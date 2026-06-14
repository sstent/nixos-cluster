{ config, pkgs, lib, ... }:

let
  haClusterManager = pkgs.writeShellScriptBin "ha-cluster-manager" ''
    set -e
    export PATH="${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin:${pkgs.systemd}/bin:${pkgs.curl}/bin:${pkgs.rsync}/bin:${pkgs.openssh}/bin:${pkgs.jq}/bin:$PATH"

    LEADER_KEY="hass-ha/leader"
    CONSUL_URL="http://127.0.0.1:8500"
    DATA_DIR="/mnt/hass-ha"
    NODE_NAME=$(cat /etc/hostname)
    
    # Get IP address of end0 interface
    IP_ADDRESS=$(ip -4 addr show end0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
    
    register_service() {
      local state="$1"

      if [ "$state" = "active" ]; then
        local payload=$(cat <<EOF
{
  "ID": "hass-ha-$NODE_NAME",
  "Name": "hass-ha",
  "Address": "$IP_ADDRESS",
  "Port": 8124,
  "Tags": ["$state", "homeassistant", "global"],
  "Check": {
    "TCP": "$IP_ADDRESS:8124",
    "Interval": "15s",
    "Timeout": "2s"
  }
}
EOF
)
      else
        local payload=$(cat <<EOF
{
  "ID": "hass-ha-$NODE_NAME",
  "Name": "hass-ha",
  "Address": "$IP_ADDRESS",
  "Port": 8124,
  "Tags": ["$state", "homeassistant", "global"]
}
EOF
)
      fi

      curl -s -X PUT -d "$payload" "$CONSUL_URL/v1/agent/service/register" > /dev/null
    }

    # Create session
    SESSION_ID=$(curl -s -X PUT "$CONSUL_URL/v1/session/create" -d '{"Name": "ha-cluster-manager-'$NODE_NAME'", "TTL": "15s", "Behavior": "release"}' | ${pkgs.jq}/bin/jq -r .ID)
    
    WAS_LEADER=false
    register_service "standby"

    while true; do
      # Renew session
      curl -s -X PUT "$CONSUL_URL/v1/session/renew/$SESSION_ID" > /dev/null
      
      # Try to acquire lock
      ACQUIRED=$(curl -s -X PUT "$CONSUL_URL/v1/kv/$LEADER_KEY?acquire=$SESSION_ID")
      
      if [ "$ACQUIRED" = "true" ]; then
        if [ "$WAS_LEADER" = "false" ]; then
          echo "Acquired lock. Promoting to leader..."
          WAS_LEADER=true
          register_service "active"
        fi
        
        # Ensure HA is running
        if ! systemctl is-active --quiet home-assistant; then
          echo "Starting Home Assistant..."
          systemctl start home-assistant
        fi
      else
        if [ "$WAS_LEADER" = "true" ]; then
          echo "Lost lock. Demoting to standby..."
          WAS_LEADER=false
          register_service "standby"
        fi
        
        # Ensure HA is stopped
        if systemctl is-active --quiet home-assistant; then
          echo "Stopping Home Assistant..."
          systemctl stop home-assistant
        fi
        
        # Sync from leader
        LEADER_SESSION=$(curl -s "$CONSUL_URL/v1/kv/$LEADER_KEY" | ${pkgs.jq}/bin/jq -r '.[0].Session')
        if [ "$LEADER_SESSION" != "null" ] && [ -n "$LEADER_SESSION" ]; then
          LEADER_NODE=$(curl -s "$CONSUL_URL/v1/session/info/$LEADER_SESSION" | ${pkgs.jq}/bin/jq -r '.[0].Node')
          LEADER_IP=$(curl -s "$CONSUL_URL/v1/catalog/node/$LEADER_NODE" | ${pkgs.jq}/bin/jq -r '.Node.Address')
          
          if [ -n "$LEADER_IP" ] && [ "$LEADER_IP" != "null" ] && [ "$LEADER_IP" != "$IP_ADDRESS" ]; then
            echo "Syncing configuration from leader ($LEADER_IP)..."
            # Sync mutable config files, ignoring the external recorder db and log files.
            # Preserves permissions to hass:hass.
            ${pkgs.rsync}/bin/rsync -a --delete \
              --exclude 'home-assistant.log*' \
              --exclude 'home-assistant_v2.db*' \
              rsync://$LEADER_IP/hass-ha/ $DATA_DIR/
          fi
        fi
      fi
      
      sleep 5
    done
  '';
in
{
  # Ensure the data directory is created and owned by the Home Assistant user
  systemd.tmpfiles.rules = [
    "d /mnt/hass-ha 0775 hass hass - -"
  ];

  # Install Home Assistant Native Service
  services.home-assistant = {
    enable = true;
    # Keep the configuration directory mutable by not declaring `config = {}`
    configDir = "/mnt/hass-ha";
    config = null; # Prevent Nix from trying to read/generate configuration.yaml
    extraPackages = python3Packages: with python3Packages; [
      psycopg2  # Required for external PostgreSQL recorder
    ];
  };

  # PREVENT Home Assistant from starting automatically on boot.
  # The ha-cluster-manager will start it ONLY when it acquires the lock.
  systemd.services.home-assistant.wantedBy = lib.mkForce [];

  environment.systemPackages = [
    haClusterManager
    pkgs.rsync
    pkgs.jq
    pkgs.curl
  ];

  # Cluster Manager Service
  systemd.services.ha-cluster-manager = {
    description = "Home Assistant Cluster Manager";
    after = [ "consul.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${haClusterManager}/bin/ha-cluster-manager";
      Restart = "always";
      RestartSec = 5;
    };
  };

  services.rsyncd = {
    enable = true;
    settings = {
      globalSection = {
        uid = "root";
        gid = "root";
        "use chroot" = true;
        "max connections" = 4;
      };
      sections = {
        hass-ha = {
          path = "/mnt/hass-ha";
          "read only" = true;
          "hosts allow" = "192.168.4.0/24 127.0.0.1";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8124 873 ];
}

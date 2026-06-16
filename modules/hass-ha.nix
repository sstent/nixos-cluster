{ config, pkgs, lib, ... }:

let
  haClusterManager = pkgs.writeShellScriptBin "ha-cluster-manager" ''
    # NOTE: deliberately no `set -e` here. The main loop must survive
    # transient curl/systemctl failures without killing the whole
    # manager and forcing a full session re-creation cycle.
    set -uo pipefail

    export PATH="${pkgs.coreutils}/bin:${pkgs.iproute2}/bin:${pkgs.gnugrep}/bin:${pkgs.systemd}/bin:${pkgs.curl}/bin:${pkgs.rsync}/bin:${pkgs.openssh}/bin:${pkgs.jq}/bin:$PATH"

    LEADER_KEY="hass-ha/leader"
    CONSUL_URL="http://127.0.0.1:8500"
    DATA_DIR="/mnt/hass-ha"
    NODE_NAME=$(cat /etc/hostname)

    SESSION_TTL="30s"
    RENEW_INTERVAL=5
    LOOP_INTERVAL=5
    MAX_START_FAILURES=3

    # Get IP address of end0 interface
    IP_ADDRESS=$(ip -4 addr show end0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

    SESSION_ID=""
    WAS_LEADER=false
    START_FAILURES=0
    RENEW_PID=""

    register_service() {
      local state="$1"

      local node_payload
      node_payload=$(cat <<EOF
{
  "ID": "hass-ha-node-$NODE_NAME",
  "Name": "hass-ha-node",
  "Address": "$IP_ADDRESS",
  "Tags": ["$state", "homeassistant", "cluster-node"]
}
EOF
)
      curl -s -f -X PUT -d "$node_payload" "$CONSUL_URL/v1/agent/service/register" > /dev/null \
        || echo "Warning: failed to register node service as $state"

      if [ "$state" = "active" ]; then
        local payload
        payload=$(cat <<EOF
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
        curl -s -f -X PUT -d "$payload" "$CONSUL_URL/v1/agent/service/register" > /dev/null \
          || echo "Warning: failed to register hass-ha service"
      else
        curl -s -f -X PUT "$CONSUL_URL/v1/agent/service/deregister/hass-ha-$NODE_NAME" > /dev/null \
          || true
      fi
    }

    # Wait until a 'systemctl stop' has actually settled (process gone),
    # not just that systemd accepted the stop request.
    wait_for_inactive() {
      local unit="$1"
      local tries=0
      while systemctl is-active --quiet "$unit"; do
        tries=$((tries + 1))
        if [ "$tries" -ge 30 ]; then
          echo "Warning: $unit still active after ''${tries}x1s waiting"
          return 1
        fi
        sleep 1
      done
      return 0
    }

    stop_ha() {
      if systemctl is-active --quiet home-assistant; then
        echo "Stopping Home Assistant..."
        systemctl stop --no-block home-assistant || echo "Warning: systemctl stop home-assistant failed"
        wait_for_inactive home-assistant || echo "Warning: proceeding even though home-assistant did not fully stop"
      fi
    }

    start_ha() {
      if ! systemctl is-active --quiet home-assistant; then
        echo "Starting Home Assistant..."
        if systemctl start home-assistant; then
          START_FAILURES=0
        else
          START_FAILURES=$((START_FAILURES + 1))
          echo "Warning: failed to start home-assistant (failure #$START_FAILURES)"
          if [ "$START_FAILURES" -ge "$MAX_START_FAILURES" ]; then
            echo "Repeated start failures ($START_FAILURES). Releasing leadership voluntarily."
            release_lock
            WAS_LEADER=false
            register_service "standby"
            START_FAILURES=0
          fi
        fi
      fi
    }

    stop_esphome() {
      if systemctl is-active --quiet esphome; then
        echo "Stopping ESPhome..."
        systemctl stop --no-block esphome || echo "Warning: systemctl stop esphome failed"
        wait_for_inactive esphome || echo "Warning: proceeding even though esphome did not fully stop"
      fi
    }

    start_esphome() {
      if ! systemctl is-active --quiet esphome; then
        echo "Starting ESPhome..."
        systemctl start esphome || echo "Warning: failed to start esphome"
      fi
    }

    release_lock() {
      if [ -n "$SESSION_ID" ]; then
        curl -s -f -X PUT "$CONSUL_URL/v1/kv/$LEADER_KEY?release=$SESSION_ID" > /dev/null || true
      fi
    }

    create_session() {
      local sid
      sid=$(curl -s -f -X PUT "$CONSUL_URL/v1/session/create" \
              -d '{"Name": "ha-cluster-manager-'"$NODE_NAME"'", "TTL": "'"$SESSION_TTL"'", "Behavior": "release", "LockDelay": "15s"}' \
              | ${pkgs.jq}/bin/jq -r '.ID // empty')
      if [ -z "$sid" ]; then
        echo "Error: failed to create Consul session"
        return 1
      fi
      SESSION_ID="$sid"
      echo "Created session $SESSION_ID"
      return 0
    }

    # Background loop: renews the session independently of the main
    # acquire/sync loop so a slow rsync or curl in the main loop can
    # never cause the session to expire from under us.
    renew_loop() {
      while true; do
        if [ -n "$SESSION_ID" ]; then
          if ! curl -s -f -X PUT "$CONSUL_URL/v1/session/renew/$SESSION_ID" > /dev/null; then
            echo "Warning: session renew failed for $SESSION_ID"
          fi
        fi
        sleep "$RENEW_INTERVAL"
      done
    }

    cleanup() {
      echo "Caught termination signal. Cleaning up..."
      if [ -n "''${RENEW_PID:-}" ]; then
        kill "$RENEW_PID" 2>/dev/null || true
      fi
      rm -f /run/ha-cluster-leader
      stop_ha
      stop_esphome
      register_service "standby"
      release_lock
      if [ -n "$SESSION_ID" ]; then
        curl -s -X PUT "$CONSUL_URL/v1/session/destroy/$SESSION_ID" > /dev/null || true
      fi
      exit 0
    }

    # Do NOT trap EXIT: it re-fires on our own `exit 0` in cleanup,
    # causing infinite recursion. INT/TERM is sufficient for systemd
    # (which sends SIGTERM on service stop).
    trap cleanup INT TERM

    # Wait for Consul to start
    echo "Waiting for Consul agent..."
    while ! curl -s -f "$CONSUL_URL/v1/agent/self" > /dev/null; do
      sleep 2
    done
    echo "Consul agent is up."

    until create_session; do
      sleep 2
    done

    renew_loop &
    RENEW_PID=$!

    register_service "standby"

    while true; do
      # Try to acquire lock. Treat curl failure (Consul unreachable)
      # as "unknown", not as "lock lost" -- don't demote on transient
      # network errors.
      ACQUIRE_RESPONSE=$(curl -s -f -X PUT "$CONSUL_URL/v1/kv/$LEADER_KEY?acquire=$SESSION_ID")
      ACQUIRE_STATUS=$?

      if [ "$ACQUIRE_STATUS" -ne 0 ]; then
        echo "Warning: could not reach Consul to acquire lock, skipping this iteration"
        sleep "$LOOP_INTERVAL"
        continue
      fi

      if [ "$ACQUIRE_RESPONSE" = "true" ]; then
        if [ "$WAS_LEADER" = "false" ]; then
          echo "Acquired lock. Promoting to leader..."
          WAS_LEADER=true
          touch /run/ha-cluster-leader
          register_service "active"
        fi

        start_ha
        start_esphome

      else
        if [ "$WAS_LEADER" = "true" ]; then
          echo "Lost lock. Demoting to standby..."
          WAS_LEADER=false
          rm -f /run/ha-cluster-leader
          register_service "standby"
        fi

        stop_esphome
        stop_ha

        # Sync from leader -- sync .storage/ but skip volatile files
        # that are rewritten constantly on a live leader (rewriting them
        # mid-read would give the standby a corrupt/partial snapshot).
        LEADER_SESSION=$(curl -s -f "$CONSUL_URL/v1/kv/$LEADER_KEY" | ${pkgs.jq}/bin/jq -r '.[0].Session // empty')

        if [ -n "$LEADER_SESSION" ]; then
          LEADER_NODE=$(curl -s -f "$CONSUL_URL/v1/session/info/$LEADER_SESSION" | ${pkgs.jq}/bin/jq -r '.[0].Node // empty')

          if [ -n "$LEADER_NODE" ]; then
            LEADER_IP=$(curl -s -f "$CONSUL_URL/v1/catalog/node/$LEADER_NODE" | ${pkgs.jq}/bin/jq -r '.Node.Address // empty')

            if [ -n "$LEADER_IP" ] && [ "$LEADER_IP" != "$IP_ADDRESS" ]; then
              echo "Syncing configuration from leader ($LEADER_IP)..."
              ${pkgs.rsync}/bin/rsync -a --delete --chown=hass:hass \
                --exclude 'home-assistant.log*' \
                --exclude 'home-assistant_v2.db*' \
                --exclude '.storage/core.restore_state' \
                --exclude '.storage/repairs.issue_registry' \
                rsync://$LEADER_IP/hass-ha/ $DATA_DIR/ \
                && date +%s > /run/last-hass-sync \
                || echo "Warning: rsync hass-ha from $LEADER_IP failed"

              echo "Syncing ESPhome configuration from leader ($LEADER_IP)..."
              ${pkgs.rsync}/bin/rsync -a --delete \
                rsync://$LEADER_IP/esphome/ /mnt/esphome/ \
                && date +%s > /run/last-esphome-sync \
                || echo "Warning: rsync esphome from $LEADER_IP failed"
            fi
          else
            echo "Warning: could not resolve leader node from session $LEADER_SESSION"
          fi
        fi
      fi

      sleep "$LOOP_INTERVAL"
    done
  '';
in
{
  # Ensure the data directories are created with correct ownership
  systemd.tmpfiles.rules = [
    "d /mnt/hass-ha  0775 hass hass - -"
    "d /mnt/esphome  0775 root root - -"
  ];

  # Install Home Assistant Native Service
  services.home-assistant = {
    enable = true;
    # Keep the configuration directory mutable by not declaring `config = {}`
    configDir = "/mnt/hass-ha";
    config = null; # Prevent Nix from trying to read/generate configuration.yaml
    extraPackages = python3Packages: with python3Packages; [
      psycopg2        # Required for external PostgreSQL recorder
      aiohomekit      # homekit_controller integration
      pychromecast    # cast (Google Cast) integration
      androidtvremote2 # androidtv_remote integration
      pyipp           # ipp (Internet Printing Protocol) integration
      python-kasa     # tplink (TP-Link smart plugs/bulbs) integration
      radios          # radio_browser integration
      gtts            # google_translate TTS integration
      python-otbr-api # homekit_controller Thread/OTBR dependency
      thinqconnect    # lg_thinq integration
      reolink-aio     # reolink camera integration
      broadlink       # broadlink IR blaster integration
      zwave-js-server-python # zwave_js integration
    ];
  };

  # PREVENT Home Assistant from starting automatically on boot or during
  # NixOS switches. The ha-cluster-manager will start it ONLY when it
  # acquires the Consul leader lock. The ConditionPathExists guard means
  # systemd (and switch-to-configuration) won't actually exec HA unless the
  # cluster manager has written the sentinel file, even if systemd tries to
  # start the unit.
  systemd.services.home-assistant.wantedBy = lib.mkForce [];
  systemd.services.home-assistant.restartIfChanged = false;
  systemd.services.home-assistant.stopIfChanged = false;
  systemd.services.home-assistant.unitConfig.ConditionPathExists = "/run/ha-cluster-leader";

  # ESPhome – enabled but NOT started on boot; ha-cluster-manager controls
  # its lifecycle via start_esphome/stop_esphome, same as Home Assistant.
  services.esphome = {
    enable = true;
    port   = 6052;
    # openFirewall = false; we manage firewall rules explicitly below
  };
  # services.esphome has no configDir option – redirect its state dir to
  # /mnt/esphome via a bind-mount so device YAMLs live on the local SSD
  # (same pattern as /mnt/hass-ha for Home Assistant).
  systemd.services.esphome = {
    wantedBy         = lib.mkForce [];
    restartIfChanged = false;
    stopIfChanged    = false;
    unitConfig.ConditionPathExists = "/run/ha-cluster-leader";
    # Ensure /mnt/esphome exists before systemd sets up the BindPaths
    # mount namespace — BindPaths fails at namespace setup time (before
    # any ExecStart*) if the source directory is missing.
    wants  = [ "systemd-tmpfiles-setup.service" ];
    after  = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      # Bind /mnt/esphome over the module's default /var/lib/esphome so
      # ESPhome transparently reads/writes from our persistent location.
      BindPaths = [ "/mnt/esphome:/var/lib/esphome" ];
    };
  };

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
      # Give cleanup (stop HA, deregister, release lock, destroy session)
      # enough time to run on shutdown/restart.
      TimeoutStopSec = 60;
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
        esphome = {
          path = "/mnt/esphome";
          "read only" = true;
          "hosts allow" = "192.168.4.0/24 127.0.0.1";
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8124 873 6052 ];
  networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS for ESPhome discovery
}

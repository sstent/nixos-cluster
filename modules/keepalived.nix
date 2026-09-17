{ config, pkgs, lib, ... }:
with lib; let
  NetworkInterface = config.custom._Networkinterface;

  # Extract the first IPv4 address from the configured network interface
  getHostIp = interfaceName:
    let
      interfaceConfig = config.networking.interfaces.${interfaceName} or {};
      addresses = interfaceConfig.ipv4.addresses or [];
    in
      if (length addresses) > 0
      then (head addresses).address
      else throw "No IPv4 address configured for interface ${interfaceName}";

  thisHostIp = getHostIp NetworkInterface;

  priorityByIp = {
    "192.168.4.226" = 70;   # Backup
    "192.168.4.227" = 90;   # Backup
    "192.168.4.228" = 80;   # Backup
    "192.168.4.36"  = 100;  # Master
    "192.168.4.37"  = 60;   # Backup
    "192.168.4.38"  = 60;   # Backup
  };

  allNodes = ["192.168.4.226" "192.168.4.227" "192.168.4.228" "192.168.4.36" "192.168.4.37" "192.168.4.38"];

  unicastPeers = filter (ip: ip != thisHostIp) allNodes;

  VIP_Priority = priorityByIp.${thisHostIp} or 50;

  # Bind script to a variable to avoid nested quote escaping in extraConfig
  notifyScript = pkgs.writeShellScript "keepalived-notify" ''
    TYPE=$1
    NAME=$2
    STATE=$3
    if [ -z "$STATE" ] && [ -n "$1" ]; then
      STATE="$1"
    fi

    LOG="/tmp/keepalived-notify.log"

    log_msg() {
      echo "$(date): $1" >> "$LOG"
      ${pkgs.util-linux}/bin/logger -t keepalived-notify "$1"
    }

    log_msg "VRRP transition triggered: type=$TYPE name=$NAME state=$STATE"

    if [ "$STATE" = "MASTER" ]; then
      VIP_ASSIGNED=false
      for i in $(seq 1 5); do
        if ${pkgs.iproute2}/bin/ip -4 addr show dev "${NetworkInterface}" | ${pkgs.gnugrep}/bin/grep -q '192.168.4.250'; then
          VIP_ASSIGNED=true
          break
        fi
        sleep 0.1
      done

      if [ "$VIP_ASSIGNED" = "true" ]; then
        log_msg "VIP 192.168.4.250 verified on ${NetworkInterface}. Promoting to MASTER."
        ${pkgs.systemd}/bin/systemctl stop hass-sync.timer hass-sync.service
        touch /run/ha-cluster-leader
        ${pkgs.systemd}/bin/systemctl start home-assistant esphome
        
        # Register hass-nix with Consul
        ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8500/v1/agent/service/register -d '{
          "id": "hass-nix",
          "name": "hass-nix",
          "port": 8123,
          "tags": [
            "homeassistant",
            "global",
            "sslcert",
            "traefik.http.routers.hass-nixlan.rule=Host(`hass-nix.service.dc1.consul`,`hass.service.dc1.consul`)",
            "traefik.http.routers.hass-nixlan.entrypoints=web",
            "traefik.http.routers.hass-nix.rule=Host(`hass-nix.service.dc1.fbleagh.duckdns.org`,`hass-local.fbleagh.duckdns.org`,`hass-nix-local.fbleagh.duckdns.org`)",
            "traefik.http.routers.hass-nix.entrypoints=websecure",
            "traefik.http.routers.hass-nix.tls=true"
          ],
          "checks": [{
            "tcp": "127.0.0.1:8123",
            "interval": "10s",
            "timeout": "2s"
          }]
        }' || true
      else
        log_msg "WARNING: Transition state is MASTER but VIP 192.168.4.250 is missing on ${NetworkInterface}! Aborting master promotion."
        rm -f /run/ha-cluster-leader
        ${pkgs.systemd}/bin/systemctl stop home-assistant esphome
        ${pkgs.systemd}/bin/systemctl start hass-sync.timer
        
        # Deregister hass-nix from Consul
        ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8500/v1/agent/service/deregister/hass-nix || true
      fi
    else
      log_msg "Non-MASTER state ($STATE). Cleaning up leader flag and stopping Home Assistant."
      rm -f /run/ha-cluster-leader
      ${pkgs.systemd}/bin/systemctl stop home-assistant esphome
      ${pkgs.systemd}/bin/systemctl start hass-sync.timer
      
      # Deregister hass-nix from Consul
      ${pkgs.curl}/bin/curl -s -X PUT http://127.0.0.1:8500/v1/agent/service/deregister/hass-nix || true
    fi
  '';

in {
  # keepalived_script user is only needed if you use vrrp_script health check
  # blocks with enable_script_security. Not needed for notify scripts (run as root).
  users.users.keepalived_script = {
    isSystemUser = true;
    group = "keepalived_script";
  };
  users.groups.keepalived_script = {};

  services.keepalived = {
    enable = true;
    openFirewall = true;
    enableScriptSecurity = true;
    extraGlobalDefs = "script_user root";

    vrrpInstances.VIP_250 = {
      interface = NetworkInterface;
      virtualRouterId = 51;
      priority = VIP_Priority;
      unicastPeers = unicastPeers;
      virtualIps = [{ addr = "192.168.4.250/22"; }];
      extraConfig = ''
        notify ${notifyScript}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

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
    "192.168.4.36"  = 100;   # Master
  };

  allNodes = ["192.168.4.226" "192.168.4.227" "192.168.4.228" "192.168.4.36"];

  unicastPeers = filter (ip: ip != thisHostIp) allNodes;

  VIP_Priority = priorityByIp.${thisHostIp} or 50;

  # Bind script to a variable to avoid nested quote escaping in extraConfig
  notifyScript = pkgs.writeShellScript "keepalived-notify" ''
    STATE=$3
    LOG="/tmp/keepalived-notify.log"
    echo "$(date): Transitioning to $STATE" >> $LOG

    if [ "$STATE" = "MASTER" ]; then
      ${pkgs.systemd}/bin/systemctl stop hass-sync.timer hass-sync.service
      touch /run/ha-cluster-leader
      ${pkgs.systemd}/bin/systemctl start home-assistant esphome
    else
      rm -f /run/ha-cluster-leader
      ${pkgs.systemd}/bin/systemctl stop home-assistant esphome
      ${pkgs.systemd}/bin/systemctl start hass-sync.timer
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
        notify_master ${notifyScript}
        notify_backup ${notifyScript}
        notify_fault  ${notifyScript}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

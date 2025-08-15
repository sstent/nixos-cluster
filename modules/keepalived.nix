{ config, pkgs, lib, ... }:
with lib; let
  NetworkInterface = config.custom._Networkinterface;
  VIP_Priority = config.custom.VIP_Priority;
in {


  services.keepalived = {
    enable = true;
    openFirewall = true;
    vrrpInstances.VIP_250 = {
        interface = "${NetworkInterface}";
        virtualRouterId  = 51;
        priority = VIP_Priority;
        unicastPeers = ["192.168.4.226" "192.168.4.227" "192.168.4.228" "192.168.4.36"];
        virtualIps = [{addr = "192.168.4.250/22";}];
          
      };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ]; # optional
}

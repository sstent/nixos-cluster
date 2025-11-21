{ config, pkgs, lib, ... }:
with lib; let
  NetworkInterface = config.custom._Networkinterface;
  
  # Extract the first IPv4 address from the configured network interface
  # This gets the IP from networking.interfaces.<interface>.ipv4.addresses
  getHostIp = interfaceName:
    let
      interfaceConfig = config.networking.interfaces.${interfaceName} or {};
      addresses = interfaceConfig.ipv4.addresses or [];
    in
      if (length addresses) > 0
      then (head addresses).address
      else throw "No IPv4 address configured for interface ${interfaceName}";
  
  thisHostIp = getHostIp NetworkInterface;
  
  # Define priorities based on IP
  priorityByIp = {
    "192.168.4.226" = 100;  # Master
    "192.168.4.227" = 90;   # Backup 1
    "192.168.4.228" = 80;   # Backup 2
    "192.168.4.36" = 70;    # Backup 3
  };
  
  # All cluster nodes
  allNodes = ["192.168.4.226" "192.168.4.227" "192.168.4.228" "192.168.4.36"];
  
  # Filter out this host from unicast peers
  unicastPeers = filter (ip: ip != thisHostIp) allNodes;
  
  # Get priority for this host (default to 50 if not found)
  VIP_Priority = priorityByIp.${thisHostIp} or 50;
  
in {
  services.keepalived = {
    enable = true;
    openFirewall = true;
    vrrpInstances.VIP_250 = {
      interface = "${NetworkInterface}";  
      virtualRouterId = 51;
      priority = VIP_Priority;
      unicastPeers = unicastPeers;
      virtualIps = [{addr = "192.168.4.250/22";}];
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
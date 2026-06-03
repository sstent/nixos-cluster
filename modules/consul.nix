{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  secretstore = config._secretstore;
  NetworkInterface = config.custom._Networkinterface;
in {
  sops.secrets."consul_encrypt.json" = {
    sopsFile = "${secretstore}/consul_encrypt.json";
    format = "binary";
    mode = "0400";
    owner = "consul";
    group = "consul";
    restartUnits = [ "consul.service" ];
  };

  # Give the consul user permission to access the /run/secrets directory
  users.users.consul.extraGroups = [ "keys" ];
  
  networking.firewall = {
    enable = true;
    # Remove port 53 - CoreDNS will handle it
    allowedTCPPorts = [8300 8301 8302 8500 8600];
    allowedUDPPorts = [8301 3802 8600];
  };

  # REMOVE the consul-dns-redirect service - no longer needed
  
  services.consul = {
    enable = true;
    webUi = true;
    interface.bind = "${NetworkInterface}";
    extraConfigFiles = [config.sops.secrets."consul_encrypt.json".path];
    extraConfig = {
      bootstrap = false;
      server = true;
      bootstrap_expect = 3;
      addresses = {
        # Bind DNS only to localhost since CoreDNS will forward to it
        dns = "0.0.0.0";
        grpc = "0.0.0.0";
        http = "0.0.0.0";
        https = "0.0.0.0";
      };
      performance = {
        raft_multiplier = 7;
      };
      recursors = [
        "192.168.4.1"
        "8.8.8.8"
      ];
      alt_domain = "fbleagh.duckdns.org";
      retry_join = [
        "192.168.4.221"
        "192.168.4.222"
        "192.168.4.225"
        "192.168.4.226"
        "192.168.4.227"
        "192.168.4.223"
        "192.168.4.224"
        "192.168.4.36"
      ];
    };
  };
}

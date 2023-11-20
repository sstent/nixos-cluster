{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid5";
  networking.interfaces.eth0.ipv4.addresses = [ {
  address = "192.168.1.225";
  prefixLength = 24;
} ];

networking.defaultGateway = "192.168.1.1";
networking.nameservers = [ "192.168.1.1" "8.8.8.8" ];
}
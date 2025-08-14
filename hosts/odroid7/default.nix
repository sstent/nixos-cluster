{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
../../modules/odroid-m1-setleds.nix
    ../../modules/odroid-m1.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid7";
  networking.interfaces.end0.ipv4.addresses = [
    {
      address = "192.168.4.227";
      prefixLength = 22;
    }
  ];

  networking.defaultGateway = "192.168.4.1";
  networking.nameservers = ["192.168.4.1" "8.8.8.8"];
}

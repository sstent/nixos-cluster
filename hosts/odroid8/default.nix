{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./odroid-m1-setleds.nix
    ./odroid-m1.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid8";

  networking.interfaces.end0.ipv4.addresses = [
    {
      address = "192.168.4.228";
      prefixLength = 24;
    }
  ];

  networking.defaultGateway = "192.168.4.1";
  networking.nameservers = ["192.168.4.1" "8.8.8.8"];
}

{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/keepalived.nix
    ../../modules/hass-ha.nix
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  networking.hostName = "opti2";
  # custom._Networkinterface = "enp0s31f6";
  # custom.VIP_Priority = 100;
  networking.interfaces.enp0s31f6.ipv4.addresses = [
    {
      address = "192.168.4.37";
      prefixLength = 22;
    }
  ];
  
  services.syncplay.enable = true;


  networking.defaultGateway = "192.168.4.1";
  networking.nameservers = ["192.168.4.250" "192.168.4.1" "8.8.8.8"];
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}

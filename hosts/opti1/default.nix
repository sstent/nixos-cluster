{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    # ../../modules/keepalived.nix
  ];

  nixpkgs.hostPlatform.system = "x86_64-linux";
  networking.hostName = "opti1";
  # custom._Networkinterface = "enp0s31f6";
  # custom.VIP_Priority = 100;
  networking.interfaces.end0.ipv4.addresses = [
    {
      address = "192.168.4.36";
      prefixLength = 22;
    }
  ];



  networking.defaultGateway = "192.168.4.1";
  networking.nameservers = ["192.168.4.1" "8.8.8.8"];
    # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/nvme0n1";
  boot.loader.grub.useOSProber = true;
}

{ lib, pkgs, config, inputs, ... }: {
  imports = [
    ../odroid-hc2-base
    ../../modules/minimal-base.nix
  ];

  networking.hostName = lib.mkForce "odroid3";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  
  boot.loader.generic-extlinux-compatible.enable = true;
}

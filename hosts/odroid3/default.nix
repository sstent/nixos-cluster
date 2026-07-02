{ lib, pkgs, config, inputs, ... }: {
  imports = [
    ../odroid-hc2-base
    ../../modules/base.nix
  ];

  networking.hostName = "odroid3";
}

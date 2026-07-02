{ lib, pkgs, config, inputs, ... }: {
  imports = [
    "${inputs.nixpkgs}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
    ../odroid-hc2-base
    ../../modules/base.nix
  ];

  networking.hostName = lib.mkForce "odroid3";
}

{ lib, pkgs, config, inputs,  ... }: {

  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid8";

}

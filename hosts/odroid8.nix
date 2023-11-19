{ lib, pkgs, config, inputs,  ... }: {

  imports = [
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid8";

}

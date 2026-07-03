{ lib, pkgs, config, inputs, ... }: {
  imports = [
    # odroid-hc2-base sets nixpkgs.hostPlatform = "armv7l-linux" which is
    # required for the SD image cross-compilation to evaluate U-Boot etc. correctly.
    # Do NOT import minimal-base.nix here — its nixpkgs-unstable overlay evaluates
    # nixpkgs for armv7l natively, requiring gccarch-armv7-a on the build host.
    ../odroid-hc2-base
  ];

  networking.hostName = lib.mkForce "odroid3";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  boot.loader.generic-extlinux-compatible.enable = true;
  boot.loader.grub.enable = false;

  # Minimal runtime — no cluster stack, no sops, no wireguard
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };
  users.users.root = {
    initialPassword = lib.mkForce "odroid";
    openssh.authorizedKeys.keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAwn26AL26A0Yt4sE+rm5//p8QKuNGI/ezAdNJX9QAjRErjEWnsiUr+w0O78912A2RCakdZYZJo6p1RuLYq6u27mjdLU1hhJs1t/ZFUjevKP33Q8hjptnV3s/G/iPfl0h4kQDStNySgJJ7cGh8Dhj906BrQbns3U2WgVZWwhaYvFiSjZA9UWwvB+n/jN9YeSShfdqGYw8/WlFZiOZrz4poO6/DUOAiztvzrpaQFDtI2f9TdGL1ttvYk04jDCRO1cM1LjgWir+WToalgyAqxfgnlvbv8g16RQo//8qhRdMqQPJKnIRewy/VLN1VbNbO2+z5f6BYbYlfioDXmuzMb86jfQ== id_rsa"];
  };

  nix.extraOptions = "experimental-features = nix-command flakes";
  environment.systemPackages = [ pkgs.git pkgs.jq ];
}

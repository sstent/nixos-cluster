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
        ../../modules/keepalived.nix
    ../../modules/hass-ha.nix
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
  networking.nameservers = ["192.168.4.250" "192.168.4.1" "8.8.8.8"];

  # Prevent rotational disks from spinning down and disable APM / USB autosuspend
  environment.systemPackages = with pkgs; [ hdparm sdparm ];
  boot.kernelParams = [ "usbcore.autosuspend=-1" ];
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", RUN+="${pkgs.hdparm}/bin/hdparm -B 255 -S 0 /dev/%k"
  '';
}

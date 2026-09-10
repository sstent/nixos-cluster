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
    ../../modules/cifs.nix
        ../../modules/keepalived.nix
    ../../modules/hass-ha.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid8";

  networking.interfaces.end0.ipv4.addresses = [
    {
      address = "192.168.4.228";
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

# Declare only the secrets this host actually uses
 sops.secrets."restic_password_odroid7" = {};
 sops.secrets."restic_password_hetzner" = {};
 custom.resticprofile.profiles = {
    calibre-library = {
      repository = "sftp:root@192.168.4.227:/mnt/EXTDrive1/_RESTICDATA/calibre-library";
      password-file = config.sops.secrets."restic_password_odroid7".path;
      retention = {
        keep-daily = 7;
        keep-weekly = 4;
        keep-monthly = 12;
        group-by = "host,paths";
      };
      backup = {
        source = [ "/mnt/EXTDrive1/PublicCalibreLibrary" ];
        tag = [ "calibre" "odroid8" ];
        exclude = [ "*.tmp" "*.lock" ];
      };
    };
    
    photos-library = {
      repository = "sftp://u665612@u665612.your-storagebox.de:23//home//restic-backups//{{ .Profile.Name }}";
      password-file = config.sops.secrets."restic_password_hetzner".path;
      retention = {
        keep-last = 10;
        group-by = "host,paths";
      };
      backup = {
        source = [ "/mnt/EXTDrive1/Photos_Backup" ];
        tag = [ "MasterPhotos" "odroid8" ];
        exclude = [ "*.tmp" "*.lock" ];
      };
    };
  };

  custom.resticprofile.groups = {
    calibre-daily = {
      profiles = [ "calibre-library" ];
      schedules.backup.at = "02:30";
    };
    photos-daily = {
      profiles = [ "photos-library" ];
      schedules.backup.at = "03:30";
    };
  };
}

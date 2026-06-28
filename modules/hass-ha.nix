{ config, pkgs, lib, ... }:

{

  # Ensure the data directories are created with correct ownership
  systemd.tmpfiles.rules = [
    "d /mnt/hass-ha  0775 hass hass - -"
    "d /mnt/esphome  0775 esphome esphome - -"
  ];

  # ---------------------------------------------------------
  # HOME ASSISTANT & ESPHOME
  # ---------------------------------------------------------
  services.home-assistant = {
    enable = true;
    package = pkgs.unstable.home-assistant;
    configDir = "/mnt/hass-ha";
    config = null;
    extraPackages = python3Packages: with python3Packages; [
      psycopg2 aiohomekit pychromecast androidtvremote2 pyipp python-kasa
      radios gtts python-otbr-api thinqconnect reolink-aio broadlink
      zwave-js-server-python adb-shell androidtv
    ];
  };

  # HA Lifecycle Locks (Prevent auto-start; keepalived notify script manages these)
  systemd.services.home-assistant.wantedBy = lib.mkForce [];
  systemd.services.home-assistant.restartIfChanged = false;
  systemd.services.home-assistant.stopIfChanged = false;
  systemd.services.home-assistant.unitConfig.ConditionPathExists = "/run/ha-cluster-leader";

  services.esphome = {
    enable = true;
    address = "0.0.0.0";
    port   = 6053;
  };

users.users.esphome = {
  isSystemUser = true;
  group = "esphome";
  uid = 993;  # pin to consistent value across all hosts
};
users.groups.esphome = {
  gid = 991;  # pin to consistent value across all hosts
};

  systemd.services.esphome = {
    wantedBy         = lib.mkForce [];
    restartIfChanged = false;
    stopIfChanged    = false;
    unitConfig.ConditionPathExists = "/run/ha-cluster-leader";
    wants  = [ "systemd-tmpfiles-setup.service" ];
    after  = [ "systemd-tmpfiles-setup.service" ];

  environment.PYTHONPATH = "${pkgs.esphome}/lib/python3.13/site-packages:${pkgs.python3Packages.makePythonPath pkgs.esphome.dependencies}";
  environment.PLATFORMIO_CORE_DIR = lib.mkForce "/mnt/esphome/.platformio";

  serviceConfig = {
    ExecStart        = lib.mkForce "${pkgs.esphome}/bin/esphome dashboard --address 0.0.0.0 --port 6053 /mnt/esphome";
    WorkingDirectory = lib.mkForce "/mnt/esphome";
    StateDirectory   = lib.mkForce "";
    DynamicUser      = lib.mkForce false;
    User             = lib.mkForce "esphome";
    Group            = lib.mkForce "esphome";
    ReadWritePaths   = [ "/mnt/esphome" ];
  };


  };

  # ---------------------------------------------------------
  # RSYNC SYNC LOGIC (Pulls from VIP)
  # ---------------------------------------------------------
  systemd.services.hass-sync = {
    description = "Sync HA data from active Keepalived master VIP";
    # Do not run if this node is the master
    unitConfig.ConditionPathExists = "!/run/ha-cluster-leader";
    path = [ pkgs.rsync ];
    script = ''
      # Sync Home Assistant
      rsync -a --delete --chown=hass:hass \
        --exclude 'home-assistant.log*' \
        --exclude 'home-assistant_v2.db*' \
        --exclude '.storage/core.restore_state' \
        --exclude '.storage/repairs.issue_registry' \
        rsync://192.168.4.250/hass-ha/ /mnt/hass-ha/ && date +%s > /run/last-hass-sync

      # Sync ESPHome
      rsync -a --delete rsync://192.168.4.250/esphome/ /mnt/esphome/
    '';
    serviceConfig.Type = "oneshot";
  };

  # Rsync Timer (Only active when node is BACKUP)
  # keepalived notify script calls `systemctl start/stop hass-sync.timer`
  systemd.timers.hass-sync = {
    description = "Timer for HA config sync";
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "30s";
    };
    wantedBy = []; # Not enabled on boot; keepalived notify script manages this
  };

  # ---------------------------------------------------------
  # RSYNC SERVER (Serves files to backups when MASTER)
  # ---------------------------------------------------------
  services.rsyncd = {
    enable = true;
    settings = {
      globalSection = {
        uid = "root";
        gid = "root";
        "use chroot" = true;
        "max connections" = 4;
      };
      sections = {
        hass-ha = {
          path = "/mnt/hass-ha";
          "read only" = true;
          "hosts allow" = "192.168.4.0/24 127.0.0.1";
        };
        esphome = {
          path = "/mnt/esphome";
          "read only" = true;
          "hosts allow" = "192.168.4.0/24 127.0.0.1";
        };
      };
    };
  };

  services.consul = {
    enable = true;
    extraConfig = {
      services = [
        {
          id = "hass-nix";
          name = "hass-nix";
          port = 8123; 
        tags = ["homeassistant" "global"];
          checks = [{
            tcp = "127.0.0.1:8123";
            interval = "10s";
            timeout = "2s";
          }];
        }
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 8123 873 6052 6053];
  networking.firewall.allowedUDPPorts = [ 5353 ];
}

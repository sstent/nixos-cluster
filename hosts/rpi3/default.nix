{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ../../modules/common.nix
    inputs.sops-nix.nixosModules.sops
  ];


  config = {
    system.stateVersion = "23.11";
    nixpkgs.config.allowUnfree = true;
    nixpkgs.hostPlatform.system = "aarch64-linux";

    networking.hostName = "rpi3";

    custom._Networkinterface = "eth0";

    services.consul.extraConfig.server = lib.mkForce false;
    services.consul.extraConfig.bootstrap_expect = lib.mkForce null;
    services.nomad.enable = lib.mkForce false;

services.consul.extraConfig.services = [
      {
        name = "zwavejsui";
        port = 8091;
        address = "192.168.5.11";
        tags = [ "homeautomation" "zwave" ];
      }
      {
        name = "node-exporter";
        port = 9100;
        address = "192.168.5.11";
        tags = [ "metrics" "prometheus" ];
      }
    ];

    
    networking.firewall.allowedTCPPorts = [ 8091 3000 9100 9080 ];
    
    # Failsafe: keep DHCP enabled globally so we always get an IP as a fallback
    networking.useDHCP = true;
    
    # Failsafe: force traditional interface names (eth0, wlan0) instead of unpredictable MAC-based ones (enx...)
    boot.kernelParams = [ "net.ifnames=0" ];

    networking.interfaces.eth0.ipv4.addresses = [
      {
        address = "192.168.5.11";
        prefixLength = 22;
      }
    ];
    networking.interfaces.wlan0.useDHCP = true;
    networking.defaultGateway = "192.168.4.1";
    networking.nameservers = ["192.168.4.250" "192.168.4.1" "8.8.8.8"];

    networking.wireless = {
      enable = true;
      secretsFile = config.sops.templates."wifi_env".path;
      networks."fbleagh2" = {
        pskRaw = "ext:FBLEAGH2_PSK";
      };
    };

    # Fix wpa_supplicant starting before sops-nix creates the wifi_env template
    systemd.services.wpa_supplicant.after = [ "sops-nix.service" ];
    systemd.services.wpa_supplicant.wants = [ "sops-nix.service" ];

    sops = {
      defaultSopsFile = "${config._secretstore}/host-secrets.yaml";
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      secrets."wifi_fbleagh2_psk" = {};
      templates."wifi_env".content = ''
        FBLEAGH2_PSK=${config.sops.placeholder.wifi_fbleagh2_psk}
      '';
    };

    # Enable ZRAM to prevent OOMs on 1GB RAM without degrading the SD card
    zramSwap = {
      enable = true;
      memoryPercent = 50; # Use up to 50% of RAM for compressed swap
    };







    # Move journald to RAM to break SD card I/O bottleneck
    services.journald.extraConfig = ''
      Storage=volatile
      RuntimeMaxUse=50M
    '';

    # Prometheus Node Exporter
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [ "systemd" ];
    };


    # Promtail container to ship logs to Loki
    virtualisation.oci-containers.containers.promtail = {
      image = "grafana/promtail:2.9.3";
      extraOptions = [ "--network=host" ];
      ports = [ "9080:9080" ];
      volumes = [
        "/var/lib/docker/containers:/var/lib/docker/containers:ro"
        "/var/log/journal:/var/log/journal:ro"
        "/run/log/journal:/run/log/journal:ro"
        "/etc/machine-id:/etc/machine-id:ro"
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/etc/promtail-config.yml:/etc/promtail/config.yml:ro"
      ];
    };

    environment.etc."promtail-config.yml".text = ''
      server:
        http_listen_port: 9080
        grpc_listen_port: 0

      positions:
        filename: "/tmp/positions.yaml"

      clients:
        - url: http://loki.service.dc1.consul:3100/loki/api/v1/push

      scrape_configs:
        - job_name: journal
          journal:
            max_age: 12h
            path: /var/log/journal
            labels:
              job: systemd-journal
              host: rpi3
          relabel_configs:
            - source_labels: ['__journal__systemd_unit']
              target_label: 'unit'
    '';

    # Z-Wave JS UI Container (Managed by Systemd automatically via oci-containers)
    virtualisation.oci-containers.backend = "docker";
    virtualisation.oci-containers.containers.zwave-js-ui = {
      image = "zwavejs/zwave-js-ui:latest";
      extraOptions = [ "--network=host" ];
      ports = [
        "8091:8091" # Web UI
        "3000:3000" # Z-Wave JS Server
      ];
      volumes = [
        "/var/lib/zwave-js-ui:/usr/src/app/store"
        "/mnt/Public/configs/ZwaveJSUI:/usr/src/app/store/backups"
      ];
      devices = [
        "/dev/ttyACM0:/dev/zwave"
      ];
      environment = {
        TZ = "America/Los_Angeles";
      };
    };

    # Make sure mount path exists for volume
    systemd.tmpfiles.rules = [
      "d /var/lib/zwave-js-ui 0755 root root -"
    ];
  };
}

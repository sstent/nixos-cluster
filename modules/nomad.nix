{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  virtualisation.docker.enable = true;

  networking.firewall = {
    allowedTCPPorts = [
      4646
      4647
      4648
      8123
      80
      443
      8080
      8081
      8443
      8843
      8880
      8123
      8989
      6789
      3478
      1900
      10001
      51820
    ];
    allowedUDPPorts = [
      4646
      4647
      4648
      8123
      80
      443
      5353 #mdns
      8080
      8081
      8443
      8843
      8880
      8123
      8989
      6789
      3478
      1900
      10001
      51820
    ];
    trustedInterfaces = ["docker0" "eth0"];
  };

  #
  systemd.tmpfiles.rules = [
    "d /mnt/configs/postgres 0770 999 999 -"
  ];

  services.nomad = {
    package = pkgs.nomad_1_9;
    dropPrivileges = false;
    enableDocker = true;
    enable = true;
    settings = {
      server = {
        enabled = true;
        bootstrap_expect = 3;
        start_join = ["192.168.4.225" "192.168.4.226" "192.168.4.227" "192.168.4.228"];
        rejoin_after_leave = false;
        enabled_schedulers = ["service" "batch" "system"];
        num_schedulers = 4;
        node_gc_threshold = "24h";
        eval_gc_threshold = "1h";
        job_gc_threshold = "4h";
        deployment_gc_threshold = "1h";
        encrypt = "";
        raft_protocol = 3;
        raft_multiplier = 5;
      };

      client = {
        enabled = true;
        node_class = "";
        no_host_uuid = false;
        servers = ["192.168.4.221:4647" "192.168.4.225:4647" "192.168.4.226:4647" "192.168.4.227:4647" "192.168.4.222:4647" "192.168.4.223:4647" "192.168.4.224:4647"];
        max_kill_timeout = "30s";
        network_speed = 0;
        cpu_total_compute = 0;
        gc_interval = "1m";
        gc_disk_usage_threshold = 80;
        gc_inode_usage_threshold = 70;
        gc_parallel_destroys = 2;
        reserved = {
          cpu = 0;
          memory = 200;
          disk = 0;
        };
        options = {
          "docker.caps.whitelist" = "SYS_ADMIN,NET_ADMIN,chown,dac_override,fsetid,fowner,mknod,net_raw,setgid,setuid,setfcap,setpcap,net_bind_service,sys_chroot,kill,audit_write,sys_module";
          "driver.raw_exec.enable" = "1";
          "docker.volumes.enabled" = "True";
          "docker.privileged.enabled" = "true";
          "docker.auth.config" = "/root/.docker/config.json";
        };
      };

      # custom = {
      "telemetry" = {
        "prometheus_metrics" = true;
        "publish_allocation_metrics" = true;
        "publish_node_metrics" = true;
      };
      # };
    };
  };
}

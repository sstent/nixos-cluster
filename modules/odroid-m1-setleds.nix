{ lib, pkgs, config, inputs,  ... }: {


systemd.services.setleds = {
  script = ''
    echo "Setting Odroid LEDs"
    echo none > /sys/class/leds/blue\:heartbeat/trigger
    cat /sys/class/leds/blue\:heartbeat/trigger
  '';
  wantedBy = [ "multi-user.target" ];
};

virtualisation.docker.enable = true;
services.nomad = {
        package = pkgs.nomad_1_6;
        dropPrivileges = false;
 	enableDocker = true;
	enable = true;
        settings = {
client = {
    enabled = true;
    node_class = "";
    no_host_uuid = false;
    servers = ["192.168.1.221:4647" "192.168.1.225:4647" "192.168.1.226:4647" "192.168.1.227:4647" "192.168.1.222:4647" "192.168.1.223:4647" "192.168.1.224:4647"];
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
};



};
}
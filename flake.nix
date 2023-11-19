{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  };

  outputs = { nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
    lib = nixpkgs.lib;

  

  in rec {
    formatter.x86_64-linux = nixpkgs.legacyPackages.aarch64-linux.nixpkgs-fmt;

    devShell.${system} = pkgs.mkShell {
      buildInputs = with pkgs; [
        rsync
        zstd
      ];
    };

    nixosConfigurations.m1 = lib.nixosSystem {
      system = "aarch64-linux";

      modules = [
      ({ pkgs, config, ... }: {

          imports = [
            ./kboot-conf
            # "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
            "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

          ];

          sdImage = {
            #compressImage = false;
            populateFirmwareCommands = let
              configTxt = pkgs.writeText "README" ''
              Nothing to see here. This empty partition is here because I don't know how to turn its creation off.
              '';
            in ''
              cp ${configTxt} firmware/README
            '';
            populateRootCommands = ''
              ${config.boot.loader.kboot-conf.populateCmd} -c ${config.system.build.toplevel} -d ./files/kboot.conf
            '';
            };

          system.stateVersion = "23.11";
          #boot.loader.grub.enable = false;
          boot.loader.kboot-conf.enable = true;
          # Use kernel >6.6 
          boot.kernelPackages = pkgs.linuxPackages_latest;
          # Stop ZFS breasking the build
          boot.supportedFilesystems = lib.mkForce [ "btrfs" "cifs" "f2fs" "jfs" "ntfs" "reiserfs" "vfat" "xfs" ];

          # I'm not completely sure if some of these could be omitted,
          # but want to make sure disk access works
          boot.initrd.availableKernelModules = [
            "nvme"
            "nvme-core"
            "phy-rockchip-naneng-combphy"
            "phy-rockchip-snps-pcie3"
          ];
          # Petitboot uses this port and baud rate on the boards serial port,
          # it's probably good to keep the options same for the running
          # kernel for serial console access to work well
          boot.kernelParams = [ "console=ttyS2,1500000" ];       
          hardware.deviceTree.name = "rockchip/rk3568-odroid-m1.dtb";
          
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [
    pkgs.git
    pkgs.treefmt

 ];

    fileSystems."/mnt/Public" = {
        device = "//192.168.1.109/Public";
        fsType = "cifs";
        # options = ["uid=0,gid=1000"];
        options = ["guest" "uid=1000"];
    };


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







      services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          users.extraUsers.root.initialPassword = lib.mkForce "test123";
        })
      ];
    };

    images = {
      m1 = nixosConfigurations.m1.config.system.build.sdImage;
    };
  };
}

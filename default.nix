{ lib, pkgs, config, inputs,  ... }: {

          imports = [
            ./kboot-conf
            # "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64-installer.nix"
            #"${pkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

          ];

        #   sdImage = {
        #     #compressImage = false;
        #     populateFirmwareCommands = let
        #       configTxt = pkgs.writeText "README" ''
        #       Nothing to see here. This empty partition is here because I don't know how to turn its creation off.
        #       '';
        #     in ''
        #       cp ${configTxt} firmware/README
        #     '';
        #     populateRootCommands = ''
        #       ${config.boot.loader.kboot-conf.populateCmd} -c ${config.system.build.toplevel} -d ./files/kboot.conf
        #     '';
        #     };

          boot.loader.grub.enable = false;
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
        
          # Turn on flakes.
          ##nix.package = pkgs.nixVersions.stable;
          nix.extraOptions = ''
            experimental-features = nix-command flakes
          '';

          # includes this flake in the live iso : "/etc/nixcfg"
          environment.etc.nixcfg.source =
            builtins.filterSource
              (path: type:
                baseNameOf path
                != ".git"
                && type != "symlink"
                && !(pkgs.lib.hasSuffix ".qcow2" path)
                && baseNameOf path != "secrets")
              ../.;


      services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };
          users.extraUsers.root.initialPassword = lib.mkForce "test123";
}
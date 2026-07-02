{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {

  config = {
    system.stateVersion = "23.11";
    nixpkgs.hostPlatform.system = "armv7l-linux";
    nixpkgs.config.allowBroken = true;
    
    nixpkgs.overlays = [
      (final: prev: {
        efivar = prev.runCommand "efivar-dummy" {} "mkdir -p $out";
        efibootmgr = prev.runCommand "efibootmgr-dummy" {} "mkdir -p $out";
        
        # Patch U-Boot to use higher FDT address, avoiding kernel overlap
        ubootOdroidXU3 = prev.ubootOdroidXU3.overrideAttrs (old: {
          extraConfig = (old.extraConfig or "") + ''
            CONFIG_EXTRA_ENV_SETTINGS="fdt_addr_r=0x45000000\0ramdisk_addr_r=0x47000000\0"
          '';
        });
      })
    ];

    networking.hostName = "odroid-hc2";

    # Ensure DHCP is on for the initial boot
    networking.useDHCP = true;
    boot.kernelParams = [ "net.ifnames=0" ];

    # Specify the device tree blob explicitly for the Exynos 5422 SoC
    hardware.deviceTree.name = "exynos5422-odroidhc1.dtb";

    # Include the bootloader tools to be able to re-flash natively if needed
    environment.systemPackages = with pkgs; [
      odroid-xu3-bootloader
    ];

    # Disable ZFS because it's typically unsupported or broken on 32-bit ARM kernel
    boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" "btrfs" ];
  };
}

{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./kboot-conf
  ];

  boot.loader.grub.enable = false;
  boot.loader.kboot-conf.enable = true;
  # Use kernel >6.6
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Stop ZFS breasking the build
  boot.supportedFilesystems = lib.mkForce ["btrfs" "cifs" "f2fs" "jfs" "ntfs" "reiserfs" "vfat" "xfs"];

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
  boot.kernelParams = ["console=ttyS2,1500000"];
  hardware.deviceTree.name = "rockchip/rk3568-odroid-m1.dtb";
}

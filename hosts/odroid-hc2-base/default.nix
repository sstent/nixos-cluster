{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ../../modules/common.nix
  ];

  config = {
    system.stateVersion = "23.11";
    nixpkgs.hostPlatform.system = "armv7l-linux";

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

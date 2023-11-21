{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";
  networking.hostName = "odroid5";
  networking.interfaces.end0.ipv4.addresses = [
    {
      address = "192.168.1.225";
      prefixLength = 24;
    }
  ];

  services.openiscsi = {
    enable = true;
    name = "iqn.2013-03.com.wdc:mycloudpr2100:clusterstore";
    enableAutoLoginOut = true;
    discoverPortal = "192.168.1.109";

    package = pkgs.openiscsi;
  };

  fileSystems."/mnt/ClusterStore" = {
    device = "/dev/sda1";
    fsType = "ext4";
    # options = ["uid=0,gid=1000"];
    options = ["_netdev"];
  };

  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = ["192.168.1.1" "8.8.8.8"];
}

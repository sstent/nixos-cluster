{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
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
    options = ["_netdev" "uid=1000"];
  };
}

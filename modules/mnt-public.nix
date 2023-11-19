{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  fileSystems."/mnt/Public" = {
    device = "//192.168.1.109/Public";
    fsType = "cifs";
    # options = ["uid=0,gid=1000"];
    options = ["guest" "uid=1000"];
  };
}

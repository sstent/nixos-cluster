{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  fileSystems."/mnt/Public" = {
    device = "//192.168.4.109/Public";
    fsType = "cifs";
    options = [
      "guest"
      "uid=1000"
      "nofail"
      "file_mode=0777"
      "dir_mode=0777"
    ];
  };
}

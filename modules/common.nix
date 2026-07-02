{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./base.nix
    ./mnt-public.nix
    # ./mnt-clusterstore.nix
    ./nomad.nix
    ./consul.nix
    ./coredns.nix
    ./wireguard.nix
  ];

  config = {
    networking.search = ["node.dc1.consul" "service.dc1.consul"];
  };
}

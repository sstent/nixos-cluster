{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  secretstore = config._secretstore;

  oldpkgs = import (builtins.fetchGit {
    # Descriptive name to make the store path easier to identify
    name = "my-old-revision";
    url = "https://github.com/NixOS/nixpkgs/";
    ref = "refs/heads/nixpkgs-unstable";
    rev = "3b05df1d13c1b315cecc610a2f3180f6669442f0";
  }) {};

  myPkg = oldpkgs.consul;
in {
  # virtualisation.docker.enable = true;
  sops.secrets.consul_encrypt = {};
  services.consul = {
    package = myPkg;
    enable = true;
    webUi = true;
    extraConfig = {
      bootstrap = false;
      bootstrap_expect = 7;
      encrypt = config.sops.secrets.consul_encrypt.path;
      performance = {
        raft_multiplier = 5;
      };
      recursors = [
        "192.168.1.1"
        "8.8.8.8"
      ];

      retry_join = [
        "192.168.1.221"
        "192.168.1.222"
        "192.168.1.225"
        "192.168.1.226"
        "192.168.1.227"
        "192.168.1.223"
        "192.168.1.224"
      ];
    };
  };
}

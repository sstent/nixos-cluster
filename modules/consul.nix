{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  secretstore = config._secretstore;

  # oldpkgs = import (builtins.fetchGit {
  #   # Descriptive name to make the store path easier to identify
  #   name = "git_consul_1_9";
  #   url = "https://github.com/NixOS/nixpkgs/";
  #   ref = "refs/heads/nixpkgs-unstable";
  #   rev = "3b05df1d13c1b315cecc610a2f3180f6669442f0";
  # }) {};
  oldpkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/3b05df1d13c1b315cecc610a2f3180f6669442f0.tar.gz";
    sha256 = "c704ef4a056c53db1a57bca7def48e4d9ed16418c81398488a6071833c10668c";
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

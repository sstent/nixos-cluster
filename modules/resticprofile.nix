{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.custom.resticprofile;
  yamlFormat = pkgs.formats.yaml {};
in {
  options.custom.resticprofile = {
    enable = lib.mkEnableOption "declarative resticprofile configuration" // {default = true;};

    global = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        default-command = "snapshots";
        initialize = false;
        priority = "low";
      };
      description = "Global configuration section for resticprofile";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Host-specific backup profiles defining the target repository and backup tasks.";
    };

    groups = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Resticprofile groups and schedules (version 2).";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (final: prev: {
        resticprofile = prev.resticprofile.overrideAttrs (_old: {
          doCheck = false;
        });
      })
    ];

    environment.systemPackages = [
      pkgs.resticprofile
      pkgs.restic
    ];

    environment.etc."resticprofile/profiles.yaml".source = yamlFormat.generate "profiles.yaml" (
      lib.filterAttrs (n: v: v != {} && v != null) {
        version = "2";
        global = cfg.global;
        profiles = cfg.profiles;
        groups = cfg.groups;
      }
    );
  };
}
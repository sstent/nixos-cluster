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

    repositories = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = ''
        Reusable base repository profiles (mixins) that backup profiles can
        inherit from. Define these in a shared module (e.g. restic-repos.nix)
        and merge them in per-host as needed.
      '';
      example = lib.literalExpression ''
        {
          repo-pr2100 = {
            repository = "rest:http://192.168.4.109:8888";
            password-file = config.sops.secrets."restic_password".path;
            retention = { keep-daily = 7; keep-weekly = 4; keep-monthly = 12; group-by = "host,paths"; };
          };
        }
      '';
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Host-specific backup profiles. Use `inherit` to pull in a repository mixin.";
      example = lib.literalExpression ''
        {
          system = {
            "inherit" = "repo-pr2100";
            backup.source = [ "/var/lib" ];
          };
        }
      '';
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
        profiles = cfg.repositories // cfg.profiles;
        groups = cfg.groups;
      }
    );
  };
}

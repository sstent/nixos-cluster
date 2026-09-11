{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.custom.resticprofile;
  yamlFormat = pkgs.formats.yaml {};

  reportingHooks = {
    backup = {
      send-before = [
        {
          url = "${cfg.reporting.serverUrl}/api/ping/${config.networking.hostName}/{{ .Profile.Name }}/start";
          method = "POST";
        }
      ];
      run-after = "${pkgs.curl}/bin/curl -s -X POST -H Content-Type:application/json --data-binary @/tmp/resticprofile-status-{{ .Profile.Name }}.json ${cfg.reporting.serverUrl}/api/report/${config.networking.hostName}/{{ .Profile.Name }}";
      send-after = [
        {
          url = "${cfg.reporting.serverUrl}/api/ping/${config.networking.hostName}/{{ .Profile.Name }}/success?interval=24h";
          method = "POST";
        }
      ];
      send-after-fail = [
        {
          url = "${cfg.reporting.serverUrl}/api/ping/${config.networking.hostName}/{{ .Profile.Name }}/fail?interval=24h";
          method = "POST";
          body = "\${ERROR}\n\n\${ERROR_STDERR}";
        }
      ];
    };
    retention = {
      run-after = "${pkgs.curl}/bin/curl -s -X POST -H Content-Type:application/json --data-binary @/tmp/resticprofile-status-{{ .Profile.Name }}.json ${cfg.reporting.serverUrl}/api/report/${config.networking.hostName}/{{ .Profile.Name }}";
      send-after-fail = [
        {
          url = "${cfg.reporting.serverUrl}/api/ping/${config.networking.hostName}/{{ .Profile.Name }}/fail?interval=24h";
          method = "POST";
          body = "\${ERROR}\n\n\${ERROR_STDERR}";
        }
      ];
    };
  };

  processedProfiles =
    if !cfg.reporting.enable
    then cfg.profiles
    else
      lib.mapAttrs (name: prof:
        prof
        // {
          status-file = prof.status-file or "/tmp/resticprofile-status-{{ .Profile.Name }}.json";
          use =
            if !(prof ? use)
            then "viewer-hooks"
            else if builtins.isList prof.use
            then prof.use ++ ["viewer-hooks"]
            else [prof.use "viewer-hooks"];
        })
      cfg.profiles;
in {
  options.custom.resticprofile = {
    enable = lib.mkEnableOption "declarative resticprofile configuration" // {default = true;};

    reporting = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically send start/finish pings and status reports to restic-viewer";
      };
      serverUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://restic.service.dc1.consul";
        description = "Base URL of restic-viewer service";
      };
    };

    global = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        default-command = "snapshots";
        initialize = false;
        priority = "low";
      };
      description = "Global configuration section for resticprofile";
    };

    mixins = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Resticprofile mixins (version 2).";
    };

    repositories = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = ''
        Reusable base repository profiles (mixins) that backup profiles can
        inherit from via `"inherit" = "repo-<name>"`. Define these in a shared
        module (e.g. restic-repos.nix) and merge them in per-host as needed.
      '';
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Host-specific backup profiles. Use \"inherit\" to pull in a repository mixin.";
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
      pkgs.curl
    ];

    environment.etc."resticprofile/profiles.yaml".source = yamlFormat.generate "profiles.yaml" (
      lib.filterAttrs (n: v: v != {} && v != null) {
        version = "2";
        global = cfg.global;
        mixins =
          (lib.optionalAttrs cfg.reporting.enable {
            viewer-hooks = reportingHooks;
          })
          // cfg.mixins;
        profiles = cfg.repositories // processedProfiles;
        groups = cfg.groups;
      }
    );
  };
}
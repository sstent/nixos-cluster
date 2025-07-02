{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.boot.loader.kboot-conf;

  # The builder used to write during system activation
  builder = pkgs.replaceVars ./generate-kboot-conf.sh {
    path = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];
    inherit (pkgs) bash;
  };
  
  # The builder exposed in populateCmd, which runs on the build architecture
  populateBuilder = pkgs.buildPackages.replaceVars ./generate-kboot-conf.sh {
    path = with pkgs.buildPackages; [coreutils gnused gnugrep];
    inherit (pkgs.buildPackages) bash;
  };

  # Debug wrapper function that takes args as parameter
  mkDebugBuilder = args: pkgs.writeScript "kboot-debug-wrapper" ''
    #!${pkgs.bash}/bin/bash
    
    # Set up PATH with required utilities
    export PATH=${lib.makeBinPath (with pkgs; [ coreutils util-linux procps gnugrep gnused])}:$PATH
    
    # Create unique log file
    log_file="/tmp/kboot-debug-$(date +%Y%m%d-%H%M%S)-$.log"
    
    # Function to log with timestamp
    log() {
      echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" | tee -a "$log_file"
    }
    
    # Start logging
    {
      log "=== KBOOT DEBUG START ==="
      log "Script called with args: $*"
      log "Current working directory: $(pwd)"
      log "Current user: $(id)"
      log "Environment variables:"
      env | sort | sed 's/^/  /'
      
      log "System information:"
      log "  Hostname: $(hostname)"
      log "  Uptime: $(uptime)"
      
      log "Mount information:"
      mount | grep -E "(boot|root|nix)" | sed 's/^/  /'
      
      log "Checking system configuration path: $1"
      if [[ -n "$1" ]]; then
        if [[ -e "$1" ]]; then
          log "  System config exists: $1"
          log "  Real path: $(readlink -f "$1")"
          log "  Contents:"
          ls -la "$1" 2>&1 | sed 's/^/    /'
          
          # Check for required files
          for file in kernel initrd dtbs nixos-version kernel-params; do
            if [[ -e "$1/$file" ]]; then
              log "  ✓ Found $file"
              if [[ "$file" == "dtbs" ]]; then
                log "    DTB contents:"
                ls -la "$1/$file" 2>&1 | head -10 | sed 's/^/      /'
              fi
            else
              log "  ✗ Missing $file"
            fi
          done
        else
          log "  ERROR: System config path does not exist: $1"
        fi
      else
        log "  ERROR: No system config path provided"
      fi
      
      log "Boot partition status:"
      if mountpoint -q /boot 2>/dev/null; then
        log "  ✓ /boot is mounted"
        log "  /boot contents:"
        ls -la /boot 2>&1 | head -10 | sed 's/^/    /'
        
        # Test write permissions
        if touch /boot/.kboot-write-test 2>/dev/null; then
          log "  ✓ /boot is writable"
          rm -f /boot/.kboot-write-test
        else
          log "  ✗ /boot is not writable"
        fi
      else
        log "  ✗ /boot is not mounted"
      fi
      
      log "Process information:"
      ps aux | grep -E "(nixos-rebuild|systemd)" | head -5 | sed 's/^/  /'
      
      log "Nix store status:"
      log "  Nix store mount: $(df -h /nix/store | tail -1)"
      
      log "=== EXECUTING ORIGINAL BUILDER ==="
      log "Command: ${builder} ${args} $*"
      
    } 2>&1 | tee -a "$log_file"
    
    # Execute the original builder and capture its output
    if /run/current-system/sw/bin/bash ${builder} ${args} "$@" 2>&1 | tee -a "$log_file"; then
      log "=== KBOOT DEBUG SUCCESS ==="
      echo "Debug log saved to: $log_file" >&2
    else
      exit_code=$?
      log "=== KBOOT DEBUG FAILED (exit code: $exit_code) ==="
      echo "Debug log saved to: $log_file" >&2
      echo "KBOOT INSTALLATION FAILED - Check $log_file for details" >&2
      exit $exit_code
    fi
  '';

in {
  options = {
    boot.loader.kboot-conf = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether to create petitboot-compatible /kboot.conf
        '';
      };
      
      debug = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether to enable debugging output for kboot configuration generation.
          Logs will be written to /tmp/kboot-debug-*.log
        '';
      };
      
      configurationLimit = mkOption {
        default = 10;
        example = 5;
        type = types.int;
        description = ''
          Maximum number of configurations in the generated kboot.conf.
        '';
      };
      
      populateCmd = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          Contains the builder command used to populate an image,
          honoring all options except the <literal>-c &lt;path-to-default-configuration&gt;</literal>
          argument.
          Useful to have for sdImage.populateRootCommands
        '';
      };
    };
  };
  
  config = let
    args = "-g ${toString cfg.configurationLimit} -n ${config.hardware.deviceTree.name}";
    
    # Choose between debug and normal builder
    activeBuilder = if cfg.debug then (mkDebugBuilder args) else builder;
    
  in mkIf cfg.enable {
    system.build.installBootLoader = lib.mkForce "${activeBuilder} ${args} -c";
    system.boot.loader.id = "kboot-conf";
    boot.loader.kboot-conf.populateCmd = "${populateBuilder} ${args}";
    
    # Warn user about debug mode
    warnings = lib.optional cfg.debug
      "kboot-conf debug mode is enabled. Debug logs will be written to /tmp/kboot-debug-*.log";
  };
}

{
  lib,
  pkgs,
  config,
  ...
}: let
  # Script to generate DNS records from Consul services with Traefik tags
  consulDnsSync = pkgs.writeShellScript "consul-dns-sync" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOCK_FILE="/var/run/consul-dns-sync.lock"
    HOSTS_FILE="/var/lib/coredns/consul-hosts"
    TEMP_FILE="/tmp/consul-hosts.tmp"
    LAST_UPDATE_FILE="/var/run/consul-dns-sync.last"
    MIN_UPDATE_INTERVAL=5  # Minimum seconds between updates
    
    # Simple file-based locking to prevent concurrent runs
    if [ -f "$LOCK_FILE" ]; then
      LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0)))
      if [ $LOCK_AGE -lt 60 ]; then
        echo "[$(date)] Sync already running, skipping" >&2
        exit 0
      else
        echo "[$(date)] Stale lock detected, removing" >&2
        rm -f "$LOCK_FILE"
      fi
    fi
    
    # Check if we updated too recently (debouncing)
    if [ -f "$LAST_UPDATE_FILE" ]; then
      LAST_UPDATE=$(cat "$LAST_UPDATE_FILE")
      CURRENT_TIME=$(date +%s)
      TIME_SINCE_LAST=$((CURRENT_TIME - LAST_UPDATE))
      
      if [ $TIME_SINCE_LAST -lt $MIN_UPDATE_INTERVAL ]; then
        echo "[$(date)] Updated $TIME_SINCE_LAST seconds ago, debouncing (min: $MIN_UPDATE_INTERVAL)" >&2
        exit 0
      fi
    fi
    
    touch "$LOCK_FILE"
    trap "rm -f $LOCK_FILE" EXIT
    
    echo "[$(date)] Starting DNS sync from Consul" >&2
    
    # Query Consul API directly (more reliable than stdin during flapping)
    SERVICES=$(${pkgs.curl}/bin/curl -sf http://localhost:8500/v1/health/state/any 2>/dev/null || echo "[]")
    
    if [ "$SERVICES" = "[]" ] || [ -z "$SERVICES" ]; then
      echo "[$(date)] Failed to fetch services from Consul, keeping existing hosts" >&2
      exit 0
    fi
    
    # Generate hosts file from services with traefik tags
    echo "# Auto-generated from Consul services - $(date)" > "$TEMP_FILE"
    
    # Parse the Consul services data
    echo "$SERVICES" | ${pkgs.jq}/bin/jq -r '
      .[] | 
      select(.Service.Tags != null) |
      {
        tags: .Service.Tags,
        address: (.Service.Address // .Node.Address),
        port: .Service.Port,
        status: .Status
      } |
      select(.status == "passing" or .status == "warning") |
      .tags[] |
      select(startswith("traefik.http.routers.") and contains(".rule=Host")) |
      . as $tag |
      ($tag | capture("Host\\((?<hosts>[^)]+)\\)") | .hosts | gsub("[`\"\\s]"; "") | split(",")[]) as $host |
      {
        host: $host,
        address: input.address
      }
    ' 2>/dev/null | ${pkgs.jq}/bin/jq -s 'unique_by(.host) | .[]' 2>/dev/null | while read -r line; do
      HOST=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.host // empty' 2>/dev/null)
      ADDRESS=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.address // empty' 2>/dev/null)
      
      if [ ! -z "$HOST" ] && [ ! -z "$ADDRESS" ] && [ "$ADDRESS" != "null" ]; then
        echo "$ADDRESS $HOST" >> "$TEMP_FILE"
        echo "[$(date)] Added: $ADDRESS -> $HOST" >&2
      fi
    done
    
    # Add static entries for critical services (always accessible even during flapping)
    # These ensure you can always reach Nomad/Consul UIs
    echo "# Static critical services - always available" >> "$TEMP_FILE"
    echo "192.168.4.250 consul.fbleagh.duckdns.org" >> "$TEMP_FILE"
    echo "192.168.4.250 nomad.fbleagh.duckdns.org" >> "$TEMP_FILE"
    # Only update if there were actual changes
    if ! cmp -s "$TEMP_FILE" "$HOSTS_FILE" 2>/dev/null; then
      cp "$TEMP_FILE" "$HOSTS_FILE"
      date +%s > "$LAST_UPDATE_FILE"
      echo "[$(date)] DNS hosts file updated, reloading CoreDNS" >&2
      ${pkgs.systemd}/bin/systemctl reload coredns.service 2>/dev/null || true
    else
      echo "[$(date)] No changes detected, skipping reload" >&2
    fi
    
    rm -f "$TEMP_FILE"
  '';
in {
  # Create CoreDNS configuration file with increased cache and stability
  environment.etc."coredns/Corefile".text = ''
    # Handle .consul domain - forward ALL to Consul
    consul:53 {
      forward . 127.0.0.1:8600
      cache 30
      errors
      log {
        class error
      }
    }

    # Handle fbleagh.duckdns.org domain
    fbleagh.duckdns.org:53 {
      # Load dynamic hosts from Consul (now in writable location)
      hosts /var/lib/coredns/consul-hosts {
        ttl 60
        reload 5s
        fallthrough
      }
      
      # Forward service.* queries to Consul with retries
      forward service.dc1.fbleagh.duckdns.org 127.0.0.1:8600 {
        max_fails 3
        expire 10s
        health_check 5s
      }
      
      # Cache aggressively to handle flapping
      cache 300 {
        success 4096
        denial 1024
        prefetch 10
      }
      
      # Fallback to upstream DNS
      forward . 8.8.8.8 1.1.1.1 {
        max_fails 3
        expire 10s
        health_check 5s
      }
      
      errors
      log {
        class error
      }
    }

    # Handle all other DNS queries
    .:53 {
      forward . 192.168.4.1 8.8.8.8 {
        max_fails 3
        expire 10s
        health_check 5s
      }
      
      cache 300 {
        success 4096
        denial 1024
      }
      
      errors
      log {
        class error
      }
    }
  '';

  # Create initial hosts file with critical services
  environment.etc."coredns/consul-hosts".text = ''
    # Placeholder - will be populated by consul-watch
    # Static critical services - always available
    192.168.4.250 consul.fbleagh.duckdns.org
    192.168.4.250 nomad.fbleagh.duckdns.org
  '';

  # Create writable directory for dynamic hosts file
  systemd.tmpfiles.rules = [
    "d /var/lib/coredns 0755 root root -"
    "f /var/lib/coredns/consul-hosts 0644 root root - # Placeholder\n192.168.4.250 consul.fbleagh.duckdns.org\n192.168.4.250 nomad.fbleagh.duckdns.org"
  ];

  # Systemd service for Consul watch with rate limiting
  systemd.services.consul-watch = {
    description = "Consul watch for DNS updates";
    after = ["consul.service" "coredns.service"];
    requires = ["consul.service"];
    wantedBy = ["multi-user.target"];
    
    serviceConfig = {
      Type = "simple";
      # Wait for Consul before starting watch, and execute watch
      ExecStart = pkgs.writeShellScript "run-consul-watch" ''
        until ${pkgs.curl}/bin/curl -sf http://localhost:8500/v1/status/leader > /dev/null 2>&1; do
          sleep 2
        done
        exec ${pkgs.consul}/bin/consul watch -type=service -service=.* -passingonly=false ${consulDnsSync}
      '';
      
      # Treat connection drops (exit 1) as a graceful reset so it doesn't report as "failed"
      SuccessExitStatus = [ 1 ];
      Restart = "always";
      RestartSec = "5s";
      User = "root";
      
      # Rate limiting: max 10 starts in 30 seconds
      StartLimitIntervalSec = 30;
      StartLimitBurst = 10;
      
      # Logging - only errors to reduce noise
      StandardOutput = "journal";
      StandardError = "journal";
      
      # Resource limits to prevent runaway during flapping
      CPUQuota = "25%";
      MemoryMax = "128M";
    };
  };

  # Initial sync on boot
  systemd.services.consul-dns-initial-sync = {
    description = "Initial DNS sync from Consul";
    after = ["consul.service" "coredns.service"];
    requires = ["consul.service" "coredns.service"];
    wantedBy = ["multi-user.target"];
    
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "initial-sync" ''
        # Wait for Consul to be ready
        timeout=60
        elapsed=0
        until ${pkgs.curl}/bin/curl -sf http://localhost:8500/v1/status/leader > /dev/null 2>&1; do
          if [ $elapsed -ge $timeout ]; then
            echo "Timeout waiting for Consul"
            exit 1
          fi
          echo "Waiting for Consul..."
          sleep 2
          elapsed=$((elapsed + 2))
        done
        
        # Run initial sync
        ${consulDnsSync}
      '';
      User = "root";
      TimeoutStartSec = "90s";
    };
  };

  # Backup timer-based sync as fallback (every 5 minutes)
  systemd.services.consul-dns-timer-sync = {
    description = "Periodic DNS sync from Consul (fallback)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${consulDnsSync}";
      User = "root";
    };
  };

  systemd.timers.consul-dns-timer-sync = {
    description = "Periodic DNS sync timer";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
    };
  };

  # Create systemd service for CoreDNS
  systemd.services.coredns = {
    description = "CoreDNS DNS server";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.coredns}/bin/coredns -conf /etc/coredns/Corefile";
      ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR1 $MAINPID";
      Restart = "on-failure";
      RestartSec = "5s";
      
      # Rate limiting for reloads
      ReloadPropagatedFrom = [];
      
      # Security hardening
      DynamicUser = true;
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = "/var/lib/coredns";
    };
  };

  # Open firewall for CoreDNS
  networking.firewall = {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };
}

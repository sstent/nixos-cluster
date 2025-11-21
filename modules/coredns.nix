{
  lib,
  pkgs,
  config,
  ...
}: let
  # 1. Merged Hosts Template
  consulAllHostsTemplate = pkgs.writeText "consul-all-hosts.ctmpl" ''
# --- Static Hosts from Consul KV ---
{{ printf "\n" }}
{{- range ls "dns/hosts" -}}
{{ .Value }} {{ .Key }}
{{ printf "\n" }}
{{- end -}}

# --- Dynamic Hosts from Consul Services (Traefik Tags) ---
{{ printf "\n" }}
{{- range services -}}
  {{- range service .Name -}}
    {{- /* Determine IP: Use Service Address, fall back to Node Address */ -}}
    {{- $ip := .Address -}}
    {{- if eq $ip "" -}}
      {{- $ip = .NodeAddress -}}
    {{- end -}}

    {{- /* Scan Tags */ -}}
    {{- range .Tags -}}
      {{- if . | regexMatch "traefik.http.routers.*.rule=Host" -}}
        
        {{- /* 1. Extract content inside Host(...) */ -}}
        {{- $content := . | regexReplaceAll ".*Host\\(([^)]+)\\).*" "$1" -}}

        {{- /* 2. Clean up quotes and spaces */ -}}
        {{- $clean := $content | regexReplaceAll "[`'\"\\s]" "" -}}

        {{- /* 3. Split by comma and print */ -}}
        {{- range split "," $clean -}}
          {{- if ne . "" -}}
{{ $ip }} {{ . }}
{{ printf "\n" }}
          {{- end -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
  '';

  # 2. Wrapper script to ensure clean execution and environment setup
  consulTemplateWrapper = pkgs.writeShellScript "consul-template-wrapper" ''
    # Only render the single merged template file
    ${pkgs.consul-template}/bin/consul-template \
      -template "${consulAllHostsTemplate}:/etc/coredns/consul-all-hosts:${pkgs.systemd}/bin/systemctl reload coredns" \
      -log-level info
  '';

in {
  # --- CoreDNS Configuration ---
  environment.etc."coredns/Corefile".text = ''
    # Forward Consul DNS queries to the local Consul Agent
    consul:53 {
      forward . 127.0.0.1:8600
      cache 30
      errors
      log
    }

    # Handle custom domain
    fbleagh.duckdns.org:53 {
      # CRITICAL FIX: Use only one hosts file/plugin definition
      hosts /etc/coredns/consul-all-hosts {
        fallthrough
      }
      # Fallback to upstream DNS
      forward . 192.168.4.1 8.8.8.8
      cache 30
      errors
      log
    }

    # Handle all other DNS queries
    .:53 {
      forward . 192.168.4.1 8.8.8.8
      cache 30
      errors
      log
    }
  '';

  systemd.tmpfiles.rules = [
    "f /etc/coredns/consul-all-hosts 0644 root root - #"
  ];

  # --- Consul Template Service ---
  systemd.services.consul-template = {
    description = "Consul Template for CoreDNS Hosts";
    wantedBy = ["multi-user.target"];
    after = ["consul.service" "coredns.service" "network.target"];
    requires = ["coredns.service"]; 

    serviceConfig = {
      # Use the robust wrapper script
      ExecStart = "${consulTemplateWrapper}";
      
      Restart = "always";
      RestartSec = "10s";
    };
  };

  # --- CoreDNS Service ---
  systemd.services.coredns = {
    description = "CoreDNS DNS server";
    wantedBy = ["multi-user.target"];
    requires = ["consul.service"];
    after = ["network.target" "consul.service"];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.coredns}/bin/coredns -conf /etc/coredns/Corefile";
      ExecReload = "${pkgs.coreutils}/bin/kill -SIGUSR1 $MAINPID";
      Restart = "on-failure";
      RestartSec = "5s";
      DynamicUser = true;
      AmbientCapabilities = "CAP_NET_BIND_SERVICE";
      CapabilityBoundingSet = "CAP_NET_BIND_SERVICE";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = "/etc/coredns";
    };
  };

  # --- Helper Scripts and Firewall ---
  environment.systemPackages = [
    pkgs.consul-template
    (pkgs.writeShellScriptBin "debug-consul-template" ''
      echo "Rendering template to stdout..."
      ${pkgs.consul-template}/bin/consul-template \
        -template "${consulAllHostsTemplate}:-" \
        -dry | grep -v "^$"
    '') # <--- This is the crucial closing of the multi-line string
  ];

  networking.firewall = {
    allowedTCPPorts = [53];
    allowedUDPPorts = [53];
  };
}

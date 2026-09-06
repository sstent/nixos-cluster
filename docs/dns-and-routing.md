---
author: "agent:antigravity"
title: "Cluster DNS and Ingress Routing Architecture"
type: "concept"
tags: [projects/cluster, networking, dns, proxy, haproxy, traefik, consul]
created: 2026-07-21
updated: 2026-09-06
summary: "Authoritative reference for cluster DNS zones, domain usage, resolution pathways across OpenWrt/CoreDNS/Consul, and edge ingress routing through HAProxy and Traefik."
aliases: [cluster-dns, dns-and-routing]
---

# Cluster DNS and Ingress Routing Architecture

This document is the authoritative reference for domain name allocation, DNS resolution flows, and ingress proxy routing across the home cluster and local network.

---

## 1. Domain Taxonomy & Usage Matrix

| Domain Pattern | Primary Use Case | Target / Resolution | Accessibility | DNS Handler |
| :--- | :--- | :--- | :--- | :--- |
| **`*.service.dc1.consul`**<br>`*.node.dc1.consul` | Internal Nomad service discovery, RPC, inter-container traffic, HAProxy dynamic backends, Prometheus scrapers. | Service/Node IP + Dynamic Port | Cluster & LAN only | **Consul DNS** (`:8600`) |
| **`*-local.fbleagh.duckdns.org`** | Direct internal service access using single-level subdomains covered natively by public wildcard certificate `*.fbleagh.duckdns.org` without WAN exposure (e.g. `gitea-local`, `grafana-local`, `status-local`, `homepage-local`, `hass-local`). | Node/Service IP | Cluster & LAN only *(explicitly blocked on WAN edge via HAProxy)* | **CoreDNS :53 bidirectional rewrite** $\to$ Consul DNS (`<service>.service.dc1.consul`) |
| **`*.service.dc1.fbleagh.duckdns.org`** | *(Legacy / Deprecated)* Legacy multi-level domain for internal services. Kept for transition backward compatibility. | Node/Service IP | Cluster & LAN only | **CoreDNS :53 $\to$ Consul DNS :8600** (`alt_domain`) |
| **`consul.fbleagh.duckdns.org`**<br>`nomad.fbleagh.duckdns.org` | Cluster control-plane web dashboards (Consul UI on `:8500`, Nomad UI on `:4646`). Direct bypass avoiding reverse proxy layers. | `192.168.4.250` (Keepalived VIP) | Cluster & LAN only | **CoreDNS Static Hosts** (`/var/lib/coredns/consul-hosts`) |
| **`*.fbleagh.duckdns.org`** | Public and user-facing apps (`notes.`, `vault.`, `immich.`, `abs.`, `m.`, `miniflux.`, `fittrack.`, `gotify.`, `mail.`). | WAN Public IP (`75.142.195.167`) | LAN (Hairpin) & WAN Internet | **DuckDNS Public DNS** $\to$ OpenWrt DNAT $\to$ HAProxy $\to$ Traefik |
| **`*.fbleagh.dedyn.io`** | Secondary / backup dynamic DNS namespace (deSEC) for failover and dual-SAN wildcard certificates. | WAN Public IP | LAN & WAN Internet | **deSEC Public DNS** |
| **`*.lan`** | Router administration (`console.gl-inet.com`), static appliances (IPKVM, smart TVs, laundry). | `192.168.4.x` | LAN only | **OpenWrt dnsmasq** (`192.168.4.1`) |
| **`4.168.192.in-addr.arpa`** | Reverse DNS lookups for cluster and LAN nodes. | Node FQDN | Cluster & LAN | **Consul DNS** (delegated by OpenWrt) |

---

## 2. DNS Infrastructure Layers

```mermaid
flowchart TD
    subgraph Clients
        LAN[LAN Client / Workstation]
        NODE[NixOS Cluster Node]
        EXT[External Internet Client]
    end

    subgraph OpenWrt ["OpenWrt Gateway (192.168.4.1)"]
        DNSMASQ[dnsmasq :53]
        FW[Firewall / NAT Port 80,443]
        HAPROXY[HAProxy :8082, :8445]
    end

    subgraph ClusterVIP ["Keepalived VIP (192.168.4.250)"]
        COREDNS[CoreDNS :53]
        CONSUL[Consul DNS :8600<br/>alt_domain: fbleagh.duckdns.org]
    end

    subgraph NomadCluster ["Nomad Nodes"]
        TRAEFIK[Traefik :80, :443<br/>Wildcard TLS from Consul KV]
        TASKS[Services & Containers]
    end

    subgraph External ["Public Internet"]
        DUCKDNS[DuckDNS / deSEC Nameservers]
    end

    %% DNS Queries
    LAN -->|DNS Query| DNSMASQ
    NODE -->|Nameserver 192.168.4.250| COREDNS

    DNSMASQ -->|/consul/ & reverse DNS| CONSUL
    DNSMASQ -->|/fbleagh.duckdns.org/| COREDNS
    DNSMASQ -->|*.lan & WAN fallback| DUCKDNS

    COREDNS -->|consul:53| CONSUL
    COREDNS -->|service.dc1.fbleagh.duckdns.org| CONSUL
    COREDNS -->|Static VIP overrides| ClusterVIP
    COREDNS -->|Fallthrough public| DUCKDNS

    %% Traffic Routing
    EXT -->|Resolves to WAN IP| DUCKDNS
    EXT -->|TCP 80/443 to WAN IP| FW
    LAN -->|TCP 80/443 to WAN IP (Hairpin)| FW
    FW -->|DNAT| HAPROXY

    HAPROXY -->|Denied if *.service.dc1.*| EXT
    HAPROXY -->|Forward to Traefik :443| TRAEFIK
    HAPROXY -->|Direct Service Backend| TASKS
    TRAEFIK -->|Forward with Auth & TLS| TASKS
```

### 1. OpenWrt Gateway (`192.168.4.1`)
- **Software**: `dnsmasq`
- **DHCP**: Distributes `192.168.4.1` as default DNS gateway to general LAN devices.
- **Selective Forwarding Rules** (`/etc/config/dhcp`):
  - Forward `.consul` $\to$ Consul servers: `192.168.4.36#8600`, `192.168.4.227#8600`, `192.168.4.228#8600`.
  - Forward `fbleagh.duckdns.org` $\to$ CoreDNS instances on cluster nodes (`192.168.4.36`, `192.168.4.227`, `192.168.4.228`).
  - Forward `4.168.192.in-addr.arpa` $\to$ Consul DNS for reverse resolution.
- **Dynamic DNS**: `ddns-scripts` automatically updates `fbleagh.duckdns.org` when the WAN interface IPv4 changes.

### 2. Cluster Keepalived VIP (`192.168.4.250`)
- **Mechanism**: VRRP via `keepalived.nix` electing an active master among cluster nodes (`opti1`, `opti2`, `opti3`, `odroid6`, etc.).
- **Hosts Resolution**:
  NixOS hosts declare:
  ```nix
  networking.nameservers = [ "192.168.4.250" "192.168.4.1" "8.8.8.8" ];
  networking.search = [ "node.dc1.consul" "service.dc1.consul" ];
  ```
  This ensures local lookups hit the cluster VIP first, failing over to OpenWrt and upstream public DNS.

### 3. CoreDNS (`modules/coredns.nix`)
Runs on port 53 across all NixOS cluster nodes:
- **`consul:53`**: Forwards all `.consul` queries to local Consul agent at `127.0.0.1:8600`.
- **`fbleagh.duckdns.org:53`**:
  1. Checks `/var/lib/coredns/consul-hosts` (provides zero-proxy static resolution for `nomad.` and `consul.` to `192.168.4.250`).
  2. **Bidirectional Rewrite for `*-local.fbleagh.duckdns.org`**:
     Rewrites incoming queries for `(.*)-local.fbleagh.duckdns.org` to `{1}.service.dc1.consul` and forwards them to local Consul DNS at `127.0.0.1:8600`. Importantly, it also rewrites the **answer section** RR names back from `.service.dc1.consul` to `-local.fbleagh.duckdns.org` so standard `glibc`/POSIX stub resolvers accept the response:
     ```coredns
     rewrite {
       name regex (.*)-local\.fbleagh\.duckdns\.org {1}.service.dc1.consul
       answer name (.*)\.service\.dc1\.consul {1}-local.fbleagh.duckdns.org
     }
     forward consul 127.0.0.1:8600
     ```
  3. **Legacy Forward**: Forwards `service.dc1.fbleagh.duckdns.org` directly to `127.0.0.1:8600` (Consul DNS `alt_domain`).
  4. Caches aggressively (300s TTL).
  5. **Fallthrough**: Forwards other `*.fbleagh.duckdns.org` subdomains to upstream `8.8.8.8` / `1.1.1.1` to resolve the WAN IP.
- **`.:53`**: Fallback forwarding to OpenWrt gateway `192.168.4.1` and Google DNS `8.8.8.8`.

### 4. HashiCorp Consul DNS (`:8600`)
- Listens on port 8600 on cluster nodes.
- **`alt_domain` Configuration**: In `modules/consul.nix`, Consul is configured with:
  ```nix
  alt_domain = "fbleagh.duckdns.org";
  ```
  This allows Consul to natively answer queries for `<service>.service.dc1.fbleagh.duckdns.org` identically to `<service>.service.dc1.consul`.

---

## 3. Ingress & Traffic Routing Details

### 1. Edge Firewall DNAT (OpenWrt)
External WAN traffic on standard web ports is redirected to HAProxy on the router:
- WAN TCP `80` $\to$ `192.168.4.1:8082`
- WAN TCP `443` $\to$ `192.168.4.1:8445`
- WAN UDP `51820` $\to$ `192.168.4.250:51820` (WireGuard VIP)

### 2. Edge Proxy: HAProxy (`nomad/haproxy.cfg`)
Runs directly on the OpenWrt router (`/etc/haproxy.cfg`):
- **Access Control (Security Boundary)**:
  ```haproxy
  acl is_internal src 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 127.0.0.0/8
  acl is_service_domain hdr_end(host) -i .service.dc1.fbleagh.duckdns.org
  acl is_local_domain hdr_reg(host) -i .*-local\.fbleagh\.duckdns\.org
  http-request deny if is_service_domain !is_internal
  http-request deny if is_local_domain !is_internal
  ```
  Any request arriving from outside the network targeting `*-local.fbleagh.duckdns.org` or `*.service.dc1...` is rejected with HTTP 403.
- **Backend Resolution via Consul**:
  HAProxy queries Consul DNS (`192.168.4.36:8600`, etc.) using SRV templates:
  `server-template <name> 4 _<name>._tcp.service.dc1.consul resolvers consul check`
- **Traefik Handoff**:
  Public application hostnames (`notes.`, `m.`, `fittrack.`, etc.) are routed to `backend_traefik_https` (`_traefik._tcp.service.dc1.consul:443`), delegating auth and application-level routing to Traefik.
- **Direct Backends**:
  Services such as `vault.fbleagh.duckdns.org`, `gitea`, `immich`, and `nginx` have direct backends in HAProxy routing straight to the service instances.

### 3. Application Ingress: Traefik (`nomad_jobs/enabled/traefik.nomad`)
Runs as a Nomad system job across nodes, binding ports 80 and 443:
- **Consul Catalog Provider & Automatic Ingress**:
  Traefik automatically discovers all services registered in Consul. With the default routing rule:
  ```yaml
  defaultRule: "Host(`{{ .Name }}-local.fbleagh.duckdns.org`, `{{ .Name }}.service.dc1.consul`)"
  ```
  Every registered Nomad service automatically receives internal TLS termination matching `*.fbleagh.duckdns.org` without needing custom job tags.
- **TLS Wildcards**: Pulls Let's Encrypt certificates directly from Consul KV:
  - `letsconsul/*.fbleagh.duckdns.org/fullchain.cer`
  - `letsconsul/*.fbleagh.dedyn.io/fullchain.cer`
  Matches single-level `*-local.fbleagh.duckdns.org` subdomains natively per RFC 6125.
- **Authentication**: Integrates with Dex / Forward-Auth (`fwdauth.fbleagh.duckdns.org`). External requests to sensitive apps are required to authenticate, while internal RFC1918 traffic can bypass auth via priority rules.

---

## 4. Wildcard TLS Certificate Automation

Wildcard certificates are managed via the batch job `enabled/acme_sh.nomad`:
1. **Periodic Renewal**: Runs weekly via `acme.sh` Docker container.
2. **DNS-01 Challenge**: Automates TXT verification via DuckDNS API and deSEC API tokens (`DuckDNS_Token`, `DEDYN_TOKEN`).
3. **Storage**: Certs and private keys are written directly into Consul KV at `letsconsul/*.fbleagh.duckdns.org/` and `letsconsul/*.fbleagh.dedyn.io/`.
4. **Hot Reload**: Traefik and HAProxy pull certificates from Consul KV and reload automatically when updated.

---

## 5. Maintenance & Troubleshooting Commands

```bash
# Test internal Consul service discovery
python3 -c "import socket; print(socket.gethostbyname('consul.service.dc1.consul'))"

# Test internal FQDN with TLS cert domain
python3 -c "import socket; print(socket.gethostbyname('gitea.service.dc1.fbleagh.duckdns.org'))"

# Test control-plane VIP static resolution
python3 -c "import socket; print(socket.gethostbyname('nomad.fbleagh.duckdns.org'))"

# Inspect OpenWrt DNS forwarding rules
python scripts/openwrt.py exec "uci show dhcp.@dnsmasq[0].server"

# Inspect CoreDNS hosts on the cluster VIP
ssh root@192.168.4.250 "cat /var/lib/coredns/consul-hosts"

# Inspect active HAProxy configuration on router
python scripts/openwrt.py exec "head -n 40 /etc/haproxy.cfg"
```

## Related Notes
- [[AntiGrav/Projects/Cluster|Cluster Architecture Index]]
- [[AntiGrav/Projects/Cluster/CONTEXT|Cluster Domain Glossary & Context]]
- [[AntiGrav/Projects/Cluster/home-assistant|Home Assistant & NixOS Sidecar Topology]]
- [[AntiGrav/Architecture/nixos-cluster/|NixOS Cluster Architecture]]

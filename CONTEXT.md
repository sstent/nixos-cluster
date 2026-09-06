# nixos-cluster — Domain Context

## Purpose
NixOS flake repository managing cluster node configuration, secrets (SOPS), and Nomad job definitions for the home cluster infrastructure.

## Key Technologies
- **NixOS / Nix Flakes**: All host configuration is declarative via `flake.nix`.
- **SOPS**: Secret encryption via `.sops.yaml` and age keys.
- **Nomad HCL**: Job specs in `jobs/` co-located with cluster config.

## Repository Layout
```
hosts/          # Per-host NixOS configurations
modules/        # Shared NixOS modules
overlays/       # Nix overlays and package overrides
jobs/           # Nomad HCL job specs
secrets/        # SOPS-encrypted secrets
scripts/        # Helper scripts
flake.nix       # Root flake definition
justfile        # Task runner (just)
```

## Architecture Reference
- Cluster architecture and node topology: `AntiGrav/Projects/Cluster/index.md`
- DNS and network: `docs/dns-and-routing.md` (and `AntiGrav/Projects/Cluster/dns-and-routing.md` in SilverBullet)
- Full architecture notes: `AntiGrav/Architecture/nixos-cluster/` in SilverBullet.

## Key Commands
```bash
# Rebuild and switch a specific host
nixos-rebuild switch --flake .#<hostname> --target-host <hostname>

# Run using justfile
just build <hostname>
just deploy <hostname>
```

## Change Management
- All NixOS changes go through flake.nix or per-host config in `hosts/`.
- Secrets are managed via SOPS — never commit unencrypted secrets.
- See `AntiGrav/Tasks/nixos-cluster/` in SilverBullet for active tasks.

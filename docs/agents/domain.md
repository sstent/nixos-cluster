# Domain Docs: nixos-cluster

## Primary Context
The primary domain context file is `CONTEXT.md` in the repository root. Read it first before making any changes.

## Architecture Notes
Extended architecture documentation lives in SilverBullet at:
- `AntiGrav/Projects/Cluster/index.md` — Cluster-level overview
- `AntiGrav/Architecture/nixos-cluster/` — nixos-cluster-specific ADRs and design notes

## ADR Convention
Architectural Decision Records are stored as SilverBullet pages:
```
AntiGrav/Architecture/nixos-cluster/adr-NNN-<slug>.md
```

## Reading Domain Context
```bash
# Search for architecture notes
python skills/silverbullet/scripts/sb.py search "nixos-cluster" --content

# List architecture docs
python skills/silverbullet/scripts/sb.py list --prefix "AntiGrav/Architecture/nixos-cluster/"
```

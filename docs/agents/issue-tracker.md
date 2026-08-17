# Issue Tracker: SilverBullet

Issues, specs, and Wayfinder tickets for this repo live centrally in your SilverBullet knowledge base. To prevent clutter, active tasks are separated from long-term project architecture.

## CLI Tool Reference

All interactions with SilverBullet MUST be executed via the `sb.py` skill helper. Run these from the repository root:

```bash
# Read a page
python skills/silverbullet/scripts/sb.py read "<path>"

# Write / update a page
python skills/silverbullet/scripts/sb.py write "<path>" --content "<markdown>"

# Search
python skills/silverbullet/scripts/sb.py search "<query>" --content

# Delete a page
python skills/silverbullet/scripts/sb.py delete "<path>"
```

## Conventions & Paths

- **Active Tasks**: `AntiGrav/Tasks/nixos-cluster/YYYY-MM-DD-<slug>.md` or `AntiGrav/Tasks/nixos-cluster/NN-<slug>.md`
- **Project Architecture / Maps**: `AntiGrav/Projects/nixos-cluster/<Document>.md`
- **Archived Tasks**: `AntiGrav/Archive/Tasks/nixos-cluster/YYYY-MM-DD-<slug>.md`

## Frontmatter Schema

Every ticket MUST include this exact YAML block. Use `parent` to link tickets back to their originating spec or Wayfinder map.

```yaml
---
title: "<Ticket Title>"
repo: "nixos-cluster"
parent: "[[AntiGrav/Projects/nixos-cluster/Wayfinder]]"
status: open | ready-for-agent | claimed | resolved
type: task | research | bug | spike
tags: [task, nixos-cluster]
blockedBy: []
created: YYYY-MM-DD
author: "agent:antigravity"
---
```

## Skill Operations

### 1. Publishing to the Tracker (e.g., `/to-tickets`, `/to-spec`)

1. Determine the repo name (from the git remote or root folder name).
2. Generate the ticket markdown, strictly adhering to the frontmatter schema above. Ensure `parent` links to the correct spec document if applicable.
3. Call `sb.py write` targeting `AntiGrav/Tasks/nixos-cluster/`.

### 2. Fetching & Reading Tickets

1. If the exact path is unknown, call `sb.py search` first to locate it.
2. Call `sb.py read` targeting the retrieved path.

### 3. Wayfinder Operations (`/wayfinder`)

- **Map Page**: `AntiGrav/Projects/nixos-cluster/Wayfinder.md`
- **Child Tickets**: `AntiGrav/Tasks/nixos-cluster/NN-<slug>.md`
- **Claiming a Ticket**: Read the ticket, update frontmatter to `status: claimed`, overwrite via `sb.py write`.
- **Resolving a Ticket**:
  1. Append a `## Answer` or `## Resolution` section to the ticket body.
  2. Update frontmatter to `status: resolved`.
  3. Update `AntiGrav/Projects/nixos-cluster/Wayfinder.md` to reflect completion and link to the ticket.
- **Archive (Optional Cleanup)**: If instructed to archive, write the ticket to `AntiGrav/Archive/Tasks/nixos-cluster/<ticket_name>.md`, then `sb.py delete` the original to prevent directory bloat.

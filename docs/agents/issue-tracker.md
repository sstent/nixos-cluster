# Issue Tracker: nixos-cluster

Tasks, specs, and issues for this repository are tracked in SilverBullet.

## Location
`AntiGrav/Tasks/nixos-cluster/` in the SilverBullet knowledge base.

## Usage

```bash
# List open tasks
python skills/silverbullet/scripts/sb.py list --prefix "AntiGrav/Tasks/nixos-cluster/"

# Read a task
python skills/silverbullet/scripts/sb.py read "AntiGrav/Tasks/nixos-cluster/<task-name>"

# Create a new task
python skills/silverbullet/scripts/sb.py write "AntiGrav/Tasks/nixos-cluster/<task-name>.md" --content "<content>"
```

## YAML Frontmatter Template
```yaml
---
title: "<Task Title>"
status: "open"          # open | in-progress | done | wontfix
type: "task"            # task | bug | feature | adr
repo: "nixos-cluster"
created: "YYYY-MM-DD"
---
```

# claude-skills

A collection of custom skills for Claude Code.

## Setup

```bash
./setup.sh
```

The setup script symlinks this repo's `skills/` directory to `~/.claude/skills`, making all skills in this repo available to Claude Code. If `~/.claude/skills` already exists as a regular directory, it gets backed up to `~/.claude/skills.bak` first.

## Skills

| Skill | Trigger | Description |
|---|---|---|
| `disk-usage` | `/disk-usage` | Scans the disk for space usage, breaks down by directory, and surfaces cleanup opportunities. |
| `review-branch` | `/review-branch` | Spawns 15 agents (5 categories × 3 agents) to review the current branch diff with consensus voting and falsification to eliminate false positives. |

## Adding a new skill

1. Create a directory under `skills/` with a `SKILL.md` file.
2. The frontmatter `name` and `description` fields control how the skill appears in Claude Code.
3. The markdown body is the prompt Claude follows when the skill is invoked.

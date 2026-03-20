# claude-memory

Persistent memory management for Claude Code — automatic context preservation, archival of stale sessions, and seamless restore across conversations.

## What it does

Claude Code loses all context when a conversation ends. **claude-memory** fixes this by:

- **Auto-creating** a `MEMORY.md` file for every project you open in Claude Code
- **Persisting** key decisions, current state, and session history across conversations
- **Archiving** stale memory files to save tokens in the system prompt
- **Auto-restoring** archived memory when you reopen a project

## How it works

```
You open a project in Claude Code
        ↓
Claude checks for MEMORY.md → creates one if missing (or restores from archive)
        ↓
During work, Claude updates MEMORY.md with state, decisions, paths
        ↓
Next session, Claude reads MEMORY.md and picks up where you left off
        ↓
After 7+ days of inactivity, MEMORY.md is archived (saves tokens)
        ↓
Reopen the project → archived memory is auto-restored
```

## Installation

```powershell
git clone https://github.com/lucasdcorrea1/claude-memory.git
cd claude-memory
.\install.ps1
```

### Options

```powershell
# Custom archival threshold (default: 7 days)
.\install.ps1 -ArchiveDays 14

# Skip scheduled task creation
.\install.ps1 -NoScheduledTask

# Skip CLAUDE.md configuration
.\install.ps1 -NoClaude

# Overwrite existing installation
.\install.ps1 -Force
```

### What the installer does

1. Copies scripts to `~/.claude/tools/claude-memory/`
2. Creates `~/.claude/archive/` directory
3. Adds context preservation rules to `~/.claude/CLAUDE.md` (safe merge, won't overwrite existing rules)
4. Creates a daily scheduled task to archive stale memory files (optional)

## Uninstallation

```powershell
.\uninstall.ps1
```

Removes scripts and scheduled task. **Does not remove** your CLAUDE.md rules or memory data.

## Manual usage

```powershell
$scripts = "$env:USERPROFILE\.claude\tools\claude-memory"

# Archive stale files (inactive > 7 days)
pwsh -File "$scripts\archive-stale.ps1" -Days 7

# Preview what would be archived
pwsh -File "$scripts\archive-stale.ps1" -DryRun

# List archived projects
pwsh -File "$scripts\archive-stale.ps1" -List

# Restore an archived project
pwsh -File "$scripts\archive-stale.ps1" -Restore -Project "my-project"

# Save a manual snapshot
pwsh -File "$scripts\save-context.ps1" -Project "my-project"

# Load latest snapshot
pwsh -File "$scripts\load-context.ps1" -Project "my-project"

# List snapshots
pwsh -File "$scripts\list-contexts.ps1" -Project "my-project"

# Clean up old snapshots
pwsh -File "$scripts\cleanup-contexts.ps1" -Project "my-project" -Keep 10
```

## File structure

```
~/.claude/
├── CLAUDE.md                              # Global rules (auto-init, archival, etc.)
├── tools/
│   └── claude-memory/                     # Installed scripts
│       ├── archive-stale.ps1
│       ├── save-context.ps1
│       ├── load-context.ps1
│       ├── list-contexts.ps1
│       ├── cleanup-contexts.ps1
│       ├── init-project.ps1
│       └── auto-save-hook.ps1
├── projects/                              # Active memory (loaded by Claude Code)
│   ├── D--Development-my-app/
│   │   └── memory/
│   │       └── MEMORY.md                  # ← loaded into system prompt
│   └── D--Development-old-app/
│       └── memory/                        # ← empty (archived)
└── archive/                               # Archived memory (NOT loaded)
    └── D--Development-old-app/
        └── MEMORY.md                      # ← waiting for restore
```

## Requirements

- Windows with PowerShell 7+ (`pwsh`)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- Git (for installation)

## License

MIT

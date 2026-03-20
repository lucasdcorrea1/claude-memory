## Context Preservation
Follow these rules in EVERY session to maintain continuity across conversations:

### Session Start (Auto-Initialization)
- A `PreToolUse` hook automatically initializes MEMORY.md when it is empty or restores it from archive
- If you see a `[claude-memory]` message from the hook, **read the MEMORY.md file immediately** to load the project context
- If MEMORY.md **has content** in the system prompt: use it as context, acknowledge current state if the user asks to continue
- If MEMORY.md **is empty** in the system prompt and no hook message appeared:
  1. Derive the `<project>` key: take the primary working directory, replace `:` `\` `/` with `-`
     - Example: `D:\Development\my-app` → `D--Development-my-app`
  2. Check for an archived version at `~/.claude/archive/<project>/MEMORY.md`
  3. If **archived version exists**: restore it (copy then delete) from `archive/<project>/` back to `projects/<project>/memory/MEMORY.md`, then read it
  4. If **no archived version**: create a new MEMORY.md using the template below at `~/.claude/projects/<project>/memory/MEMORY.md`
- This ensures context tracking works automatically in ANY project without manual setup

### During Work
- After completing a significant task (feature, bug fix, refactor), update MEMORY.md:
  - Update "Current State" with what was just done
  - Add key decisions to "Key Decisions" if any were made
  - Add new important file paths to "Important Paths" if discovered
- Keep MEMORY.md under 150 lines to avoid truncation (the system loads first 200 lines)

### Before Ending / On Request
- When the user says "save context", "save state", or before a natural end of session:
  - Update MEMORY.md "Current State" with exactly where things stand
  - Update "Session Log" with a 2-3 line summary of this session
  - Keep only the last 5 sessions in the log (remove oldest)

### Context Snapshot Scripts (Optional)
- Scripts are installed at `~/.claude/tools/claude-memory/`
- `save-context.ps1 -Project <name>` — saves a timestamped snapshot
- `load-context.ps1 -Project <name>` — loads the latest snapshot
- `list-contexts.ps1 -Project <name>` — lists all snapshots
- `cleanup-contexts.ps1 -Project <name> -Keep <n>` — keeps only the last N snapshots
- `archive-stale.ps1 -Days <n>` — archives MEMORY.md files inactive for more than N days
- `archive-stale.ps1 -List` — lists all archived projects
- `archive-stale.ps1 -Restore -Project <name>` — restores an archived MEMORY.md

### MEMORY.md Template
When auto-creating MEMORY.md for a new project, use this exact format:
```
# Project Memory: <project path>

## Current State
- Project initialized on <current date YYYY-MM-DD>
- No active work tracked yet

## Key Decisions
- (none yet)

## Important Paths
- Project root: <project path>

## Session Log
```

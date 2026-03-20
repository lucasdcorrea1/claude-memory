<#
.SYNOPSIS
    PreToolUse hook: auto-initializes MEMORY.md if empty or restores from archive.
    Exits fast when MEMORY.md has content (exit 0).
    When MEMORY.md is empty, initializes it and BLOCKS the tool call (exit 2)
    so Claude sees the message and re-reads the file.
    Compatible with PowerShell 5.1+ (powershell.exe).
#>
$ErrorActionPreference = "SilentlyContinue"

# --- Determine project directory ---
$projectDir = $null

# Method 1: Read cwd from stdin (Claude Code pipes JSON with tool info)
try {
    $stdinText = @($input) -join ""
    if ($stdinText) {
        $json = $stdinText | ConvertFrom-Json
        if ($json.cwd) { $projectDir = $json.cwd }
    }
} catch {}

# Method 2: PowerShell working directory
if (-not $projectDir) {
    $loc = (Get-Location).Path
    if ($loc -and $loc -ne $env:USERPROFILE) {
        $projectDir = $loc
    }
}

# Method 3: .NET process working directory
if (-not $projectDir) {
    $netDir = [System.Environment]::CurrentDirectory
    if ($netDir -and $netDir -ne $env:USERPROFILE) {
        $projectDir = $netDir
    }
}

if (-not $projectDir) {
    exit 0
}

# Derive Claude's project folder name (same logic as Claude Code)
$normalizedPath = $projectDir -replace "[:\\\/]", "-"
$claudeBase = Join-Path $env:USERPROFILE ".claude"

# NOTE: Use 2-arg Join-Path only — PS 5.1 does not support 3+ args
$memoryFile = Join-Path $claudeBase "projects\$normalizedPath\memory\MEMORY.md"

# Fast exit: file doesn't exist (Claude Code hasn't created the dir yet)
if (-not (Test-Path $memoryFile)) {
    exit 0
}

# Fast exit: MEMORY.md already has content (most common case)
$content = Get-Content -Path $memoryFile -Raw -ErrorAction SilentlyContinue
if ($content -and $content.Trim().Length -gt 0) {
    exit 0
}

# --- MEMORY.md exists but is empty — needs initialization ---

# Check for archived version first
$archiveFile = Join-Path $claudeBase "archive\$normalizedPath\MEMORY.md"
if (Test-Path $archiveFile) {
    Copy-Item -Path $archiveFile -Destination $memoryFile -Force
    Remove-Item -Path $archiveFile -Force
    # Clean up empty archive directory
    $archiveDir = Split-Path -Parent $archiveFile
    if ((Get-ChildItem -Path $archiveDir -ErrorAction SilentlyContinue).Count -eq 0) {
        Remove-Item -Path $archiveDir -Force
    }
    Write-Output "[claude-memory] MEMORY.md has been restored from archive. Read it before continuing: $memoryFile"
    exit 2
}

# No archive — initialize from template
$date = Get-Date -Format "yyyy-MM-dd"
$template = @"
# Project Memory: $projectDir

## Current State
- Project initialized on $date
- Path: $projectDir
- No active work tracked yet

## Key Decisions
- (none yet)

## Important Paths
- Project root: $projectDir

## Session Log
<!-- Latest sessions appear first. Keep only the last 5. -->
"@

Set-Content -Path $memoryFile -Value $template -Encoding UTF8
Write-Output "[claude-memory] MEMORY.md was empty and has been initialized. Read it before continuing: $memoryFile"
exit 2

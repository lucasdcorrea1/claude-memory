<#
.SYNOPSIS
    Saves a context snapshot for a Claude Code project.
.DESCRIPTION
    Creates a timestamped snapshot of the current MEMORY.md and optional
    extra context, stored in the project's memory/snapshots/ directory.
.PARAMETER Project
    The project name (used to locate the memory directory).
.PARAMETER Message
    Optional message describing what was being done.
.PARAMETER MemoryDir
    Override the memory directory path. Defaults to auto-detection from ~/.claude/projects/.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$Message = "",

    [string]$MemoryDir = ""
)

$ErrorActionPreference = "Stop"

# Resolve memory directory
if (-not $MemoryDir) {
    $claudeProjectsDir = Join-Path $env:USERPROFILE ".claude" "projects"
    if (-not (Test-Path $claudeProjectsDir)) {
        Write-Error "Claude projects directory not found: $claudeProjectsDir"
        exit 1
    }

    # Search for a matching project directory
    $projectDirs = Get-ChildItem -Path $claudeProjectsDir -Directory | Where-Object {
        $_.Name -like "*$Project*"
    }

    if ($projectDirs.Count -eq 0) {
        Write-Error "No project directory found matching '$Project' in $claudeProjectsDir"
        exit 1
    }
    if ($projectDirs.Count -gt 1) {
        Write-Host "Multiple matches found:" -ForegroundColor Yellow
        $projectDirs | ForEach-Object { Write-Host "  - $($_.Name)" }
        Write-Error "Ambiguous project name. Please be more specific."
        exit 1
    }

    $MemoryDir = Join-Path $projectDirs[0].FullName "memory"
}

if (-not (Test-Path $MemoryDir)) {
    Write-Error "Memory directory not found: $MemoryDir"
    exit 1
}

# Create snapshots directory
$snapshotsDir = Join-Path $MemoryDir "snapshots"
if (-not (Test-Path $snapshotsDir)) {
    New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
}

# Generate snapshot filename
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$snapshotFile = Join-Path $snapshotsDir "snapshot_$timestamp.md"

# Read current MEMORY.md
$memoryFile = Join-Path $MemoryDir "MEMORY.md"
$memoryContent = ""
if (Test-Path $memoryFile) {
    $memoryContent = Get-Content -Path $memoryFile -Raw
}

# Build snapshot
$snapshot = @"
# Context Snapshot
- **Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- **Project:** $Project
$(if ($Message) { "- **Message:** $Message" })

## MEMORY.md Content
$memoryContent
"@

# Write snapshot
Set-Content -Path $snapshotFile -Value $snapshot -Encoding UTF8

Write-Host "Context snapshot saved: $snapshotFile" -ForegroundColor Green
Write-Host "  Project: $Project" -ForegroundColor Cyan
Write-Host "  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
if ($Message) {
    Write-Host "  Message: $Message" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Loads the latest context snapshot for a Claude Code project.
.DESCRIPTION
    Reads and displays the most recent context snapshot, optionally
    restoring it as the current MEMORY.md.
.PARAMETER Project
    The project name (used to locate the memory directory).
.PARAMETER Restore
    If set, overwrites MEMORY.md with the snapshot's memory content.
.PARAMETER Index
    Load a specific snapshot by index (0 = latest). Use list-contexts.ps1 to see indices.
.PARAMETER MemoryDir
    Override the memory directory path.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [switch]$Restore,

    [int]$Index = 0,

    [string]$MemoryDir = ""
)

$ErrorActionPreference = "Stop"

# Resolve memory directory
if (-not $MemoryDir) {
    $claudeProjectsDir = Join-Path $env:USERPROFILE ".claude" "projects"
    $projectDirs = Get-ChildItem -Path $claudeProjectsDir -Directory | Where-Object {
        $_.Name -like "*$Project*"
    }

    if ($projectDirs.Count -eq 0) {
        Write-Error "No project directory found matching '$Project'"
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

$snapshotsDir = Join-Path $MemoryDir "snapshots"
if (-not (Test-Path $snapshotsDir)) {
    Write-Host "No snapshots found for project '$Project'." -ForegroundColor Yellow
    exit 0
}

# Get snapshots sorted by name (newest first since they're timestamped)
$snapshots = Get-ChildItem -Path $snapshotsDir -Filter "snapshot_*.md" | Sort-Object Name -Descending

if ($snapshots.Count -eq 0) {
    Write-Host "No snapshots found for project '$Project'." -ForegroundColor Yellow
    exit 0
}

if ($Index -ge $snapshots.Count) {
    Write-Error "Index $Index out of range. Only $($snapshots.Count) snapshot(s) available."
    exit 1
}

$selected = $snapshots[$Index]
$content = Get-Content -Path $selected.FullName -Raw

Write-Host "=== Snapshot: $($selected.Name) ===" -ForegroundColor Green
Write-Host ""
Write-Host $content

if ($Restore) {
    # Extract MEMORY.md content from snapshot
    $memoryFile = Join-Path $MemoryDir "MEMORY.md"

    # Find the "## MEMORY.md Content" section and extract everything after it
    $marker = "## MEMORY.md Content"
    $markerIndex = $content.IndexOf($marker)

    if ($markerIndex -ge 0) {
        $memoryContent = $content.Substring($markerIndex + $marker.Length).TrimStart()
        Set-Content -Path $memoryFile -Value $memoryContent -Encoding UTF8
        Write-Host ""
        Write-Host "MEMORY.md restored from snapshot." -ForegroundColor Green
    }
    else {
        Write-Warning "Could not find MEMORY.md content section in snapshot."
    }
}

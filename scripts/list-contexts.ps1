<#
.SYNOPSIS
    Lists all context snapshots for a Claude Code project.
.PARAMETER Project
    The project name (used to locate the memory directory).
.PARAMETER MemoryDir
    Override the memory directory path.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

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
    Write-Host "No snapshots directory found for project '$Project'." -ForegroundColor Yellow
    exit 0
}

$snapshots = Get-ChildItem -Path $snapshotsDir -Filter "snapshot_*.md" | Sort-Object Name -Descending

if ($snapshots.Count -eq 0) {
    Write-Host "No snapshots found for project '$Project'." -ForegroundColor Yellow
    exit 0
}

Write-Host "Context snapshots for '$Project':" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host ""

$index = 0
foreach ($snap in $snapshots) {
    # Parse timestamp from filename: snapshot_yyyy-MM-dd_HH-mm-ss.md
    $name = $snap.BaseName -replace "^snapshot_", ""
    $dateStr = $name -replace "_", " " -replace "(\d{2})-(\d{2})-(\d{2})$", '$1:$2:$3'

    # Read first few lines to get the message if any
    $lines = Get-Content -Path $snap.FullName -TotalCount 6
    $message = ($lines | Where-Object { $_ -match "^\- \*\*Message:\*\*" }) -replace "^- \*\*Message:\*\* ", ""

    $label = if ($index -eq 0) { " (latest)" } else { "" }
    Write-Host "  [$index] $dateStr$label" -ForegroundColor Cyan
    if ($message) {
        Write-Host "      $message" -ForegroundColor Gray
    }
    Write-Host "      File: $($snap.Name)" -ForegroundColor DarkGray

    $index++
}

Write-Host ""
Write-Host "Total: $($snapshots.Count) snapshot(s)" -ForegroundColor Gray
Write-Host "Use 'load-context.ps1 -Project $Project -Index <n>' to view a specific snapshot." -ForegroundColor Gray

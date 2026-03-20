<#
.SYNOPSIS
    Removes old context snapshots, keeping only the most recent ones.
.PARAMETER Project
    The project name (used to locate the memory directory).
.PARAMETER Keep
    Number of most recent snapshots to keep. Defaults to 10.
.PARAMETER MemoryDir
    Override the memory directory path.
.PARAMETER DryRun
    If set, shows what would be deleted without actually deleting.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [int]$Keep = 10,

    [string]$MemoryDir = "",

    [switch]$DryRun
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

if ($snapshots.Count -le $Keep) {
    Write-Host "Only $($snapshots.Count) snapshot(s) found. Nothing to clean up (keeping $Keep)." -ForegroundColor Green
    exit 0
}

$toDelete = $snapshots | Select-Object -Skip $Keep
$toKeep = $snapshots | Select-Object -First $Keep

Write-Host "Cleanup for project '$Project':" -ForegroundColor Green
Write-Host "  Total snapshots: $($snapshots.Count)" -ForegroundColor Cyan
Write-Host "  Keeping: $Keep (newest)" -ForegroundColor Cyan
Write-Host "  Removing: $($toDelete.Count)" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would delete:" -ForegroundColor Yellow
    foreach ($file in $toDelete) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "[DRY RUN] Would keep:" -ForegroundColor Green
    foreach ($file in $toKeep) {
        Write-Host "  - $($file.Name)" -ForegroundColor Gray
    }
}
else {
    foreach ($file in $toDelete) {
        Remove-Item -Path $file.FullName -Force
        Write-Host "  Deleted: $($file.Name)" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "$($toDelete.Count) snapshot(s) removed. $Keep snapshot(s) retained." -ForegroundColor Green
}

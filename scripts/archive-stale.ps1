<#
.SYNOPSIS
    Archives stale MEMORY.md files that haven't been modified in a configurable number of days.
.DESCRIPTION
    Scans all projects in ~/.claude/projects/*/memory/MEMORY.md, checks modification date,
    and moves stale files to ~/.claude/archive/<project>/ so they are no longer loaded
    into the Claude Code system prompt. Archived files can be restored manually or
    automatically by Claude when the project is reopened.
.PARAMETER Days
    Number of days of inactivity before a MEMORY.md is considered stale. Defaults to 7.
.PARAMETER DryRun
    If set, shows what would be archived without actually moving anything.
.PARAMETER Restore
    If set, restores an archived MEMORY.md back to its active location.
.PARAMETER Project
    When used with -Restore, specifies which project to restore (partial match).
.PARAMETER List
    If set, lists all currently archived projects.
#>
param(
    [int]$Days = 7,

    [switch]$DryRun,

    [switch]$Restore,

    [switch]$List,

    [string]$Project = ""
)

$ErrorActionPreference = "Stop"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$projectsDir = Join-Path $claudeDir "projects"
$archiveDir = Join-Path $claudeDir "archive"

# --- List archived projects ---
if ($List) {
    if (-not (Test-Path $archiveDir)) {
        Write-Host "No archive directory found. Nothing has been archived yet." -ForegroundColor Yellow
        exit 0
    }

    $archived = Get-ChildItem -Path $archiveDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "MEMORY.md")
    }

    if ($archived.Count -eq 0) {
        Write-Host "No archived MEMORY.md files found." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Archived projects ($($archived.Count)):" -ForegroundColor Cyan
    foreach ($dir in $archived) {
        $memFile = Get-Item (Join-Path $dir.FullName "MEMORY.md")
        $age = (Get-Date) - $memFile.LastWriteTime
        Write-Host "  $($dir.Name)" -ForegroundColor White -NoNewline
        Write-Host "  (archived $([math]::Floor($age.TotalDays)) days ago)" -ForegroundColor DarkGray
    }
    exit 0
}

# --- Restore an archived project ---
if ($Restore) {
    if (-not $Project) {
        Write-Error "You must specify -Project when using -Restore."
        exit 1
    }

    if (-not (Test-Path $archiveDir)) {
        Write-Error "No archive directory found."
        exit 1
    }

    $matches = Get-ChildItem -Path $archiveDir -Directory | Where-Object {
        $_.Name -like "*$Project*" -and (Test-Path (Join-Path $_.FullName "MEMORY.md"))
    }

    if ($matches.Count -eq 0) {
        Write-Error "No archived project found matching '$Project'."
        exit 1
    }
    if ($matches.Count -gt 1) {
        Write-Host "Multiple matches found:" -ForegroundColor Yellow
        $matches | ForEach-Object { Write-Host "  - $($_.Name)" }
        Write-Error "Ambiguous project name. Please be more specific."
        exit 1
    }

    $archiveProject = $matches[0]
    $archiveMemory = Join-Path $archiveProject.FullName "MEMORY.md"
    $activeDir = Join-Path $projectsDir $archiveProject.Name "memory"
    $activeMemory = Join-Path $activeDir "MEMORY.md"

    if (Test-Path $activeMemory) {
        Write-Error "Active MEMORY.md already exists at '$activeMemory'. Will not overwrite."
        exit 1
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Would restore:" -ForegroundColor Yellow
        Write-Host "  From: $archiveMemory" -ForegroundColor Gray
        Write-Host "  To:   $activeMemory" -ForegroundColor Gray
        exit 0
    }

    if (-not (Test-Path $activeDir)) {
        New-Item -ItemType Directory -Path $activeDir -Force | Out-Null
    }

    Copy-Item -Path $archiveMemory -Destination $activeMemory
    Remove-Item -Path $archiveMemory -Force

    # Clean up empty archive directory
    $remaining = Get-ChildItem -Path $archiveProject.FullName
    if ($remaining.Count -eq 0) {
        Remove-Item -Path $archiveProject.FullName -Force
    }

    Write-Host "Restored MEMORY.md for '$($archiveProject.Name)'." -ForegroundColor Green
    Write-Host "  Active: $activeMemory" -ForegroundColor Cyan
    exit 0
}

# --- Archive stale MEMORY.md files ---
if (-not (Test-Path $projectsDir)) {
    Write-Error "Projects directory not found: $projectsDir"
    exit 1
}

$cutoffDate = (Get-Date).AddDays(-$Days)
$memoryFiles = Get-ChildItem -Path $projectsDir -Recurse -Filter "MEMORY.md" | Where-Object {
    $_.Directory.Name -eq "memory"
}

if ($memoryFiles.Count -eq 0) {
    Write-Host "No MEMORY.md files found." -ForegroundColor Yellow
    exit 0
}

$stale = @()
$active = @()

foreach ($file in $memoryFiles) {
    if ($file.LastWriteTime -lt $cutoffDate) {
        $stale += $file
    } else {
        $active += $file
    }
}

Write-Host "MEMORY.md Archival Report (stale > $Days days):" -ForegroundColor Green
Write-Host "  Total found:  $($memoryFiles.Count)" -ForegroundColor Cyan
Write-Host "  Active:       $($active.Count)" -ForegroundColor Cyan
Write-Host "  Stale:        $($stale.Count)" -ForegroundColor Cyan
Write-Host ""

if ($stale.Count -eq 0) {
    Write-Host "Nothing to archive." -ForegroundColor Green
    exit 0
}

foreach ($file in $stale) {
    # Derive project key from path: projects/<project-key>/memory/MEMORY.md
    $projectKey = $file.Directory.Parent.Name
    $archiveDest = Join-Path $archiveDir $projectKey
    $archiveFile = Join-Path $archiveDest "MEMORY.md"
    $age = [math]::Floor(((Get-Date) - $file.LastWriteTime).TotalDays)

    if ($DryRun) {
        Write-Host "[DRY RUN] Would archive:" -ForegroundColor Yellow
        Write-Host "  Project: $projectKey ($age days old)" -ForegroundColor Gray
        Write-Host "  From:    $($file.FullName)" -ForegroundColor Gray
        Write-Host "  To:      $archiveFile" -ForegroundColor Gray
        Write-Host ""
    } else {
        if (-not (Test-Path $archiveDest)) {
            New-Item -ItemType Directory -Path $archiveDest -Force | Out-Null
        }

        Copy-Item -Path $file.FullName -Destination $archiveFile
        Remove-Item -Path $file.FullName -Force

        # Clean up empty memory directory
        $remaining = Get-ChildItem -Path $file.Directory.FullName
        if ($remaining.Count -eq 0) {
            Remove-Item -Path $file.Directory.FullName -Force
        }

        Write-Host "  Archived: $projectKey ($age days old)" -ForegroundColor DarkGray
    }
}

if (-not $DryRun) {
    Write-Host ""
    Write-Host "$($stale.Count) MEMORY.md file(s) archived." -ForegroundColor Green
    Write-Host "Use -Restore -Project <name> to restore." -ForegroundColor Cyan
}

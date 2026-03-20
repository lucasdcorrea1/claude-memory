<#
.SYNOPSIS
    Installs claude-memory tools for Claude Code context persistence.
.DESCRIPTION
    Copies scripts to ~/.claude/tools/claude-memory/, creates the archive directory,
    and optionally merges context preservation rules into the global CLAUDE.md.
.PARAMETER ArchiveDays
    Default number of days before a MEMORY.md is considered stale. Defaults to 7.
.PARAMETER NoScheduledTask
    If set, skips creation of the Windows Scheduled Task for auto-archival.
.PARAMETER NoClaude
    If set, skips merging rules into the global CLAUDE.md.
.PARAMETER Force
    If set, overwrites an existing installation.
#>
param(
    [int]$ArchiveDays = 7,
    [switch]$NoScheduledTask,
    [switch]$NoClaude,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$toolsDir = Join-Path $claudeDir "tools" "claude-memory"
$archiveDir = Join-Path $claudeDir "archive"
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
$settingsJson = Join-Path $claudeDir "settings.json"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "=== claude-memory installer ===" -ForegroundColor Cyan
Write-Host ""

# --- Check if already installed ---
if ((Test-Path $toolsDir) -and -not $Force) {
    Write-Host "claude-memory is already installed at: $toolsDir" -ForegroundColor Yellow
    Write-Host "Use -Force to overwrite." -ForegroundColor Gray
    exit 0
}

# --- Copy scripts ---
Write-Host "[1/5] Installing scripts..." -ForegroundColor White

if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}

$scriptsSource = Join-Path $scriptDir "scripts"
if (-not (Test-Path $scriptsSource)) {
    Write-Error "Scripts directory not found: $scriptsSource"
    exit 1
}

Copy-Item -Path "$scriptsSource\*" -Destination $toolsDir -Force -Recurse
Write-Host "  Scripts installed to: $toolsDir" -ForegroundColor Green

# --- Create archive directory ---
Write-Host "[2/5] Setting up archive directory..." -ForegroundColor White

if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    Write-Host "  Created: $archiveDir" -ForegroundColor Green
} else {
    Write-Host "  Already exists: $archiveDir" -ForegroundColor Gray
}

# --- Merge CLAUDE.md ---
if (-not $NoClaude) {
    Write-Host "[3/5] Configuring CLAUDE.md..." -ForegroundColor White

    $templateFile = Join-Path $scriptDir "templates" "CLAUDE-global.md"
    if (-not (Test-Path $templateFile)) {
        Write-Host "  Template not found, skipping CLAUDE.md merge." -ForegroundColor Yellow
    } else {
        $templateContent = Get-Content -Path $templateFile -Raw

        if (Test-Path $claudeMd) {
            $existingContent = Get-Content -Path $claudeMd -Raw

            if ($existingContent -match "## Context Preservation") {
                Write-Host "  CLAUDE.md already contains Context Preservation rules. Skipping." -ForegroundColor Gray
                Write-Host "  (To update manually, see: templates/CLAUDE-global.md)" -ForegroundColor DarkGray
            } else {
                # Append the context preservation section
                $newContent = $existingContent.TrimEnd() + "`n`n" + $templateContent
                Set-Content -Path $claudeMd -Value $newContent -Encoding UTF8
                Write-Host "  Added Context Preservation rules to CLAUDE.md" -ForegroundColor Green
            }
        } else {
            # Create new CLAUDE.md with template
            $header = "# Global Instructions`n`n"
            Set-Content -Path $claudeMd -Value ($header + $templateContent) -Encoding UTF8
            Write-Host "  Created CLAUDE.md with Context Preservation rules" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[3/5] Skipping CLAUDE.md configuration (--NoClaude)" -ForegroundColor Gray
}

# --- Configure hooks in settings.json ---
Write-Host "[4/5] Configuring Claude Code hooks..." -ForegroundColor White

$initHookScript = Join-Path $toolsDir "init-memory-hook.ps1"
$saveHookScript = Join-Path $toolsDir "auto-save-hook.ps1"

$initHookCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$initHookScript`""
$saveHookCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$saveHookScript`""

if (Test-Path $settingsJson) {
    $settings = Get-Content -Path $settingsJson -Raw | ConvertFrom-Json
} else {
    $settings = [PSCustomObject]@{}
}

# Ensure hooks object exists
if (-not $settings.PSObject.Properties["hooks"]) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{})
}

# Configure PreToolUse hook (auto-init MEMORY.md)
$preToolUseHook = [PSCustomObject]@{
    matcher = ""
    hooks = @(
        [PSCustomObject]@{
            type = "command"
            command = $initHookCmd
            timeout = 5
        }
    )
}

$needsPreToolUse = $true
if ($settings.hooks.PSObject.Properties["PreToolUse"]) {
    # Check if our hook is already registered
    foreach ($entry in $settings.hooks.PreToolUse) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*init-memory-hook*") {
                $needsPreToolUse = $false
                break
            }
        }
    }
}

if ($needsPreToolUse) {
    if (-not $settings.hooks.PSObject.Properties["PreToolUse"]) {
        $settings.hooks | Add-Member -NotePropertyName "PreToolUse" -NotePropertyValue @($preToolUseHook)
    } else {
        $settings.hooks.PreToolUse = @($settings.hooks.PreToolUse) + @($preToolUseHook)
    }
    Write-Host "  Added PreToolUse hook (auto-init MEMORY.md)" -ForegroundColor Green
} else {
    Write-Host "  PreToolUse hook already registered. Skipping." -ForegroundColor Gray
}

# Configure Stop hook (auto-save snapshot)
$stopHook = [PSCustomObject]@{
    matcher = ""
    hooks = @(
        [PSCustomObject]@{
            type = "command"
            command = $saveHookCmd
            timeout = 10
        }
    )
}

$needsStop = $true
if ($settings.hooks.PSObject.Properties["Stop"]) {
    foreach ($entry in $settings.hooks.Stop) {
        foreach ($h in $entry.hooks) {
            if ($h.command -like "*auto-save-hook*") {
                $needsStop = $false
                break
            }
        }
    }
}

if ($needsStop) {
    if (-not $settings.hooks.PSObject.Properties["Stop"]) {
        $settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue @($stopHook)
    } else {
        $settings.hooks.Stop = @($settings.hooks.Stop) + @($stopHook)
    }
    Write-Host "  Added Stop hook (auto-save snapshot)" -ForegroundColor Green
} else {
    Write-Host "  Stop hook already registered. Skipping." -ForegroundColor Gray
}

$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsJson -Encoding UTF8
Write-Host "  Settings saved to: $settingsJson" -ForegroundColor Cyan

# --- Scheduled Task ---
if (-not $NoScheduledTask) {
    Write-Host "[5/5] Setting up scheduled task..." -ForegroundColor White

    $taskName = "Claude-ArchiveStaleMemory"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existingTask -and -not $Force) {
        Write-Host "  Scheduled task '$taskName' already exists. Skipping." -ForegroundColor Gray
    } else {
        try {
            $archiveScript = Join-Path $toolsDir "archive-stale.ps1"
            $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -NonInteractive -File `"$archiveScript`" -Days $ArchiveDays"
            $trigger = New-ScheduledTaskTrigger -Daily -At "00:00"
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

            if ($existingTask) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            }

            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Archives stale Claude Code MEMORY.md files older than $ArchiveDays days" | Out-Null
            Write-Host "  Scheduled task created: runs daily at midnight" -ForegroundColor Green
            Write-Host "  Archives MEMORY.md files inactive for $ArchiveDays+ days" -ForegroundColor Cyan
        } catch {
            Write-Host "  Could not create scheduled task (may need admin privileges)." -ForegroundColor Yellow
            Write-Host "  You can run archive-stale.ps1 manually instead." -ForegroundColor Gray
        }
    }
} else {
    Write-Host "[5/5] Skipping scheduled task (--NoScheduledTask)" -ForegroundColor Gray
}

# --- Done ---
Write-Host ""
Write-Host "=== Installation complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Installed to:  $toolsDir" -ForegroundColor Cyan
Write-Host "Archive dir:   $archiveDir" -ForegroundColor Cyan
Write-Host "CLAUDE.md:     $claudeMd" -ForegroundColor Cyan
Write-Host ""
Write-Host "How it works:" -ForegroundColor White
Write-Host "  - Claude Code auto-creates MEMORY.md on first session in any project" -ForegroundColor Gray
Write-Host "  - Stale files are archived after $ArchiveDays days of inactivity" -ForegroundColor Gray
Write-Host "  - Reopening a project auto-restores its archived memory" -ForegroundColor Gray
Write-Host ""
Write-Host "Manual commands:" -ForegroundColor White
Write-Host "  pwsh -File `"$toolsDir\archive-stale.ps1`" -DryRun     # Preview archival" -ForegroundColor Gray
Write-Host "  pwsh -File `"$toolsDir\archive-stale.ps1`" -List        # List archived" -ForegroundColor Gray
Write-Host "  pwsh -File `"$toolsDir\archive-stale.ps1`" -Restore -Project <name>" -ForegroundColor Gray

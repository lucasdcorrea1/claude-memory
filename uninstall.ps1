<#
.SYNOPSIS
    Uninstalls claude-memory tools.
.DESCRIPTION
    Removes installed scripts and the scheduled task.
    Does NOT remove CLAUDE.md rules or user data (MEMORY.md files, archive).
#>

$ErrorActionPreference = "Stop"

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$toolsDir = Join-Path $claudeDir "tools" "claude-memory"

Write-Host ""
Write-Host "=== claude-memory uninstaller ===" -ForegroundColor Cyan
Write-Host ""

# --- Remove scripts ---
if (Test-Path $toolsDir) {
    Remove-Item -Path $toolsDir -Recurse -Force
    Write-Host "  Removed scripts: $toolsDir" -ForegroundColor Green
} else {
    Write-Host "  Scripts not found (already removed?)" -ForegroundColor Gray
}

# --- Remove hooks from settings.json ---
$settingsJson = Join-Path $claudeDir "settings.json"
if (Test-Path $settingsJson) {
    try {
        $settings = Get-Content -Path $settingsJson -Raw | ConvertFrom-Json
        $changed = $false

        if ($settings.PSObject.Properties["hooks"]) {
            # Remove PreToolUse hooks referencing claude-memory
            if ($settings.hooks.PSObject.Properties["PreToolUse"]) {
                $filtered = @($settings.hooks.PreToolUse | Where-Object {
                    $keep = $true
                    foreach ($h in $_.hooks) {
                        if ($h.command -like "*claude-memory*" -or $h.command -like "*init-memory-hook*") {
                            $keep = $false
                        }
                    }
                    $keep
                })
                if ($filtered.Count -eq 0) {
                    $settings.hooks.PSObject.Properties.Remove("PreToolUse")
                } else {
                    $settings.hooks.PreToolUse = $filtered
                }
                $changed = $true
            }

            # Remove Stop hooks referencing claude-memory
            if ($settings.hooks.PSObject.Properties["Stop"]) {
                $filtered = @($settings.hooks.Stop | Where-Object {
                    $keep = $true
                    foreach ($h in $_.hooks) {
                        if ($h.command -like "*claude-memory*" -or $h.command -like "*auto-save-hook*") {
                            $keep = $false
                        }
                    }
                    $keep
                })
                if ($filtered.Count -eq 0) {
                    $settings.hooks.PSObject.Properties.Remove("Stop")
                } else {
                    $settings.hooks.Stop = $filtered
                }
                $changed = $true
            }

            # Remove empty hooks object
            $remainingHooks = @($settings.hooks.PSObject.Properties).Count
            if ($remainingHooks -eq 0) {
                $settings.PSObject.Properties.Remove("hooks")
            }
        }

        if ($changed) {
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsJson -Encoding UTF8
            Write-Host "  Removed hooks from settings.json" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Could not clean hooks from settings.json: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No settings.json found" -ForegroundColor Gray
}

# --- Remove scheduled task ---
$taskName = "Claude-ArchiveStaleMemory"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "  Removed scheduled task: $taskName" -ForegroundColor Green
    } catch {
        Write-Host "  Could not remove scheduled task (may need admin privileges)." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Scheduled task not found (already removed?)" -ForegroundColor Gray
}

# --- Clean up empty tools dir ---
$toolsParent = Join-Path $claudeDir "tools"
if ((Test-Path $toolsParent) -and (Get-ChildItem $toolsParent).Count -eq 0) {
    Remove-Item -Path $toolsParent -Force
}

# --- Done ---
Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Preserved (not removed):" -ForegroundColor Yellow
Write-Host "  - ~/.claude/CLAUDE.md (may contain your custom rules)" -ForegroundColor Gray
Write-Host "  - ~/.claude/projects/ (your active MEMORY.md files)" -ForegroundColor Gray
Write-Host "  - ~/.claude/archive/ (your archived MEMORY.md files)" -ForegroundColor Gray
Write-Host ""
Write-Host "To fully clean up, manually remove those directories." -ForegroundColor Gray

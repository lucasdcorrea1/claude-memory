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

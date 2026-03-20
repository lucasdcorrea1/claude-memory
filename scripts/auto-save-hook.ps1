<#
.SYNOPSIS
    Hook script called automatically by Claude Code on Stop event.
    Reads session data from stdin and saves a context snapshot.
#>
$ErrorActionPreference = "SilentlyContinue"

# Read hook input from stdin
$inputJson = $null
try {
    $inputJson = [Console]::In.ReadToEnd() | ConvertFrom-Json
} catch {}

# Determine the project directory
$projectDir = if ($inputJson -and $inputJson.cwd) {
    $inputJson.cwd
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $env:CLAUDE_PROJECT_DIR
} else {
    Get-Location | Select-Object -ExpandProperty Path
}

# Normalize path to get Claude's project folder name
$normalizedPath = $projectDir -replace "[:\\\/]", "-"

$claudeProjectsDir = Join-Path $env:USERPROFILE ".claude" "projects"
$memoryDir = $null

# Try exact match first
$exactDir = Join-Path $claudeProjectsDir $normalizedPath "memory"
if (Test-Path $exactDir) {
    $memoryDir = $exactDir
}

# Fallback: find a matching directory
if (-not $memoryDir) {
    $candidates = Get-ChildItem -Path $claudeProjectsDir -Directory -ErrorAction SilentlyContinue | Where-Object {
        Test-Path (Join-Path $_.FullName "memory" "MEMORY.md")
    } | Where-Object {
        # Check if the project dir name is a prefix match
        $dirPath = $_.Name -replace "-", "\" -replace "^([A-Z])\\", '$1:\'
        $projectDir.StartsWith($dirPath) -or $_.Name -eq $normalizedPath
    }
    if ($candidates) {
        $memoryDir = Join-Path $candidates[0].FullName "memory"
    }
}

# No memory dir found — nothing to snapshot
if (-not $memoryDir -or -not (Test-Path $memoryDir)) {
    exit 0
}

# Check if MEMORY.md exists
$memoryFile = Join-Path $memoryDir "MEMORY.md"
if (-not (Test-Path $memoryFile)) {
    exit 0
}

# Create snapshots dir
$snapshotsDir = Join-Path $memoryDir "snapshots"
if (-not (Test-Path $snapshotsDir)) {
    New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
}

# Only save if MEMORY.md changed since last snapshot
$lastSnapshot = Get-ChildItem -Path $snapshotsDir -Filter "snapshot_*.md" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1

$memoryContent = Get-Content -Path $memoryFile -Raw

if ($lastSnapshot) {
    $lastContent = Get-Content -Path $lastSnapshot.FullName -Raw
    # Extract the MEMORY.md section from the last snapshot
    $marker = "## MEMORY.md Content"
    $markerIdx = $lastContent.IndexOf($marker)
    if ($markerIdx -ge 0) {
        $lastMemory = $lastContent.Substring($markerIdx + $marker.Length).TrimStart()
        # If content is the same, skip
        if ($lastMemory.Trim() -eq $memoryContent.Trim()) {
            exit 0
        }
    }
}

# Save snapshot
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$snapshotFile = Join-Path $snapshotsDir "snapshot_$timestamp.md"

$snapshot = @"
# Context Snapshot (Auto)
- **Date:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- **Project Dir:** $projectDir

## MEMORY.md Content
$memoryContent
"@

Set-Content -Path $snapshotFile -Value $snapshot -Encoding UTF8

# Auto-cleanup: keep only last 20 snapshots
$allSnapshots = Get-ChildItem -Path $snapshotsDir -Filter "snapshot_*.md" | Sort-Object Name -Descending
$toDelete = $allSnapshots | Select-Object -Skip 20
foreach ($old in $toDelete) {
    Remove-Item -Path $old.FullName -Force
}

exit 0

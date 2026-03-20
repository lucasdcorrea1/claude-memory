<#
.SYNOPSIS
    Initializes context tracking for a Claude Code project.
.DESCRIPTION
    Sets up the MEMORY.md file with a structured format and optionally
    creates a project-level CLAUDE.md from the template.
.PARAMETER Project
    A friendly name for the project (used in snapshot operations).
.PARAMETER Path
    The filesystem path to the project root.
.PARAMETER WithClaudeMd
    If set, also creates a CLAUDE.md in the project root from the template.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [switch]$WithClaudeMd
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templatesDir = Join-Path (Split-Path -Parent $scriptDir) "templates"

# Resolve the Claude projects directory for this path
# Claude uses the path with separators replaced by dashes
$claudeProjectsDir = Join-Path $env:USERPROFILE ".claude" "projects"

if (-not (Test-Path $claudeProjectsDir)) {
    New-Item -ItemType Directory -Path $claudeProjectsDir -Force | Out-Null
}

# Find or create the project's memory directory
# Claude Code names directories based on the path: D--Development becomes the folder name
$normalizedPath = $Path.TrimEnd('\', '/')
$projectDirName = $normalizedPath -replace "[:\\\/]", "-"

$projectDir = Join-Path $claudeProjectsDir $projectDirName
$memoryDir = Join-Path $projectDir "memory"

if (-not (Test-Path $memoryDir)) {
    New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
    Write-Host "Created memory directory: $memoryDir" -ForegroundColor Green
}

# Create MEMORY.md from template
$memoryFile = Join-Path $memoryDir "MEMORY.md"
$memoryTemplate = Join-Path $templatesDir "memory-template.md"

if (Test-Path $memoryFile) {
    Write-Host "MEMORY.md already exists at: $memoryFile" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "Skipping MEMORY.md creation." -ForegroundColor Gray
    }
    else {
        $templateContent = Get-Content -Path $memoryTemplate -Raw
        $templateContent = $templateContent -replace "\{\{PROJECT_NAME\}\}", $Project
        $templateContent = $templateContent -replace "\{\{PROJECT_PATH\}\}", $Path
        $templateContent = $templateContent -replace "\{\{DATE\}\}", (Get-Date -Format "yyyy-MM-dd")
        Set-Content -Path $memoryFile -Value $templateContent -Encoding UTF8
        Write-Host "MEMORY.md overwritten." -ForegroundColor Green
    }
}
else {
    $templateContent = Get-Content -Path $memoryTemplate -Raw
    $templateContent = $templateContent -replace "\{\{PROJECT_NAME\}\}", $Project
    $templateContent = $templateContent -replace "\{\{PROJECT_PATH\}\}", $Path
    $templateContent = $templateContent -replace "\{\{DATE\}\}", (Get-Date -Format "yyyy-MM-dd")
    Set-Content -Path $memoryFile -Value $templateContent -Encoding UTF8
    Write-Host "MEMORY.md created: $memoryFile" -ForegroundColor Green
}

# Create snapshots directory
$snapshotsDir = Join-Path $memoryDir "snapshots"
if (-not (Test-Path $snapshotsDir)) {
    New-Item -ItemType Directory -Path $snapshotsDir -Force | Out-Null
    Write-Host "Created snapshots directory: $snapshotsDir" -ForegroundColor Green
}

# Optionally create project CLAUDE.md
if ($WithClaudeMd) {
    $projectClaudeMd = Join-Path $Path "CLAUDE.md"
    $claudeMdTemplate = Join-Path $templatesDir "claude-md-base.md"

    if (Test-Path $projectClaudeMd) {
        Write-Host "CLAUDE.md already exists at project root. Skipping." -ForegroundColor Yellow
    }
    else {
        $templateContent = Get-Content -Path $claudeMdTemplate -Raw
        $templateContent = $templateContent -replace "\{\{PROJECT_NAME\}\}", $Project
        Set-Content -Path $projectClaudeMd -Value $templateContent -Encoding UTF8
        Write-Host "CLAUDE.md created at project root: $projectClaudeMd" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Context tracking initialized for '$Project'!" -ForegroundColor Green
Write-Host "  Memory dir: $memoryDir" -ForegroundColor Cyan
Write-Host "  Project path: $Path" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Gray
Write-Host "  - Use 'save-context.ps1 -Project $Project' to save snapshots" -ForegroundColor Gray
Write-Host "  - Use 'load-context.ps1 -Project $Project' to restore context" -ForegroundColor Gray

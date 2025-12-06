# Jujutsu format and commit script (PowerShell version)

param(
    [string]$m,
    [switch]$help
)

# Show help
if ($help) {
    Write-Host ""
    Write-Host "Jujutsu Format and Commit Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\jjc.ps1 -m `"message`"    (single-line commit)"
    Write-Host "  .\jjc.ps1                   (open editor)"
    Write-Host "  .\jjc.ps1 -help"
    Write-Host ""
    Write-Host "Steps:" -ForegroundColor Yellow
    Write-Host "  1. Formats changed files by language"
    Write-Host "  2. Commits if formatting succeeds"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\jjc.ps1 -m `":sparkles: feat: add feature`""
    Write-Host "  .\jjc.ps1 -m `":bug: fix: fix bug`""
    Write-Host "  .\jjc.ps1"
    Write-Host ""
    exit 0
}

# Check if jj-fmt.ps1 exists
if (-not (Test-Path "jj-fmt.ps1")) {
    Write-Host "Error: jj-fmt.ps1 not found" -ForegroundColor Red
    Write-Host "Please run from project root" -ForegroundColor Yellow
    exit 1
}

# Check if jj is available
try {
    $null = Get-Command jj -ErrorAction Stop
}
catch {
    Write-Host "Error: Jujutsu (jj) not found in PATH" -ForegroundColor Red
    exit 1
}

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Jujutsu Format and Commit" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Step 1: Format
Write-Host "[1/2] Formatting changed files..." -ForegroundColor Cyan
& .\jj-fmt.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Error: Formatting failed" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    exit 1
}

# Step 2: Commit
Write-Host ""
Write-Host "[2/2] Committing changes..." -ForegroundColor Cyan
Write-Host ""

if ($m) {
    # Single-line commit
    jj commit -m $m
}
else {
    # Open editor
    Write-Host "Opening editor for commit message..." -ForegroundColor Yellow
    Write-Host ""
    jj commit
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Error: Commit failed" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Success: Changes committed" -ForegroundColor Green
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

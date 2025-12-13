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
    Write-Host "  3. Sets bookmark 'main' to parent commit"
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

function Get-PowerShellExecutable {
    try {
        $null = Get-Command pwsh -ErrorAction Stop
        return "pwsh"
    }
    catch {
        return "powershell"
    }
}

Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Jujutsu Format and Commit" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host ""

# Step 1: Format
Write-Host "[1/3] " -ForegroundColor Yellow -NoNewline
Write-Host "Formatting changed files..." -ForegroundColor Cyan

$psExe = Get-PowerShellExecutable
$fmtLogDir = Join-Path $PSScriptRoot ".jj"
if (-not (Test-Path $fmtLogDir)) {
    New-Item -ItemType Directory -Path $fmtLogDir | Out-Null
}

$fmtLog = Join-Path $fmtLogDir ("jj-fmt-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

Write-Host "" 
Write-Host "Formatter log: $fmtLog" -ForegroundColor DarkGray

& $psExe -NoProfile -ExecutionPolicy Bypass -File ".\jj-fmt.ps1" *>> $fmtLog
$fmtExitCode = $LASTEXITCODE

if ($fmtExitCode -ne 0) {
    Write-Host ""
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Error: Formatting failed" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

    Write-Host "" 
    Write-Host "Diagnostics:" -ForegroundColor Yellow
    Write-Host "  - Log file: $fmtLog" -ForegroundColor Yellow
    Write-Host "  - Re-run formatter with verbose output:" -ForegroundColor Yellow
    Write-Host "      .\jj-fmt.ps1 -Verbose" -ForegroundColor Yellow
    Write-Host "" 
    Write-Host "Recent formatter output (from log):" -ForegroundColor Yellow

    try {
        Get-Content -Path $fmtLog -Tail 200 | ForEach-Object { Write-Host $_ }
    }
    catch {
        Write-Host "(Failed to read log file: $fmtLog)" -ForegroundColor Yellow
    }

    Write-Host "" 
    Write-Host "Re-running formatter in verbose mode to show file list and exact errors..." -ForegroundColor Yellow

    $fmtVerboseLog = Join-Path $fmtLogDir ("jj-fmt-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-verbose.log")
    Write-Host "Verbose formatter log: $fmtVerboseLog" -ForegroundColor DarkGray

    & $psExe -NoProfile -ExecutionPolicy Bypass -File ".\jj-fmt.ps1" -Verbose *>> $fmtVerboseLog
    $fmtVerboseExitCode = $LASTEXITCODE

    if ($fmtVerboseExitCode -ne 0) {
        Write-Host "" 
        Write-Host "Recent verbose output (from log):" -ForegroundColor Yellow
        try {
            Get-Content -Path $fmtVerboseLog -Tail 250 | ForEach-Object { Write-Host $_ }
        }
        catch {
            Write-Host "(Failed to read verbose log file: $fmtVerboseLog)" -ForegroundColor Yellow
        }
    }

    exit 1
}

# Step 2: Commit
Write-Host ""
Write-Host "[2/3] " -ForegroundColor Yellow -NoNewline
Write-Host "Committing changes..." -ForegroundColor Cyan
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

# Only set bookmark if commit succeeded
Write-Host "Commit successful!" -ForegroundColor Green
Write-Host ""
Write-Host "[3/3] " -ForegroundColor Yellow -NoNewline
Write-Host "Setting bookmark..." -ForegroundColor Cyan
jj bookmark set main -r "@-"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Failed to set bookmark (you may need to set it manually)" -ForegroundColor Yellow
    Write-Host "You can manually run: jj bookmark set main -r '@-'" -ForegroundColor Yellow
}
else {
    Write-Host "Bookmark 'main' set to parent commit successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Success: Changes committed" -ForegroundColor Green
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

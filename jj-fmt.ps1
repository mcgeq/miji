# Format changed files for Jujutsu
# UTF-8 encoding with BOM

<#
.SYNOPSIS
    Format changed files for Jujutsu commits

.DESCRIPTION
    Detects changed files using jj status and formats them with appropriate tools:
    
    Frontend:
    - JavaScript/TypeScript: Biome
    
    Backend:
    - Rust: cargo fmt / rustfmt
    - Zig: zig fmt
    - Python: ruff / black / autopep8 (auto-detect)
    - C/C++: clang-format

.PARAMETER Verbose
    Show detailed output for each file

.PARAMETER Quiet
    Suppress non-error output

.EXAMPLE
    .\jj-fmt.ps1
    Format all changed files with standard output

.EXAMPLE
    .\jj-fmt.ps1 -Verbose
    Format with detailed output for each file

.EXAMPLE
    .\jj-fmt.ps1 -Quiet
    Silent mode, only show errors

.NOTES
    Supported file extensions:
    - Frontend: .js, .ts, .jsx, .tsx, .vue, .json, .jsonc
    - Rust: .rs
    - Zig: .zig
    - Python: .py
    - C/C++: .c, .cpp, .cc, .cxx, .h, .hpp
#>

param(
    [switch]$Verbose,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$startTime = Get-Date

# Statistics
$stats = @{
    TotalFiles = 0
    FrontendFiles = 0
    BackendFiles = @{
        Rust = 0
        Zig = 0
        Python = 0
        Cpp = 0
        Total = 0
    }
    SkippedFiles = 0
    FormattedFiles = 0
    Errors = @()
}

# Check if jj is available
try {
    $null = Get-Command jj -ErrorAction Stop
}
catch {
    Write-Host "Error: Jujutsu (jj) not found in PATH" -ForegroundColor Red
    Write-Host "Please install Jujutsu: https://github.com/martinvonz/jj" -ForegroundColor Yellow
    exit 1
}

# Check if biome is available
try {
    $null = Get-Command biome -ErrorAction Stop
}
catch {
    Write-Host "Error: Biome not found in PATH" -ForegroundColor Red
    Write-Host "Please install Biome or run: bun install" -ForegroundColor Yellow
    exit 1
}

if (-not $Quiet) {
    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Jujutsu File Formatter" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Checking changed files..." -ForegroundColor Cyan
}

# Get list of changed files using jj status
$changedFiles = jj status 2>$null | Where-Object { 
    $_ -match "^[AM]\s+(.+)$" 
} | ForEach-Object { 
    $matches[1] 
}

if ($LASTEXITCODE -ne 0 -or -not $changedFiles) {
    Write-Host "Warning: Cannot get file list, trying diff..." -ForegroundColor Yellow
    # Fallback: try using diff --summary
    $changedFiles = jj diff --summary 2>$null | Where-Object {
        $_ -match "^\s*[AM]\s+(.+)$"
    } | ForEach-Object {
        $matches[1]
    }
}

if (-not $changedFiles) {
    Write-Host "No changed files" -ForegroundColor Green
    exit 0
}

# Convert to array
$files = @($changedFiles)
$stats.TotalFiles = $files.Count

if (-not $Quiet) {
    Write-Host "Found $($files.Count) changed file(s)" -ForegroundColor Cyan
    if ($Verbose) {
        Write-Host "`nAll changed files:" -ForegroundColor Gray
        $files | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor DarkGray
        }
    }
}

# Filter frontend files (sync with .lintstagedrc.json)
$frontendFiles = $files | Where-Object { 
    $_ -match '\.(js|ts|cjs|mjs|jsx|tsx|vue|json|jsonc)$' -and $_ -notmatch '^src-tauri/'
}
$stats.FrontendFiles = $frontendFiles.Count

# Filter backend files by language
$rustFiles = $files | Where-Object { $_ -match '\.rs$' }
$zigFiles = $files | Where-Object { $_ -match '\.zig$' }
$pythonFiles = $files | Where-Object { $_ -match '\.py$' }
$cppFiles = $files | Where-Object { $_ -match '\.(c|cpp|cc|cxx|h|hpp)$' }

$stats.BackendFiles.Rust = $rustFiles.Count
$stats.BackendFiles.Zig = $zigFiles.Count
$stats.BackendFiles.Python = $pythonFiles.Count
$stats.BackendFiles.Cpp = $cppFiles.Count
$stats.BackendFiles.Total = $rustFiles.Count + $zigFiles.Count + $pythonFiles.Count + $cppFiles.Count

# Calculate skipped files
$formattableFiles = $frontendFiles.Count + $stats.BackendFiles.Total
$stats.SkippedFiles = $stats.TotalFiles - $formattableFiles

if (-not $Quiet) {
    Write-Host "`nFile categorization:" -ForegroundColor Cyan
    Write-Host "  Frontend:       $($stats.FrontendFiles)" -ForegroundColor White
    if ($stats.BackendFiles.Total -gt 0) {
        Write-Host "  Backend:        $($stats.BackendFiles.Total)" -ForegroundColor White
        if ($stats.BackendFiles.Rust -gt 0) {
            Write-Host "    - Rust:       $($stats.BackendFiles.Rust)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Zig -gt 0) {
            Write-Host "    - Zig:        $($stats.BackendFiles.Zig)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Python -gt 0) {
            Write-Host "    - Python:     $($stats.BackendFiles.Python)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Cpp -gt 0) {
            Write-Host "    - C/C++:      $($stats.BackendFiles.Cpp)" -ForegroundColor Gray
        }
    }
    if ($stats.SkippedFiles -gt 0) {
        Write-Host "  Skipped:        $($stats.SkippedFiles)" -ForegroundColor DarkGray
    }
}

$hasError = $false

# Format frontend files
if ($frontendFiles) {
    if (-not $Quiet) {
        Write-Host "`n[1/2] Formatting frontend files..." -ForegroundColor Cyan
        if ($Verbose) {
            $frontendFiles | ForEach-Object {
                Write-Host "  > $_" -ForegroundColor Gray
            }
        }
    }
    
    $frontendStartTime = Get-Date
    
    try {
        # Run biome
        if ($Verbose) {
            & biome check --write --unsafe --no-errors-on-unmatched $frontendFiles
            $biomeExitCode = $LASTEXITCODE
        }
        else {
            & biome check --write --unsafe --no-errors-on-unmatched $frontendFiles 2>&1 | Out-String | Out-Null
            $biomeExitCode = $LASTEXITCODE
        }
        
        $frontendDuration = (Get-Date) - $frontendStartTime
        
        # Check if biome succeeded (exit code 0 or 1 are both OK)
        if ($biomeExitCode -gt 1) {
            $errorMsg = "Biome formatting failed (exit code: $biomeExitCode)"
            $stats.Errors += $errorMsg
            if (-not $Quiet) {
                Write-Host "  [FAIL] Failed" -ForegroundColor Red
            }
            $hasError = $true
        }
        else {
            $stats.FormattedFiles += $frontendFiles.Count
            if (-not $Quiet) {
                Write-Host "  [OK] Completed in $([math]::Round($frontendDuration.TotalSeconds, 2))s" -ForegroundColor Green
            }
        }
    }
    catch {
        $errorMsg = "Frontend formatting error: $_"
        $stats.Errors += $errorMsg
        if (-not $Quiet) {
            Write-Host "  [FAIL] Error: $_" -ForegroundColor Red
        }
        $hasError = $true
    }
}
else {
    if (-not $Quiet -and $Verbose) {
        Write-Host "`n[1/2] No frontend files to format" -ForegroundColor DarkGray
    }
}

# Format backend files
$backendStep = 2
$totalSteps = 2

# Format Rust files
if ($rustFiles) {
    if (-not $Quiet) {
        Write-Host "`n[$backendStep/$totalSteps] Formatting Rust files..." -ForegroundColor Cyan
        if ($Verbose) {
            $rustFiles | ForEach-Object {
                Write-Host "  > $_" -ForegroundColor Gray
            }
        }
    }
    
    $rustStartTime = Get-Date
    
    # Check if rustfmt is available
    try {
        $null = Get-Command rustfmt -ErrorAction Stop
    }
    catch {
        if (-not $Quiet) {
            Write-Host "  Using cargo fmt (rustfmt not in PATH)" -ForegroundColor Yellow
        }
        Push-Location src-tauri
        try {
            if ($Verbose) {
                & cargo fmt
            }
            else {
                & cargo fmt 2>&1 | Out-Null
            }
            
            $rustDuration = (Get-Date) - $rustStartTime
            
            if ($LASTEXITCODE -eq 0) {
                $stats.FormattedFiles += $rustFiles.Count
                if (-not $Quiet) {
                    Write-Host "  [OK] Completed in $([math]::Round($rustDuration.TotalSeconds, 2))s" -ForegroundColor Green
                }
            }
            else {
                $errorMsg = "Cargo fmt failed (exit code: $LASTEXITCODE)"
                $stats.Errors += $errorMsg
                if (-not $Quiet) {
                    Write-Host "  [FAIL] Failed" -ForegroundColor Red
                }
                $hasError = $true
            }
        }
        catch {
            $errorMsg = "Rust formatting error: $_"
            $stats.Errors += $errorMsg
            if (-not $Quiet) {
                Write-Host "  [FAIL] Error: $_" -ForegroundColor Red
            }
            $hasError = $true
        }
        finally {
            Pop-Location
        }
        return
    }
    
    # Use rustfmt for individual files
    Push-Location src-tauri
    try {
        $rustFormatted = 0
        $rustFailed = 0
        
        foreach ($rustFile in $rustFiles) {
            $file = $rustFile -replace '^src-tauri/', ''
            if (Test-Path $file) {
                if ($Verbose) {
                    & rustfmt $file
                }
                else {
                    & rustfmt $file 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $rustFormatted++
                    if ($Verbose) {
                        Write-Host "    [OK] $file" -ForegroundColor Green
                    }
                }
                else {
                    $rustFailed++
                    $errorMsg = "rustfmt failed for: $file"
                    $stats.Errors += $errorMsg
                    if (-not $Quiet) {
                        Write-Host "    [FAIL] $file" -ForegroundColor Red
                    }
                    $hasError = $true
                }
            }
            else {
                if (-not $Quiet) {
                    Write-Host "    [WARN] File not found: $file" -ForegroundColor Yellow
                }
            }
        }
        
        $rustDuration = (Get-Date) - $rustStartTime
        $stats.FormattedFiles += $rustFormatted
        
        if (-not $hasError) {
            if (-not $Quiet) {
                Write-Host "  [OK] Completed in $([math]::Round($rustDuration.TotalSeconds, 2))s" -ForegroundColor Green
                if ($Verbose) {
                    Write-Host "    Formatted: $rustFormatted/$($rustFiles.Count)" -ForegroundColor Gray
                }
            }
        }
        else {
            if (-not $Quiet) {
                Write-Host "  [WARN] Completed with errors ($rustFailed failed)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $errorMsg = "Rust formatting error: $_"
        $stats.Errors += $errorMsg
        if (-not $Quiet) {
            Write-Host "  [FAIL] Error: $_" -ForegroundColor Red
        }
        $hasError = $true
    }
    finally {
        Pop-Location
    }
}
else {
    if (-not $Quiet -and $Verbose) {
        Write-Host "`n[$backendStep/$totalSteps] No Rust files to format" -ForegroundColor DarkGray
    }
}

# Format Zig files
if ($zigFiles) {
    if (-not $Quiet) {
        Write-Host "`n[Backend] Formatting Zig files..." -ForegroundColor Cyan
        if ($Verbose) {
            $zigFiles | ForEach-Object {
                Write-Host "  > $_" -ForegroundColor Gray
            }
        }
    }
    
    $zigStartTime = Get-Date
    
    # Check if zig is available
    try {
        $null = Get-Command zig -ErrorAction Stop
        
        $zigFormatted = 0
        $zigFailed = 0
        
        foreach ($file in $zigFiles) {
            if (Test-Path $file) {
                if ($Verbose) {
                    & zig fmt $file
                }
                else {
                    & zig fmt $file 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $zigFormatted++
                    if ($Verbose) {
                        Write-Host "    [OK] $file" -ForegroundColor Green
                    }
                }
                else {
                    $zigFailed++
                    $stats.Errors += "zig fmt failed for: $file"
                    if (-not $Quiet) {
                        Write-Host "    [FAIL] $file" -ForegroundColor Red
                    }
                    $hasError = $true
                }
            }
        }
        
        $zigDuration = (Get-Date) - $zigStartTime
        $stats.FormattedFiles += $zigFormatted
        
        if (-not $hasError) {
            if (-not $Quiet) {
                Write-Host "  [OK] Completed in $([math]::Round($zigDuration.TotalSeconds, 2))s" -ForegroundColor Green
            }
        }
    }
    catch {
        if (-not $Quiet) {
            Write-Host "  [WARN] zig not found, skipping Zig files" -ForegroundColor Yellow
        }
    }
}

# Format Python files
if ($pythonFiles) {
    if (-not $Quiet) {
        Write-Host "`n[Backend] Formatting Python files..." -ForegroundColor Cyan
        if ($Verbose) {
            $pythonFiles | ForEach-Object {
                Write-Host "  > $_" -ForegroundColor Gray
            }
        }
    }
    
    $pythonStartTime = Get-Date
    
    # Try formatters in order: ruff, black, autopep8
    $formatter = $null
    $formatterCmd = @()
    
    try {
        $null = Get-Command ruff -ErrorAction Stop
        $formatter = "ruff"
        $formatterCmd = @("format")
    }
    catch {
        try {
            $null = Get-Command black -ErrorAction Stop
            $formatter = "black"
            $formatterCmd = @()
        }
        catch {
            try {
                $null = Get-Command autopep8 -ErrorAction Stop
                $formatter = "autopep8"
                $formatterCmd = @("--in-place")
            }
            catch {
                if (-not $Quiet) {
                    Write-Host "  [WARN] No Python formatter found (ruff/black/autopep8), skipping" -ForegroundColor Yellow
                }
            }
        }
    }
    
    if ($formatter) {
        $pythonFormatted = 0
        $pythonFailed = 0
        
        foreach ($file in $pythonFiles) {
            if (Test-Path $file) {
                $cmd = @($formatter) + $formatterCmd + @($file)
                
                if ($Verbose) {
                    & $cmd[0] $cmd[1..($cmd.Length-1)]
                }
                else {
                    & $cmd[0] $cmd[1..($cmd.Length-1)] 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $pythonFormatted++
                    if ($Verbose) {
                        Write-Host "    [OK] $file" -ForegroundColor Green
                    }
                }
                else {
                    $pythonFailed++
                    $stats.Errors += "$formatter failed for: $file"
                    if (-not $Quiet) {
                        Write-Host "    [FAIL] $file" -ForegroundColor Red
                    }
                    $hasError = $true
                }
            }
        }
        
        $pythonDuration = (Get-Date) - $pythonStartTime
        $stats.FormattedFiles += $pythonFormatted
        
        if (-not $hasError) {
            if (-not $Quiet) {
                Write-Host "  [OK] Completed in $([math]::Round($pythonDuration.TotalSeconds, 2))s ($formatter)" -ForegroundColor Green
            }
        }
    }
}

# Format C/C++ files
if ($cppFiles) {
    if (-not $Quiet) {
        Write-Host "`n[Backend] Formatting C/C++ files..." -ForegroundColor Cyan
        if ($Verbose) {
            $cppFiles | ForEach-Object {
                Write-Host "  > $_" -ForegroundColor Gray
            }
        }
    }
    
    $cppStartTime = Get-Date
    
    # Check if clang-format is available
    try {
        $null = Get-Command clang-format -ErrorAction Stop
        
        $cppFormatted = 0
        $cppFailed = 0
        
        foreach ($file in $cppFiles) {
            if (Test-Path $file) {
                if ($Verbose) {
                    & clang-format -i $file
                }
                else {
                    & clang-format -i $file 2>&1 | Out-Null
                }
                
                if ($LASTEXITCODE -eq 0) {
                    $cppFormatted++
                    if ($Verbose) {
                        Write-Host "    [OK] $file" -ForegroundColor Green
                    }
                }
                else {
                    $cppFailed++
                    $stats.Errors += "clang-format failed for: $file"
                    if (-not $Quiet) {
                        Write-Host "    [FAIL] $file" -ForegroundColor Red
                    }
                    $hasError = $true
                }
            }
        }
        
        $cppDuration = (Get-Date) - $cppStartTime
        $stats.FormattedFiles += $cppFormatted
        
        if (-not $hasError) {
            if (-not $Quiet) {
                Write-Host "  [OK] Completed in $([math]::Round($cppDuration.TotalSeconds, 2))s" -ForegroundColor Green
            }
        }
    }
    catch {
        if (-not $Quiet) {
            Write-Host "  [WARN] clang-format not found, skipping C/C++ files" -ForegroundColor Yellow
        }
    }
}

# Calculate total duration
$totalDuration = (Get-Date) - $startTime

# Summary
if (-not $Quiet) {
    Write-Host "`n--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    
    Write-Host "Files processed:  $($stats.TotalFiles)" -ForegroundColor White
    Write-Host "  Frontend:       $($stats.FrontendFiles)" -ForegroundColor White
    if ($stats.BackendFiles.Total -gt 0) {
        Write-Host "  Backend:        $($stats.BackendFiles.Total)" -ForegroundColor White
        if ($stats.BackendFiles.Rust -gt 0) {
            Write-Host "    - Rust:       $($stats.BackendFiles.Rust)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Zig -gt 0) {
            Write-Host "    - Zig:        $($stats.BackendFiles.Zig)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Python -gt 0) {
            Write-Host "    - Python:     $($stats.BackendFiles.Python)" -ForegroundColor Gray
        }
        if ($stats.BackendFiles.Cpp -gt 0) {
            Write-Host "    - C/C++:      $($stats.BackendFiles.Cpp)" -ForegroundColor Gray
        }
    }
    if ($stats.SkippedFiles -gt 0) {
        Write-Host "  Skipped:        $($stats.SkippedFiles)" -ForegroundColor DarkGray
    }
    Write-Host "Formatted:        $($stats.FormattedFiles)" -ForegroundColor $(if ($hasError) { "Yellow" } else { "Green" })
    
    if ($stats.Errors.Count -gt 0) {
        Write-Host "Errors:           $($stats.Errors.Count)" -ForegroundColor Red
    }
    
    Write-Host "Duration:         $([math]::Round($totalDuration.TotalSeconds, 2))s" -ForegroundColor Gray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
}

if ($hasError) {
    if (-not $Quiet) {
        Write-Host "Status: FAILED" -ForegroundColor Red
        if ($stats.Errors.Count -gt 0 -and $Verbose) {
            Write-Host "`nError details:" -ForegroundColor Yellow
            $stats.Errors | ForEach-Object {
                Write-Host "  * $_" -ForegroundColor Red
            }
        }
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    }
    exit 1
}
else {
    if (-not $Quiet) {
        Write-Host "Status: SUCCESS" -ForegroundColor Green
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    }
    exit 0
}

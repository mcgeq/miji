param(
    [ValidateSet("apk", "split-apk", "aab", "analyze-size", "signing-report")]
    [string]$Mode,
    [switch]$SkipSigningReport
)

$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$androidRoot = Join-Path $repoRoot "android"
$gradlew = Join-Path $androidRoot "gradlew.bat"

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)

    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$WorkingDirectory = $repoRoot
    )

    Push-Location $WorkingDirectory
    try {
        & $FilePath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
        }
    } finally {
        Pop-Location
    }
}

function Require-AndroidSigningConfig {
    $keyProperties = Join-Path $androidRoot "key.properties"
    $legacyProperties = Join-Path $androidRoot "keystore.properties"

    if ((Test-Path -LiteralPath $keyProperties) -or
        (Test-Path -LiteralPath $legacyProperties)) {
        return
    }

    throw "Missing Android signing config. Create android/key.properties from android/key.properties.example first."
}

function Select-BuildMode {
    Write-Host ""
    Write-Host "Android build tasks"
    Write-Host "  1. Release APK"
    Write-Host "  2. Split APK by ABI (recommended)"
    Write-Host "  3. App Bundle (AAB)"
    Write-Host "  4. Analyze arm64 APK size"
    Write-Host "  5. Signing report"
    Write-Host ""

    $choice = Read-Host "Choose a task [2]"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = "2"
    }

    switch ($choice.Trim()) {
        "1" { return "apk" }
        "2" { return "split-apk" }
        "3" { return "aab" }
        "4" { return "analyze-size" }
        "5" { return "signing-report" }
        default { throw "Unknown choice: $choice" }
    }
}

function Show-Outputs {
    param([Parameter(Mandatory = $true)][string]$CurrentMode)

    Write-Host ""
    Write-Host "Output:"

    $paths = switch ($CurrentMode) {
        "apk" {
            @(Join-Path $repoRoot "build\app\outputs\flutter-apk\app-release.apk")
        }
        "split-apk" {
            @(Get-ChildItem -Path (Join-Path $repoRoot "build\app\outputs\flutter-apk") -Filter "*-release.apk" -ErrorAction SilentlyContinue |
                Sort-Object Name |
                Select-Object -ExpandProperty FullName)
        }
        "aab" {
            @(Join-Path $repoRoot "build\app\outputs\bundle\release\app-release.aab")
        }
        "analyze-size" {
            @(Join-Path $repoRoot "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk")
        }
        default {
            @()
        }
    }

    if ($paths.Count -eq 0) {
        Write-Host "  No output file was found."
        return
    }

    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) {
            $item = Get-Item -LiteralPath $path
            $sizeMb = [Math]::Round($item.Length / 1MB, 2)
            Write-Host "  $($item.FullName) ($sizeMb MB)"
        } else {
            Write-Host "  $path"
        }
    }
}

if (-not $Mode) {
    $Mode = Select-BuildMode
}

if (-not (Test-CommandAvailable "flutter")) {
    throw "flutter was not found in PATH."
}

if (-not (Test-Path -LiteralPath $gradlew)) {
    throw "Missing Android Gradle wrapper: $gradlew"
}

if ($Mode -ne "signing-report") {
    Require-AndroidSigningConfig
}

if (-not $SkipSigningReport -or $Mode -eq "signing-report") {
    Invoke-Checked -FilePath $gradlew -Arguments @(":app:signingReport") -WorkingDirectory $androidRoot
}

switch ($Mode) {
    "apk" {
        Invoke-Checked -FilePath "flutter" -Arguments @("build", "apk", "--release")
        Show-Outputs -CurrentMode $Mode
    }
    "split-apk" {
        Invoke-Checked -FilePath "flutter" -Arguments @("build", "apk", "--release", "--split-per-abi")
        Show-Outputs -CurrentMode $Mode
    }
    "aab" {
        Invoke-Checked -FilePath "flutter" -Arguments @("build", "appbundle", "--release")
        Show-Outputs -CurrentMode $Mode
    }
    "analyze-size" {
        Invoke-Checked -FilePath "flutter" -Arguments @(
            "build",
            "apk",
            "--release",
            "--analyze-size",
            "--target-platform",
            "android-arm64"
        )
        Show-Outputs -CurrentMode $Mode
    }
    "signing-report" {
        Write-Host ""
        Write-Host "Signing report completed."
    }
}

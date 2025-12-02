# Miji Build Script
# Supports Windows Desktop, Android, and iOS builds

param(
    [Parameter(Mandatory=$false, Position=0)]
    [ValidateSet("windows", "android", "ios", "all")]
    [Alias("t")]
    [string]$Target,
    
    [Parameter(Mandatory=$false)]
    [Alias("c")]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [Alias("d")]
    [switch]$Dev
)

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n==> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "OK $Message" "Green"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "X $Message" "Red"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "! $Message" "Yellow"
}

# Show menu
function Show-Menu {
    Write-ColorOutput "`n========================================" "Cyan"
    Write-ColorOutput "       Miji Build Script v1.0.0        " "Cyan"
    Write-ColorOutput "========================================" "Cyan"
    Write-Host ""
    Write-Host "  1. Windows Desktop (default)" -ForegroundColor White
    Write-Host "  2. Android Mobile" -ForegroundColor White
    Write-Host "  3. iOS Mobile (macOS only)" -ForegroundColor White
    Write-Host "  4. All Platforms" -ForegroundColor White
    Write-Host "  0. Exit" -ForegroundColor White
    Write-Host ""
}

# Clean build artifacts
function Clean-BuildArtifacts {
    Write-Step "Cleaning build artifacts..."
    
    try {
        # Clean frontend build
        if (Test-Path "dist") {
            Remove-Item -Path "dist" -Recurse -Force
            Write-Success "Cleaned dist directory"
        }
        
        # Clean Tauri build
        if (Test-Path "src-tauri/target") {
            Remove-Item -Path "src-tauri/target" -Recurse -Force
            Write-Success "Cleaned src-tauri/target directory"
        }
        
        # Clean mobile build
        if (Test-Path "src-tauri/gen") {
            Remove-Item -Path "src-tauri/gen" -Recurse -Force
            Write-Success "Cleaned src-tauri/gen directory"
        }
        
        Write-Success "Cleanup complete"
    }
    catch {
        Write-Error "Cleanup failed: $_"
        exit 1
    }
}

# Check environment
function Check-Environment {
    param([string]$BuildTarget)
    
    Write-Step "Checking build environment..."
    
    # Check Bun
    if (-not (Get-Command "bun" -ErrorAction SilentlyContinue)) {
        Write-Error "Bun not found. Please install: https://bun.sh"
        exit 1
    }
    Write-Success "Bun is installed"
    
    # Check Rust
    if (-not (Get-Command "cargo" -ErrorAction SilentlyContinue)) {
        Write-Error "Rust not found. Please install: https://rustup.rs"
        exit 1
    }
    Write-Success "Rust is installed"
    
    # Check mobile environment
    if ($BuildTarget -eq "android" -or $BuildTarget -eq "all") {
        if (-not (Get-Command "rustup" -ErrorAction SilentlyContinue)) {
            Write-Error "rustup not found"
            exit 1
        }
        
        # Check Android targets
        $androidTargets = rustup target list --installed
        if (-not ($androidTargets -match "aarch64-linux-android" -and $androidTargets -match "armv7-linux-androideabi")) {
            Write-Warning "Android build targets not installed"
            Write-Host "Installing Android build targets..."
            rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
        }
        Write-Success "Android environment ready"
    }
    
    if ($BuildTarget -eq "ios" -or $BuildTarget -eq "all") {
        if ($IsMacOS -or $IsLinux) {
            # Check iOS targets
            $iosTargets = rustup target list --installed
            if (-not ($iosTargets -match "aarch64-apple-ios")) {
                Write-Warning "iOS build targets not installed"
                Write-Host "Installing iOS build targets..."
                rustup target add aarch64-apple-ios x86_64-apple-ios
            }
            Write-Success "iOS environment ready"
        }
        else {
            Write-Error "iOS build requires macOS"
            exit 1
        }
    }
}

# Build Windows Desktop
function Build-Windows {
    Write-Step "Building Windows Desktop..."
    
    try {
        if ($Dev) {
            bun run tauri dev
        }
        else {
            bun run tauri build
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Windows Desktop build successful!"
            Write-Host ""
            Write-ColorOutput "Installer Location:" "Yellow"
            Write-Host "  * NSIS Installer: src-tauri\target\release\bundle\nsis\"
            Write-Host "  * MSI Package: src-tauri\target\release\bundle\msi\"
        }
        else {
            Write-Error "Windows Desktop build failed"
            exit 1
        }
    }
    catch {
        Write-Error "Build error: $_"
        exit 1
    }
}

# Build Android
function Build-Android {
    Write-Step "Building Android Mobile..."
    
    try {
        # Initialize Android project (first build)
        if (-not (Test-Path "src-tauri/gen/android")) {
            Write-Host "First build, initializing Android project..."
            bun run tauri android init
        }
        
        if ($Dev) {
            bun run tauri android dev
        }
        else {
            # 只构建 arm64 架构的 APK，避免 universal APK 导致体积过大
            # arm64 (aarch64) 是现代 Android 设备的主流架构
            # 这样可以将 APK 大小从 160M 降低到 40M
            bun run tauri android build --apk --target aarch64
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Android Mobile build successful!"
            Write-Host ""
            Write-ColorOutput "APK Location:" "Yellow"
            Write-Host "  * arm64-v8a APK: src-tauri\gen\android\app\build\outputs\apk\arm64-v8a\release\"
            Write-Host ""
            Write-ColorOutput "Note: Built for arm64 only (modern devices)" "Cyan"
            Write-Host "  For universal APK (all architectures), remove --target flag"
        }
        else {
            Write-Error "Android Mobile build failed"
            exit 1
        }
    }
    catch {
        Write-Error "Build error: $_"
        exit 1
    }
}

# Build iOS
function Build-iOS {
    Write-Step "Building iOS Mobile..."
    
    if (-not $IsMacOS) {
        Write-Error "iOS build requires macOS"
        exit 1
    }
    
    try {
        # Initialize iOS project (first build)
        if (-not (Test-Path "src-tauri/gen/apple")) {
            Write-Host "First build, initializing iOS project..."
            bun run tauri ios init
        }
        
        if ($Dev) {
            bun run tauri ios dev
        }
        else {
            bun run tauri ios build
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "iOS Mobile build successful!"
            Write-Host ""
            Write-ColorOutput "IPA Location:" "Yellow"
            Write-Host "  * src-tauri\gen\apple\build\"
        }
        else {
            Write-Error "iOS Mobile build failed"
            exit 1
        }
    }
    catch {
        Write-Error "Build error: $_"
        exit 1
    }
}

# Main function
function Main {
    $startTime = Get-Date
    
    # Show menu if no target specified
    if ([string]::IsNullOrWhiteSpace($Target)) {
        Show-Menu
        $choice = Read-Host "Select build target (default: 1)"
        
        if ([string]::IsNullOrWhiteSpace($choice)) {
            $choice = "1"
        }
        
        switch ($choice) {
            "1" { $Target = "windows" }
            "2" { $Target = "android" }
            "3" { $Target = "ios" }
            "4" { $Target = "all" }
            "0" { 
                Write-Host "Build cancelled"
                exit 0
            }
            default {
                Write-Error "Invalid choice"
                exit 1
            }
        }
    }
    
    Write-ColorOutput "`nStarting Miji build..." "Cyan"
    Write-Host "Target Platform: $Target"
    if ($Dev) {
        Write-Host "Build Mode: Development"
    } else {
        Write-Host "Build Mode: Production"
    }
    
    # Clean build artifacts if specified
    if ($Clean) {
        Clean-BuildArtifacts
    }
    
    # Check environment
    Check-Environment -BuildTarget $Target
    
    # Execute build
    switch ($Target) {
        "windows" {
            Build-Windows
        }
        "android" {
            Build-Android
        }
        "ios" {
            Build-iOS
        }
        "all" {
            Build-Windows
            Build-Android
            if ($IsMacOS) {
                Build-iOS
            }
            else {
                Write-Warning "Skipping iOS build (macOS required)"
            }
        }
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-ColorOutput "========================================" "Green"
    Write-ColorOutput "         Build Completed!              " "Green"
    Write-ColorOutput "========================================" "Green"
    Write-Host ""
    Write-ColorOutput "Total Time: $($duration.ToString('mm\:ss'))" "Yellow"
    Write-Host ""
}

# Execute main function
Main

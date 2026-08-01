param(
    [string]$Keystore = "G:\keystore\miji-upload-keystore.p12",
    [string]$Alias = "upload",
    [int]$ValidityDays = 10000,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    throw "keytool was not found. Install a JDK or add the JDK bin directory to PATH."
}

$keystorePath = [System.IO.Path]::GetFullPath($Keystore)
$keystoreDirectory = [System.IO.Path]::GetDirectoryName($keystorePath)
if ([string]::IsNullOrWhiteSpace($keystoreDirectory)) {
    throw "Invalid keystore path: $Keystore"
}

if (-not (Test-Path -LiteralPath $keystoreDirectory)) {
    New-Item -ItemType Directory -Path $keystoreDirectory | Out-Null
}

if ((Test-Path -LiteralPath $keystorePath) -and -not $Force) {
    throw "Keystore already exists: $keystorePath. Use -Force only if you really want to overwrite it."
}

if ((Test-Path -LiteralPath $keystorePath) -and $Force) {
    Remove-Item -LiteralPath $keystorePath -Force
}

keytool -genkeypair -v `
    -keystore $keystorePath `
    -storetype PKCS12 `
    -keyalg RSA `
    -keysize 2048 `
    -validity $ValidityDays `
    -alias $Alias

Write-Host ""
Write-Host "Keystore created: $keystorePath"
Write-Host "Alias: $Alias"
Write-Host ""
Write-Host "Next, create android/key.properties with:"
Write-Host "storeFile=$($keystorePath.Replace('\', '\\'))"
Write-Host "storePassword=<store-password>"
Write-Host "keyAlias=$Alias"
Write-Host "keyPassword=<key-password>"

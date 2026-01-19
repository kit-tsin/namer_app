# PowerShell script to get Android debug key hash for Facebook
# This script gets both SHA-1 and SHA-256 hashes

Write-Host "Getting Android Debug Key Hash..." -ForegroundColor Cyan
Write-Host ""

$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (-not (Test-Path $keytoolPath)) {
    Write-Host "Error: keytool not found at $keytoolPath" -ForegroundColor Red
    Write-Host "Please make sure Android Studio is installed." -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $keystorePath)) {
    Write-Host "Error: Debug keystore not found at $keystorePath" -ForegroundColor Red
    Write-Host "The debug keystore will be created automatically when you build your first Android app." -ForegroundColor Yellow
    exit 1
}

Write-Host "Running keytool..." -ForegroundColor Gray
Write-Host ""

$output = & $keytoolPath -list -v -alias androiddebugkey -keystore $keystorePath -storepass android 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error running keytool:" -ForegroundColor Red
    Write-Host $output -ForegroundColor Red
    exit 1
}

# Extract SHA-1
$sha1Match = $output | Select-String -Pattern "SHA1:\s+([A-F0-9:]+)"
if ($sha1Match) {
    $sha1 = $sha1Match.Matches[0].Groups[1].Value
    Write-Host "SHA-1 Key Hash:" -ForegroundColor Green
    Write-Host $sha1 -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Warning: Could not extract SHA-1 hash" -ForegroundColor Yellow
}

# Extract SHA-256
$sha256Match = $output | Select-String -Pattern "SHA256:\s+([A-F0-9:]+)"
if ($sha256Match) {
    $sha256 = $sha256Match.Matches[0].Groups[1].Value
    Write-Host "SHA-256 Key Hash:" -ForegroundColor Green
    Write-Host $sha256 -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Warning: Could not extract SHA-256 hash" -ForegroundColor Yellow
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Go to https://developers.facebook.com/apps/" -ForegroundColor White
Write-Host "2. Select your app (ID: 850045457924806)" -ForegroundColor White
Write-Host "3. Go to Settings > Basic > Android" -ForegroundColor White
Write-Host "4. Add the key hashes above" -ForegroundColor White
Write-Host "5. Save changes and restart your app" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

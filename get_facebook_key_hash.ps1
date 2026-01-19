# PowerShell script to get Facebook Key Hash in Base64 format

$keytoolPath = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

Write-Host "Getting Facebook Key Hash (Base64 format)..." -ForegroundColor Cyan
Write-Host ""

# Get the SHA-1 hash from keytool
$output = & $keytoolPath -list -v -alias androiddebugkey -keystore $keystorePath -storepass android 2>&1
$sha1Match = $output | Select-String -Pattern "SHA1:\s+([A-F0-9:]+)"

if ($sha1Match) {
    $sha1Hex = $sha1Match.Matches[0].Groups[1].Value
    
    # Remove colons and convert to bytes
    $hexString = $sha1Hex -replace ':', ''
    $bytes = @()
    for ($i = 0; $i -lt $hexString.Length; $i += 2) {
        $bytes += [Convert]::ToByte($hexString.Substring($i, 2), 16)
    }
    
    # Convert to Base64
    $base64Hash = [Convert]::ToBase64String($bytes)
    
    Write-Host "SHA-1 (Hex): $sha1Hex" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Facebook Key Hash (Base64) - USE THIS:" -ForegroundColor Green
    Write-Host $base64Hash -ForegroundColor White
    Write-Host ""
    
    # Copy to clipboard
    try {
        Set-Clipboard -Value $base64Hash
        Write-Host "Copied to clipboard!" -ForegroundColor Green
    } catch {
        Write-Host "Could not copy to clipboard" -ForegroundColor Yellow
    }
} else {
    Write-Host "Error: Could not extract SHA-1 hash" -ForegroundColor Red
    exit 1
}

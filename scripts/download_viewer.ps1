param (
    [switch]$Force
)

$targetDir = "$PSScriptRoot\..\SIBR_viewers"
$zipPath = "$PSScriptRoot\..\SIBR_viewers.zip"
$downloadUrl = "https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/binaries/viewers.zip"

if ((Test-Path "$targetDir\bin") -and (-not $Force)) {
    Write-Host "SIBR_viewers already exists. Use -Force to re-download." -ForegroundColor Yellow
    exit 0
}

Write-Host "Downloading SIBR_viewers (this may take a while)..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
} catch {
    Write-Host "Failed to download SIBR_viewers: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Extracting SIBR_viewers..." -ForegroundColor Cyan
if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
Remove-Item -Force $zipPath

Write-Host "SIBR_viewers downloaded and extracted successfully." -ForegroundColor Green
exit 0

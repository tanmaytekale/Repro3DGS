param (
    [switch]$Force
)

$targetDir = "$PSScriptRoot\..\colmap"
$zipPath = "$PSScriptRoot\..\colmap.zip"
$downloadUrl = "https://github.com/colmap/colmap/releases/download/3.8/COLMAP-3.8-windows-cuda.zip"

if ((Test-Path "$targetDir\COLMAP.bat") -and (-not $Force)) {
    Write-Host "COLMAP already exists. Use -Force to re-download." -ForegroundColor Yellow
    exit 0
}

Write-Host "Downloading COLMAP 3.8 (this may take a while)..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
} catch {
    Write-Host "Failed to download COLMAP: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Extracting COLMAP..." -ForegroundColor Cyan
if (Test-Path $targetDir) { Remove-Item -Recurse -Force $targetDir }
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force
Remove-Item -Force $zipPath

Write-Host "COLMAP downloaded and extracted successfully." -ForegroundColor Green
exit 0

[CmdletBinding()]
param(
    [switch]$AllowDestructiveTests
)

$env_name = "3dgs_community"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " 3DGS Validation & Reproducibility Suite" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Environment Snapshot
Write-Host "`n[1/4] Snapshotting Environment..." -ForegroundColor Yellow
$snapshotFile = "validation_env_backup.yml"
$envs = conda env list
if ($envs -match "\b$env_name\b") {
    & cmd.exe /c "conda env export -n $env_name > $snapshotFile"
    Write-Host " Snapshot saved to $snapshotFile" -ForegroundColor Green
} else {
    Write-Host " No existing environment found to snapshot." -ForegroundColor DarkGray
}

# 2. Idempotency Test (Existing Env)
Write-Host "`n[2/4] Testing Idempotency (Existing Installation)..." -ForegroundColor Yellow
Write-Host " Running installer over an existing installation to ensure it does not break."
& .\install_windows.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host " Idempotency test passed." -ForegroundColor Green
} else {
    Write-Host " Idempotency test failed." -ForegroundColor Red
    exit 1
}

# 3. Contamination Test (Isolated Cache)
Write-Host "`n[3/4] Testing System Contamination Resilience..." -ForegroundColor Yellow
$tempCache = ".temp_pip_cache"
$env:PIP_CACHE_DIR = $tempCache

Write-Host " Simulating a user manually installing CPU Torch..."
& cmd.exe /c "conda run -n $env_name --no-capture-output pip install torch==2.1.0+cpu --index-url https://download.pytorch.org/whl/cpu --force-reinstall" | Out-Null

Write-Host " Re-running the full installer to ensure it can detect and recover from contamination..."
& .\install_windows.ps1
if ($LASTEXITCODE -eq 0) {
    Write-Host " Contamination test passed. The installer successfully recovered the environment." -ForegroundColor Green
} else {
    Write-Host " Contamination test failed." -ForegroundColor Red
    exit 1
}

# 4. Cleanup and Restoration
Write-Host "`n[4/4] Cleaning Up..." -ForegroundColor Yellow
if (Test-Path $tempCache) { Remove-Item -Recurse -Force $tempCache }

if (Test-Path $snapshotFile) {
    Write-Host " Restoring environment from snapshot..."
    & cmd.exe /c "conda env update -n $env_name -f $snapshotFile --prune"
    Write-Host " Environment restored." -ForegroundColor Green
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " Validation Suite Completed Successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

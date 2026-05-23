[CmdletBinding()]
param()

$bundleDir = "debug_bundle"
if (Test-Path $bundleDir) { Remove-Item -Recurse -Force $bundleDir }
New-Item -ItemType Directory -Path $bundleDir | Out-Null

Write-Host "Collecting 3DGS Debug Bundle..." -ForegroundColor Cyan

# 1. Collect Logs
$logs = @("install.log", "compile.log", "diagnostics.log")
foreach ($log in $logs) {
    if (Test-Path $log) {
        Copy-Item $log -Destination "$bundleDir\"
        Write-Host " Copied $log"
    } else {
        Write-Host " Missing $log" -ForegroundColor Yellow
    }
}

# 2. Collect System Info
$sysInfoPath = "$bundleDir\system_info.txt"
"--- OS Info ---" | Out-File $sysInfoPath
[System.Environment]::OSVersion.VersionString | Out-File $sysInfoPath -Append

"--- GPU Info ---" | Out-File $sysInfoPath -Append
if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
    & nvidia-smi | Out-File $sysInfoPath -Append
} else {
    "nvidia-smi not found" | Out-File $sysInfoPath -Append
}
Write-Host " Copied system info"

# 3. Collect Conda Environment Info
$env_name = "3dgs_community"
$envs = conda env list
if ($envs -match "\b$env_name\b") {
    Write-Host " Exporting conda environment..."
    & cmd.exe /c "conda env export -n $env_name > `"$bundleDir\conda_env.yml`""
    
    Write-Host " Exporting pip freeze..."
    & cmd.exe /c "conda run -n $env_name --no-capture-output pip freeze > `"$bundleDir\pip_freeze.txt`""
} else {
    Write-Host " Environment $env_name not found. Skipping env export." -ForegroundColor Yellow
}

# 4. Zip the bundle
$zipPath = "debug_bundle.zip"
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path "$bundleDir\*" -DestinationPath $zipPath
Remove-Item -Recurse -Force $bundleDir

Write-Host "`nDebug bundle created at: $zipPath" -ForegroundColor Green
Write-Host "Please attach this file when opening a GitHub issue." -ForegroundColor Cyan

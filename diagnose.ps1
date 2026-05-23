<#
.SYNOPSIS
    3DGS Community Edition - Diagnostics Utility
.DESCRIPTION
    Outputs system information, GPU models, compiler versions, and detects common issues.
#>

$ErrorActionPreference = "Continue"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " 3DGS Community Edition - Diagnostics Report" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. OS Info
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Host "`n[OS Information]" -ForegroundColor Yellow
Write-Host "OS: $($osInfo.Caption) ($($osInfo.OSArchitecture))"

# 2. GPU & CUDA Detection
Write-Host "`n[GPU & NVIDIA Detection]" -ForegroundColor Yellow
if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
    $gpuInfo = nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader
    Write-Host "Detected GPUs: $gpuInfo"
    
    # Check if Blackwell (sm_120) is detected
    if ($gpuInfo -match "12.0") {
        Write-Host ">> Blackwell GPU Detected (sm_120). Requires PyTorch Nightly cu128." -ForegroundColor Green
    }
} else {
    Write-Host "nvidia-smi not found! Ensure NVIDIA drivers are installed and in PATH." -ForegroundColor Red
}

if (Get-Command "nvcc" -ErrorAction SilentlyContinue) {
    $nvccInfo = nvcc --version | Select-String "release"
    Write-Host "NVCC Version: $nvccInfo"
} else {
    Write-Host "nvcc not found! Is CUDA Toolkit installed and in PATH?" -ForegroundColor Red
}

# 3. Compiler Detection (MSVC)
Write-Host "`n[Compiler Detection (MSVC)]" -ForegroundColor Yellow
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = ""
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -property installationPath
}

$vcvars = ""
if ($vsPath) {
    $vcvars = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"
}

if (-not $vcvars -or -not (Test-Path $vcvars -ErrorAction SilentlyContinue)) {
    # Fallback paths
    $fallback_paths = @(
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files (x86)\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat",
        "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat"
    )
    foreach ($p in $fallback_paths) {
        if ($p -and (Test-Path $p -ErrorAction SilentlyContinue)) {
            $vcvars = $p
            break
        }
    }
}

if ($vcvars -and (Test-Path $vcvars -ErrorAction SilentlyContinue)) {
    Write-Host "Build Tools (vcvars64.bat) found at: $vcvars" -ForegroundColor Green
} else {
    Write-Host "vcvars64.bat not found! Ensure Desktop C++ workload is installed." -ForegroundColor Red
}

# 4. Conda Environment
Write-Host "`n[Python & Conda]" -ForegroundColor Yellow
if (Get-Command "conda" -ErrorAction SilentlyContinue) {
    $condaVer = conda --version
    Write-Host "Conda Version: $condaVer"
    
    $envs = conda env list
    if ($envs -match "3dgs_community") {
        Write-Host "3dgs_community environment found." -ForegroundColor Green
    } else {
        Write-Host "3dgs_community environment not found. Run install_windows.ps1 first." -ForegroundColor Gray
    }
} else {
    Write-Host "conda not found in PATH!" -ForegroundColor Red
}

# 5. Extension Compile Status
Write-Host "`n[Submodule Extension Compile Status]" -ForegroundColor Yellow
$env_name = "3dgs_community"
$python_cmd = "conda run -n $env_name python -c"

try {
    $out = Invoke-Expression "$python_cmd ""import torch; print(f'PyTorch {torch.__version__}')""" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PyTorch Status: $out"
    } else {
        Write-Host "PyTorch: Not installed or environment missing." -ForegroundColor Red
    }

    $out = Invoke-Expression "$python_cmd ""import diff_gaussian_rasterization; print('diff_gaussian_rasterization: OK')""" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "Rasterizer: Installed" -ForegroundColor Green } else { Write-Host "Rasterizer: NOT Installed" -ForegroundColor Red }

    $out = Invoke-Expression "$python_cmd ""import simple_knn; print('simple_knn: OK')""" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "Simple-KNN: Installed" -ForegroundColor Green } else { Write-Host "Simple-KNN: NOT Installed" -ForegroundColor Red }

    $out = Invoke-Expression "$python_cmd ""import fused_ssim; print('fused_ssim: OK')""" 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "Fused-SSIM: Installed" -ForegroundColor Green } else { Write-Host "Fused-SSIM: NOT Installed" -ForegroundColor Red }

} catch {
    Write-Host "Error checking extensions." -ForegroundColor Red
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Diagnostics Complete." -ForegroundColor Cyan

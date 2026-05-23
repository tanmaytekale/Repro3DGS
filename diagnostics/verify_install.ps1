[CmdletBinding()]
param(
    [switch]$RunMiniTrain
)

$env_name = "3dgs_community"
$python_cmd = "conda run -n $env_name --no-capture-output python"

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host " 3DGS Verification Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Check Python/Torch
$pyCode = @"
import torch
import sys
print(f'Python Version: {sys.version.split()[0]}')
print(f'Torch Version: {torch.__version__}')
cuda_avail = torch.cuda.is_available()
print(f'CUDA Available: {cuda_avail}')
if cuda_avail:
    print(f'GPU Detected: {torch.cuda.get_device_name(0)}')
"@
$pyCode | Out-File -FilePath .verify_torch.py -Encoding utf8
$condaOut = & cmd.exe /c "$python_cmd .verify_torch.py"
Write-Host $condaOut
Remove-Item .verify_torch.py -ErrorAction SilentlyContinue

# Check Extensions
$extCode = @"
try:
    import diff_gaussian_rasterization
    import simple_knn
    import fused_ssim
    print('Extensions: COMPILED & IMPORTED SUCCESSFULLY')
except Exception as e:
    print(f'Extensions: FAILED TO IMPORT ({e})')
"@
$extCode | Out-File -FilePath .verify_ext.py -Encoding utf8
$extOut = & cmd.exe /c "$python_cmd .verify_ext.py"
if ($extOut -match "SUCCESSFULLY") {
    Write-Host $extOut -ForegroundColor Green
} else {
    Write-Host $extOut -ForegroundColor Red
}
Remove-Item .verify_ext.py -ErrorAction SilentlyContinue

# Check SIBR Viewer
$viewerPath = "SIBR_viewers\bin\SIBR_gaussianViewer_app.exe"
if (Test-Path $viewerPath) {
    Write-Host "SIBR Viewer: FOUND" -ForegroundColor Green
} else {
    Write-Host "SIBR Viewer: NOT FOUND" -ForegroundColor Red
}

if ($RunMiniTrain) {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host " Running Mini-Train Validation" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    
    $testDir = ".temp_dataset"
    if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
    New-Item -ItemType Directory -Path "$testDir\input" | Out-Null
    
    $imgs = Get-ChildItem -Path "data\input" -Filter "*.jpg" | Select-Object -First 10
    if ($imgs) {
        foreach ($img in $imgs) { Copy-Item $img.FullName -Destination "$testDir\input\" }
        $colmap_bin = "$PSScriptRoot\..\colmap\COLMAP.bat"
        if (-not (Test-Path $colmap_bin)) {
            Write-Host "CRITICAL: COLMAP not found at $colmap_bin." -ForegroundColor Red
            Write-Host "Please run '.\scripts\download_colmap.ps1' to automatically download it." -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Converting dataset using COLMAP..." -ForegroundColor Yellow
        $python_cmd = "conda run -n 3dgs_community --no-capture-output python"
        
        # We need to run convert.py and train.py from the root of the repository
        $repo_root = "$PSScriptRoot\.."
        $convert_cmd = "$python_cmd `"$repo_root\convert.py`" -s `"$testDir`" --colmap_executable `"$colmap_bin`""
        & cmd.exe /c "$convert_cmd > `"$testDir\convert.log`" 2>&1"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "COLMAP conversion failed! See $testDir\convert.log" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "COLMAP conversion successful." -ForegroundColor Green
            Write-Host "Running 10 iterations of train.py..." -ForegroundColor Yellow
            
            # Run 10 iterations and force save at iteration 10
            & cmd.exe /c "cd /d `"$repo_root`" && $python_cmd train.py -s `"$testDir`" --iterations 10 -m `"$testDir\output`" --save_iterations 10"
            
            if (Test-Path "$testDir\output\point_cloud\iteration_10\point_cloud.ply") {
                Write-Host "Mini-Train Validation: SUCCESS (Point cloud checkpoint generated)" -ForegroundColor Green
            } else {
                Write-Host "Mini-Train Validation: FAILED (No checkpoints found)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "No images found in data\input to run Mini-Train." -ForegroundColor Yellow
    }
}
Write-Host "==================================================`n" -ForegroundColor Cyan

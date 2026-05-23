<#
.SYNOPSIS
    3DGS Community Edition - Unattended Windows Installer
.DESCRIPTION
    Automates the entire setup of 3D Gaussian Splatting for Windows.
    Fully non-interactive, debug-friendly, and supports resuming from specific steps.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$RecreateEnv,
    [switch]$DebugMode,
    [string]$Step = "All"
)

$ErrorActionPreference = "Continue"

$LogFile = "install.log"
$CompileLog = "compile.log"

if ($Step -eq "All") {
    Clear-Content $LogFile -ErrorAction SilentlyContinue
    Clear-Content $CompileLog -ErrorAction SilentlyContinue
}

$globalStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $formatted = "[$timestamp] $Message"
    Write-Host $formatted -ForegroundColor $Color
    $formatted | Out-File -FilePath $LogFile -Append -Encoding utf8
}

if ($DebugMode) {
    Write-Log "[DEBUG] Debug mode enabled. Step: $Step" "DarkGray"
    Write-Log "[DEBUG] Force: $Force | RecreateEnv: $RecreateEnv" "DarkGray"
}

function Invoke-SafeCommand {
    param(
        [string]$Command,
        [int]$TimeoutSeconds = 600,
        [string]$LogPath = $LogFile,
        [string]$ProbableIssue = "The process might be hung waiting for user input, or a network request is stalled."
    )
    Write-Log "Running: $Command" "Yellow"
    if ($DebugMode) { Write-Log "[DEBUG] Timeout set to $TimeoutSeconds seconds" "DarkGray" }
    
    $tempLog = [System.IO.Path]::GetTempFileName()
    $env:PYTHONUNBUFFERED = "1"
    $env:PIP_NO_INPUT = "1"
    
    # We wrap in cmd.exe so we can redirect all streams
    $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$Command > `"$tempLog`" 2>&1`"" -PassThru -WindowStyle Hidden
    
    $elapsed = 0
    $lastReadIndex = 0
    
    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 500
        $elapsed += 0.5
        
        if (Test-Path $tempLog) {
            $lines = Get-Content $tempLog -ErrorAction SilentlyContinue
            if ($lines -is [array] -or $lines -is [string]) {
                $lineArray = @($lines)
                if ($lineArray.Count -gt $lastReadIndex) {
                    for ($i = $lastReadIndex; $i -lt $lineArray.Count; $i++) {
                        Write-Host $lineArray[$i]
                        $lineArray[$i] | Out-File -FilePath $LogPath -Append -Encoding utf8
                    }
                    $lastReadIndex = $lineArray.Count
                }
            }
        }
        
        if ($elapsed -ge $TimeoutSeconds) {
            Write-Log "WARNING: Command exceeded timeout of $TimeoutSeconds seconds!" "Red"
            Write-Log "Command: $Command" "Red"
            Write-Log "Probable Issue: $ProbableIssue" "Red"
            Write-Log "Terminating process..." "Red"
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    
    # Flush remaining lines
    if (Test-Path $tempLog) {
        $lines = Get-Content $tempLog -ErrorAction SilentlyContinue
        if ($lines -is [array] -or $lines -is [string]) {
            $lineArray = @($lines)
            if ($lineArray.Count -gt $lastReadIndex) {
                for ($i = $lastReadIndex; $i -lt $lineArray.Count; $i++) {
                    Write-Host $lineArray[$i]
                    $lineArray[$i] | Out-File -FilePath $LogPath -Append -Encoding utf8
                }
            }
        }
    }
    Remove-Item $tempLog -ErrorAction SilentlyContinue
    
    if ($proc.ExitCode -ne 0) {
        Write-Log "Command failed with exit code $($proc.ExitCode)." "Red"
        return $false
    }
    return $true
}

function Run-Step {
    param(
        [string]$StepName,
        [string]$Description,
        [scriptblock]$Action
    )
    if ($Step -eq "All" -or $Step -eq $StepName) {
        Write-Log "`n==================================================" "Cyan"
        Write-Log " Phase: $StepName" "Cyan"
        Write-Log " $Description" "Cyan"
        Write-Log "==================================================" "Cyan"
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        & $Action
        
        $stopwatch.Stop()
        Write-Log "Phase '$StepName' completed in $($stopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds." "Green"
    } else {
        if ($DebugMode) { Write-Log "Skipping Phase: $StepName" "DarkGray" }
    }
}

$env_name = "3dgs_community"
$global:torch_cuda_arch = ""
$global:pytorch_channel = ""
$global:vcvars = ""

Run-Step -StepName "Init" -Description "Checking Conda installation" -Action {
    if (-not (Get-Command "conda" -ErrorAction SilentlyContinue)) {
        Write-Log "Conda not found. Please install Anaconda or Miniconda first." "Red"
        exit 1
    }
    $condaVer = conda --version
    Write-Log "Found Conda: $condaVer"
}

Run-Step -StepName "DetectGPU" -Description "Detecting NVIDIA GPU Architecture" -Action {
    if (Get-Command "nvidia-smi" -ErrorAction SilentlyContinue) {
        $gpuCaps = nvidia-smi --query-gpu=compute_cap --format=csv,noheader
        $gpuCaps = ($gpuCaps -replace "`r`n",";" -replace "\s","").Trim()
        Write-Log "Detected GPU Capabilities: $gpuCaps"
        
        $archMapping = @{
            "12.0" = @{ Channel = "--pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"; Target = "12.0a"; Name = "Blackwell (sm_120) Nightly cu128" }
            "8.9"  = @{ Channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"; Target = "8.9"; Name = "Ada (sm_89) Stable cu124" }
            "8.6"  = @{ Channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"; Target = "8.6"; Name = "Ampere (sm_86) Stable cu124" }
            "8.0"  = @{ Channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"; Target = "8.0"; Name = "Ampere (sm_80) Stable cu124" }
            "7.5"  = @{ Channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"; Target = "7.5"; Name = "Turing (sm_75) Stable cu124" }
        }

        $matched = $false
        foreach ($key in $archMapping.Keys) {
            if ($gpuCaps -match $key) {
                $config = $archMapping[$key]
                Write-Log "Mapped Architecture: $($config.Name)" "Green"
                $global:pytorch_channel = $config.Channel
                $global:torch_cuda_arch = $config.Target
                $matched = $true
                break
            }
        }

        if (-not $matched) {
            Write-Log "Standard/Unknown GPU detected. Using PyTorch Stable cu124 fallback." "Green"
            $global:pytorch_channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
            $global:torch_cuda_arch = $gpuCaps
        }
    } else {
        Write-Log "WARNING: nvidia-smi not found. Defaulting to standard PyTorch cu124." "Yellow"
        $global:pytorch_channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
    }
}

Run-Step -StepName "SetupEnv" -Description "Creating Conda Environment" -Action {
    $envs = conda env list
    if ($envs -match "\b$env_name\b") {
        if ($RecreateEnv) {
            Write-Log "Environment '$env_name' exists. Removing as requested (-RecreateEnv)."
            $success = Invoke-SafeCommand -Command "conda env remove -n $env_name -y" -TimeoutSeconds 120 -ProbableIssue "Conda environment removal hung."
            if (-not $success) { exit 1 }
            
            Write-Log "Creating fresh Conda environment '$env_name' with Python 3.11..."
            $success = Invoke-SafeCommand -Command "conda create -n $env_name python=3.11 -y" -TimeoutSeconds 600 -ProbableIssue "Conda package download hung. Check network."
            if (-not $success) { exit 1 }
        } else {
            Write-Log "Environment '$env_name' already exists. Using existing environment." "Green"
            Write-Log "Note: Use -RecreateEnv flag to force a clean slate." "Yellow"
        }
    } else {
        Write-Log "Creating Conda environment '$env_name' with Python 3.11..."
        $success = Invoke-SafeCommand -Command "conda create -n $env_name python=3.11 -y" -TimeoutSeconds 600 -ProbableIssue "Conda package download hung. Check network."
        if (-not $success) { exit 1 }
    }
}

Run-Step -StepName "InstallDependencies" -Description "Installing general dependencies" -Action {
    $success = Invoke-SafeCommand -Command "conda run -n $env_name pip install plyfile tqdm colorama opencv-python joblib" -TimeoutSeconds 300
    if (-not $success) { exit 1 }
}

Run-Step -StepName "InstallTorch" -Description "Installing PyTorch" -Action {
    if (-not $global:pytorch_channel) {
        # Fallback if jumping straight to this step
        $global:pytorch_channel = "torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
    }
    Write-Log "Installing PyTorch using channel: $global:pytorch_channel"
    $success = Invoke-SafeCommand -Command "conda run -n $env_name pip install $global:pytorch_channel" -TimeoutSeconds 1800 -ProbableIssue "Large PyTorch download hung. Check internet connection."
    if (-not $success) { exit 1 }
}

Run-Step -StepName "LocateMSVC" -Description "Locating Visual Studio Build Tools" -Action {
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

    if (-not $vcvars -or -not (Test-Path $vcvars -ErrorAction SilentlyContinue)) {
        Write-Log "vcvars64.bat not found! Ensure Desktop C++ workload is installed." "Red"
        exit 1
    } else {
        Write-Log "Visual Studio Build Tools located at: $vcvars" "Green"
        $global:vcvars = $vcvars
    }
}

Run-Step -StepName "CompileExtensions" -Description "Compiling Custom CUDA Submodules" -Action {
    if (-not $global:vcvars) {
        # Fallback if jumping straight to this step
        $global:vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    }
    
    $env:DISTUTILS_USE_SDK = "1"
    if ($global:torch_cuda_arch) {
        $env:TORCH_CUDA_ARCH_LIST = $global:torch_cuda_arch
        Write-Log "Targeting explicit CUDA architectures: $global:torch_cuda_arch"
    }

    Write-Log "Compiling diff-gaussian-rasterization, simple-knn, fused-ssim..."
    $conda_python = "conda run -n $env_name --no-capture-output python"
    
    # Pre-clean just in case
    $cmd = "cmd.exe /c `"call `"$global:vcvars`" && $conda_python -m pip install `"$PSScriptRoot\..\submodules\diff-gaussian-rasterization`" `"$PSScriptRoot\..\submodules\simple-knn`" `"$PSScriptRoot\..\submodules\fused-ssim`" --no-build-isolation --no-cache-dir --force-reinstall --no-deps`""
    
    $success = Invoke-SafeCommand -Command $cmd -TimeoutSeconds 900 -LogPath $CompileLog -ProbableIssue "Native compilation hung. Could be nvcc compiler waiting on a lock or missing dependencies."
    
    if (-not $success) {
        Write-Log "`n[CRITICAL ERROR] Compilation failed! We detected your GPU, but PyTorch could not find or use the Visual Studio C++ Compiler." "Red"
        Write-Log "Why it happened: Native CUDA extensions require MSVC C++ tools to link against PyTorch." "Yellow"
        Write-Log "How to fix it:" "Green"
        Write-Log "  1. Install Visual Studio 2022 Build Tools." "White"
        Write-Log "  2. Select the 'Desktop development with C++' workload." "White"
        Write-Log "  3. Then rerun: .\scripts\install_windows.ps1 -Step CompileExtensions" "White"
        Write-Log "`nReview compile.log for detailed MSVC/NVCC errors." "Red"
        exit 1
    }
}

Run-Step -StepName "FixViewerDLLs" -Description "Copying Missing CUDA Runtime DLLs to SIBR Viewer" -Action {
    $torch_dir = conda run -n $env_name python -c "import torch, os; print(os.path.dirname(torch.__file__))" 2>$null
    if ($torch_dir) {
        $cudart_path = Get-ChildItem -Path $torch_dir -Filter "cudart64_*.dll" -Recurse | Select-Object -First 1 -ExpandProperty FullName
        if ($cudart_path) {
            $viewer_bin = "$PSScriptRoot\..\SIBR_viewers\bin"
            if (Test-Path $viewer_bin) {
                Copy-Item $cudart_path -Destination "$viewer_bin\" -Force
                Write-Log "Copied $cudart_path to SIBR_viewers/bin." "Green"
            } else {
                Write-Log "INFO: SIBR_viewers/bin not found. Run download_viewer.ps1 first if you want the viewer." "DarkGray"
            }
        }
    }
}

Run-Step -StepName "Validate" -Description "Validating Installation" -Action {
    $conda_python = "conda run -n $env_name --no-capture-output python"
    $val_cmd = "$conda_python -c `"import diff_gaussian_rasterization, simple_knn, fused_ssim; import torch; assert torch.cuda.is_available(); print('Validation Success!')`""
    $success = Invoke-SafeCommand -Command $val_cmd -TimeoutSeconds 60
    
    if ($success) {
        Write-Log "`n==================================================" "Green"
        Write-Log " 3DGS Community Edition successfully installed!" "Green"
        Write-Log " Activate your environment using: conda activate $env_name" "Green"
        Write-Log " Then run: python train.py -s data" "Green"
        Write-Log "==================================================" "Green"
    } else {
        Write-Log "Validation failed. Extensions did not import properly. Please run diagnose.ps1." "Red"
        exit 1
    }
}

if ($Step -eq "All") {
    $globalStopwatch.Stop()
    Write-Log "`n--- Performance Metrics ---" "Cyan"
    Write-Log "Total Installation Time: $($globalStopwatch.Elapsed.TotalSeconds.ToString('F2')) seconds" "Cyan"
}

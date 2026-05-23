#!/bin/bash
# 3DGS Community Edition - Unattended Linux Installer

set -e

FORCE=0
RECREATE_ENV=0
DEBUG_MODE=0
STEP="All"

for arg in "$@"; do
    case $arg in
        --Force|-Force) FORCE=1 ;;
        --RecreateEnv|-RecreateEnv) RECREATE_ENV=1 ;;
        --DebugMode|-DebugMode) DEBUG_MODE=1 ;;
        --Step=*|-Step=*) STEP="${arg#*=}" ;;
    esac
done

LOG_FILE="install.log"
COMPILE_LOG="compile.log"

if [ "$STEP" = "All" ]; then
    > "$LOG_FILE"
    > "$COMPILE_LOG"
fi

write_log() {
    local MESSAGE=$1
    local COLOR=$2
    local TIMESTAMP=$(date +"%H:%M:%S")
    local FORMATTED="[$TIMESTAMP] $MESSAGE"
    
    case $COLOR in
        "White") echo -e "$FORMATTED" ;;
        "Cyan") echo -e "\e[36m$FORMATTED\e[0m" ;;
        "Green") echo -e "\e[32m$FORMATTED\e[0m" ;;
        "Yellow") echo -e "\e[33m$FORMATTED\e[0m" ;;
        "Red") echo -e "\e[31m$FORMATTED\e[0m" ;;
        "DarkGray") echo -e "\e[90m$FORMATTED\e[0m" ;;
        *) echo -e "$FORMATTED" ;;
    esac
    echo "$FORMATTED" >> "$LOG_FILE"
}

if [ "$DEBUG_MODE" -eq 1 ]; then
    write_log "[DEBUG] Debug mode enabled. Step: $STEP" "DarkGray"
fi

run_step() {
    local STEP_NAME=$1
    local DESC=$2
    local ACTION=$3

    if [ "$STEP" = "All" ] || [ "$STEP" = "$STEP_NAME" ]; then
        write_log "\n==================================================" "Cyan"
        write_log " Phase: $STEP_NAME" "Cyan"
        write_log " $DESC" "Cyan"
        write_log "==================================================" "Cyan"
        
        local START_TIME=$(date +%s)
        eval "$ACTION"
        local END_TIME=$(date +%s)
        local ELAPSED=$((END_TIME - START_TIME))
        
        write_log "Phase '$STEP_NAME' completed in $ELAPSED seconds." "Green"
    else
        if [ "$DEBUG_MODE" -eq 1 ]; then write_log "Skipping Phase: $STEP_NAME" "DarkGray"; fi
    fi
}

ENV_NAME="3dgs_community"
export PYTHONUNBUFFERED=1

if [ "$STEP" = "All" ]; then
    GLOBAL_START=$(date +%s)
fi

run_step "Init" "Checking Conda installation" '
    if ! command -v conda &> /dev/null; then
        write_log "Conda not found. Please install Anaconda or Miniconda first." "Red"
        exit 1
    fi
    CONDA_VER=$(conda --version)
    write_log "Found Conda: $CONDA_VER" "White"
'

run_step "DetectGPU" "Detecting NVIDIA GPU Architecture" '
    if command -v nvidia-smi &> /dev/null; then
        GPU_CAPS=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | tr "\n" ";" | sed "s/ //g" | sed "s/;$//")
        write_log "Detected GPU Capabilities: $GPU_CAPS" "White"
        
        if echo "$GPU_CAPS" | grep -q "12.0"; then
            write_log "Mapped Architecture: Blackwell (sm_120) Nightly cu128" "Green"
            PYTORCH_CHANNEL="--pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
            TORCH_CUDA_ARCH="12.0a"
        elif echo "$GPU_CAPS" | grep -q "8.9"; then
            write_log "Mapped Architecture: Ada (sm_89) Stable cu124" "Green"
            PYTORCH_CHANNEL="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
            TORCH_CUDA_ARCH="8.9"
        elif echo "$GPU_CAPS" | grep -q "8.6"; then
            write_log "Mapped Architecture: Ampere (sm_86) Stable cu124" "Green"
            PYTORCH_CHANNEL="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
            TORCH_CUDA_ARCH="8.6"
        else
            write_log "Standard GPU detected. Using PyTorch Stable cu124." "Green"
            PYTORCH_CHANNEL="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
            TORCH_CUDA_ARCH=$GPU_CAPS
        fi
    else
        write_log "WARNING: nvidia-smi not found. Defaulting to standard PyTorch cu124." "Yellow"
        PYTORCH_CHANNEL="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
    fi
'

run_step "SetupEnv" "Creating Conda Environment" '
    if conda env list | grep -q "$ENV_NAME"; then
        if [ "$RECREATE_ENV" -eq 1 ]; then
            write_log "Environment exists. Removing..." "White"
            conda env remove -n $ENV_NAME -y >> $LOG_FILE 2>&1
            write_log "Creating fresh Conda environment..." "White"
            conda create -n $ENV_NAME python=3.11 -y >> $LOG_FILE 2>&1
        else
            write_log "Environment already exists. Using existing." "Green"
        fi
    else
        write_log "Creating Conda environment..." "White"
        conda create -n $ENV_NAME python=3.11 -y >> $LOG_FILE 2>&1
    fi
'

run_step "InstallDependencies" "Installing general dependencies" '
    conda run -n $ENV_NAME pip install plyfile tqdm colorama opencv-python joblib >> $LOG_FILE 2>&1
'

run_step "InstallTorch" "Installing PyTorch" '
    write_log "Installing PyTorch..." "White"
    conda run -n $ENV_NAME pip install $PYTORCH_CHANNEL >> $LOG_FILE 2>&1
'

run_step "CompileExtensions" "Compiling Custom CUDA Submodules" '
    if [ -n "$TORCH_CUDA_ARCH" ]; then
        export TORCH_CUDA_ARCH_LIST="$TORCH_CUDA_ARCH"
        write_log "Targeting explicit CUDA architectures: $TORCH_CUDA_ARCH_LIST" "White"
    fi
    CONDA_PYTHON="conda run -n $ENV_NAME --no-capture-output python"
    write_log "Compiling diff-gaussian-rasterization, simple-knn, fused-ssim..." "White"
    if ! $CONDA_PYTHON -m pip install ./submodules/diff-gaussian-rasterization ./submodules/simple-knn ./submodules/fused-ssim --no-build-isolation --no-cache-dir --force-reinstall --no-deps > "$COMPILE_LOG" 2>&1; then
        write_log "Compilation failed! Check compile.log." "Red"
        exit 1
    fi
'

run_step "Validate" "Validating Installation" '
    CONDA_PYTHON="conda run -n $ENV_NAME --no-capture-output python"
    if $CONDA_PYTHON -c "import diff_gaussian_rasterization, simple_knn, fused_ssim; import torch; assert torch.cuda.is_available()"; then
        write_log "\n==================================================" "Green"
        write_log " 3DGS Community Edition successfully installed!" "Green"
        write_log "==================================================" "Green"
    else
        write_log "Validation failed." "Red"
        exit 1
    fi
'

if [ "$STEP" = "All" ]; then
    GLOBAL_END=$(date +%s)
    GLOBAL_ELAPSED=$((GLOBAL_END - GLOBAL_START))
    write_log "\n--- Performance Metrics ---" "Cyan"
    write_log "Total Installation Time: $GLOBAL_ELAPSED seconds" "Cyan"
fi

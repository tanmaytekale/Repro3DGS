#!/bin/bash
# 3DGS Community Edition - Diagnostics Utility

echo -e "\e[36m==================================================\e[0m"
echo -e "\e[36m 3DGS Community Edition - Diagnostics Report\e[0m"
echo -e "\e[36m==================================================\e[0m"

echo -e "\n\e[33m[OS Information]\e[0m"
uname -a

echo -e "\n\e[33m[GPU & NVIDIA Detection]\e[0m"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi --query-gpu=name,compute_cap,driver_version --format=csv,noheader
    if nvidia-smi --query-gpu=compute_cap --format=csv,noheader | grep -q "12.0"; then
        echo -e "\e[32m>> Blackwell GPU Detected (sm_120). Requires PyTorch Nightly cu128.\e[0m"
    fi
else
    echo -e "\e[31mnvidia-smi not found! Ensure NVIDIA drivers are installed.\e[0m"
fi

if command -v nvcc &> /dev/null; then
    nvcc --version | grep "release"
else
    echo -e "\e[31mnvcc not found! Is CUDA Toolkit installed and in PATH?\e[0m"
fi

echo -e "\n\e[33m[Compiler Detection]\e[0m"
if command -v gcc &> /dev/null; then
    gcc --version | head -n 1
else
    echo -e "\e[31mgcc not found! Ensure build-essential is installed.\e[0m"
fi

if command -v g++ &> /dev/null; then
    g++ --version | head -n 1
else
    echo -e "\e[31mg++ not found! Ensure build-essential is installed.\e[0m"
fi

echo -e "\n\e[33m[Python & Conda]\e[0m"
if command -v conda &> /dev/null; then
    conda --version
    if conda env list | grep -q "3dgs_community"; then
        echo -e "\e[32m3dgs_community environment found.\e[0m"
    else
        echo -e "\e[37m3dgs_community environment not found. Run install_linux.sh first.\e[0m"
    fi
else
    echo -e "\e[31mconda not found in PATH!\e[0m"
fi

echo -e "\n\e[33m[Submodule Extension Compile Status]\e[0m"
PYTHON_CMD="conda run -n 3dgs_community python"
if command -v conda &> /dev/null && conda env list | grep -q "3dgs_community"; then
    $PYTHON_CMD -c "import torch; print(f'PyTorch {torch.__version__}')" 2>/dev/null || echo -e "\e[31mPyTorch: Not installed or environment missing.\e[0m"
    $PYTHON_CMD -c "import diff_gaussian_rasterization; print('diff_gaussian_rasterization: OK')" 2>/dev/null && echo -e "\e[32mRasterizer: Installed\e[0m" || echo -e "\e[31mRasterizer: NOT Installed\e[0m"
    $PYTHON_CMD -c "import simple_knn; print('simple_knn: OK')" 2>/dev/null && echo -e "\e[32mSimple-KNN: Installed\e[0m" || echo -e "\e[31mSimple-KNN: NOT Installed\e[0m"
    $PYTHON_CMD -c "import fused_ssim; print('fused_ssim: OK')" 2>/dev/null && echo -e "\e[32mFused-SSIM: Installed\e[0m" || echo -e "\e[31mFused-SSIM: NOT Installed\e[0m"
else
    echo -e "\e[31mCannot test extensions because environment '3dgs_community' does not exist.\e[0m"
fi

echo -e "\n\e[36m==================================================\e[0m"
echo -e "\e[36mDiagnostics Complete.\e[0m"

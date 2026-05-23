# Installation Guide

Welcome to the **3DGS Community Edition**. This fork provides a drastically simplified, automated installation process designed to be reliable across various modern hardware architectures, including RTX 50-series (Blackwell) GPUs.

## 1. Automated Installation (Recommended)

The easiest way to install 3DGS Community Edition is to use the provided automated installation scripts. These scripts will automatically detect your OS, GPU architecture, and compiler availability to ensure you get the most compatible environment.

### Windows

1. Open **Anaconda Prompt** or **Developer PowerShell**.
2. Run the Windows installation script:
   ```powershell
   .\install_windows.ps1
   ```
3. The script will:
   - Create a clean conda environment named `3dgs_community`.
   - Install the correct PyTorch version for your GPU.
   - Compile the required C++/CUDA extensions using MSVC.
   - Validate the installation.

### Linux (Ubuntu)

1. Open your terminal.
2. Run the Linux installation script:
   ```bash
   chmod +x install_linux.sh
   ./install_linux.sh
   ```
3. The script performs the same automated environment creation and extension compilation tailored for Linux.

---

## 2. Hardware Compatibility & PyTorch Strategies

We use dynamic PyTorch allocation to minimize instability while guaranteeing compatibility:

- **RTX 30-series / 40-series (Ampere/Ada):** The script automatically selects the **latest Stable PyTorch (cu124)**. This avoids the random regressions associated with nightly builds.
- **RTX 50-series (Blackwell `sm_120`):** The script automatically detects the `12.0` compute capability and gracefully upgrades your environment to the **PyTorch Nightly (cu128)** build, which is strictly required to execute instructions on Blackwell cards.

---

## 3. Manual Installation (Advanced)

If you prefer to maintain tight control over your environments, you can manually reproduce the setup.

### A. Environment Creation
```bash
conda create -n 3dgs_community python=3.11 -y
conda activate 3dgs_community
pip install plyfile tqdm colorama
```

### B. PyTorch Installation
*For standard GPUs (RTX 30/40):*
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```
*For Blackwell GPUs (RTX 50):*
```bash
pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
```

### C. Extension Compilation
The 3DGS Community Edition features runtime monkeypatching built directly into the submodules' `setup.py` scripts. You do **not** need to manually patch PyTorch internals to compile.

```bash
pip install ./submodules/diff-gaussian-rasterization ./submodules/simple-knn ./submodules/fused-ssim --no-build-isolation --no-cache-dir
```

---

## 4. Troubleshooting & Diagnostics

If your installation fails, please run the included diagnostic utilities:

- **Windows:** `.\diagnose.ps1`
- **Linux:** `./diagnose.sh`

These tools will output your compiler versions, CUDA versions, and extension availability, highlighting exactly what failed. For deeper debugging, refer to [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

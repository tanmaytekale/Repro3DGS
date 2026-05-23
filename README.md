# Repro3DGS

Repro3DGS is a deployment-focused and beginner-friendly 3D Gaussian Splatting environment that automates setup, dependency management, CUDA compatibility, diagnostics, and validation — making 3DGS reproducible and easy to run across modern GPUs, including RTX 50 / Blackwell systems.

---

## 🚀 What is Repro3DGS?
If you've ever tried to run 3D Gaussian Splatting and been met with cryptic NVCC compiler errors, PyTorch version mismatches, or silent hangs, this project is for you. We've completely overhauled the infrastructure to get you up and running without the headaches.

We provide:
* **One-Command Installation**: No more piecing together Conda environments manually.
* **Auto-Hardware Detection**: We automatically deploy the correct PyTorch binaries for your GPU (including cutting-edge Blackwell / RTX 50-series support via PyTorch Nightly).
* **Safe Compilation**: Native C++ extensions are compiled in an isolated sandbox, preventing pip from accidentally destroying your PyTorch installation.
* **Integrated Diagnostics**: A built-in verification suite and telemetry gatherer to help you troubleshoot your machine instantly.

## 💻 Supported Hardware

| Architecture Family | GPU Examples | PyTorch Target | Support Level |
| :--- | :--- | :--- | :--- |
| **Blackwell (sm_120)** | RTX 5070, 5080, 5090 | `cu128` (Nightly) | 🟢 Native |
| **Ada Lovelace (sm_89)** | RTX 4070, 4080, 4090 | `cu124` (Stable) | 🟢 Native |
| **Ampere (sm_86 / sm_80)** | RTX 3070, 3080, A100 | `cu124` (Stable) | 🟢 Native |
| **Turing (sm_75)** | RTX 2070, 2080, T4 | `cu124` (Stable) | 🟢 Native |
| **Older** | GTX 1080 | `cu124` (Stable) | 🟡 Fallback |

---

## ⚡ Quick Start

### 1. Install
Ensure you have [Miniconda](https://docs.conda.io/en/latest/miniconda.html) installed. Open your terminal (PowerShell for Windows) and run:

**Windows:**
```powershell
.\scripts\install_windows.ps1
```

**Linux:**
```bash
./scripts/install_linux.sh
```
> **Expectations**: The installation takes roughly **3–5 minutes**. Large PyTorch binaries (~2.7GB) will be downloaded depending on your internet speed.

### 2. Verify Your Installation
Want to make sure your CUDA compilers actually worked? We include a mini-train loop that will process 10 sample frames and run a real backpropagation test on your GPU.

```powershell
.\diagnostics\verify_install.ps1 -RunMiniTrain
```
If you see **"Mini-Train Validation: SUCCESS"**, your system is 100% ready.

---

## 🎓 Train Your First Scene

Most users fail because their dataset isn't structured correctly. We've included an `example_dataset` skeleton in the `data/` folder to guide you.

1. **Take 50-200 photos** of a static object or scene. Video frames work too!
2. Place your raw `.jpg` or `.png` images into `data/example_dataset/input/`.
3. Open a terminal, activate your environment, and process your images using COLMAP (if you don't have COLMAP, run `.\scripts\download_colmap.ps1` first):
```powershell
conda activate 3dgs_community
python convert.py -s data/example_dataset
```
4. **Train the 3D Gaussians!**
```powershell
python train.py -s data/example_dataset
```
> **Expectations**: Training requires at least 8GB of VRAM (preferably 12GB+ for high resolution). 7,000 iterations takes about 5 minutes; 30,000 takes about 15-20 minutes on modern cards.

---

## 👁️ Open Viewer

To view your trained scene in real-time, you need the interactive SIBR Viewer.
If you haven't downloaded it yet, use our automated script:

```powershell
.\scripts\download_viewer.ps1
```

Then, launch the viewer pointing to your training output (which defaults to the `output/` folder generated in the root directory):
```powershell
.\SIBR_viewers\bin\SIBR_gaussianViewer_app -m .\output\<your_scene_hash>
```

---

## 🛠️ Troubleshooting & Diagnostics

If your installation failed, don't panic. Look at the error message printed to the console. 

**Common Fixes:**
* **"Visual Studio Build Tools not found"**: You must install [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio). Ensure you select the **Desktop development with C++** workload. Then rerun the installer with `-Step CompileExtensions`.
* **Conda command not found**: You need to install Miniconda and ensure it is added to your PATH.

**Reporting an Issue**
If you are still stuck, generate a debug bundle before opening a GitHub Issue. This script securely gathers your install logs, compiler errors, and GPU configuration:
```powershell
.\diagnostics\collect_debug_bundle.ps1
```
Upload the resulting `debug_bundle.zip` to your issue.

---

## ⚙️ Advanced Usage

For developers looking to integrate 3DGS into larger pipelines, our installers support specific phase execution and debugging.

```powershell
# Force reinstall PyTorch only
.\scripts\install_windows.ps1 -Step InstallTorch -Force

# Force a clean slate (deletes the conda environment first)
.\scripts\install_windows.ps1 -RecreateEnv

# Recompile C++ extensions (useful if you changed CUDA versions)
.\scripts\install_windows.ps1 -Step CompileExtensions
```

### About This Project
This is an independent, community-driven deployment layer designed for enterprise and consumer use. If you use this software in research, please cite the original [3D Gaussian Splatting for Real-Time Radiance Field Rendering](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/) paper by Kerbl, Kopanas, Leimkühler, and Drettakis.

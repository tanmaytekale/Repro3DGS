# Troubleshooting Guide

This guide addresses the most common issues users face when trying to install or run 3D Gaussian Splatting locally.

## First Step: Run Diagnostics

Before trying to debug manually, run our automated diagnostic tool:
- **Windows:** `.\diagnose.ps1`
- **Linux:** `./diagnose.sh`

The output will usually immediately identify if your compiler is missing, if PyTorch failed to install, or if your CUDA extensions didn't compile.

---

## Common Issues & Fixes

### 1. `RuntimeError: CUDA error: no kernel image is available for execution on the device`
This occurs when the PyTorch version installed does not support your GPU architecture.
- **Cause:** Usually affects RTX 50-series (Blackwell) users attempting to run Stable PyTorch `cu124`. 
- **Fix:** Ensure you are using PyTorch Nightly `cu128`. The automated `install_windows.ps1` script detects your GPU and handles this automatically.

### 2. `cl.exe: Command not found` or `vcvars64.bat not found` (Windows)
The C++ extensions require the Microsoft Visual C++ compiler to build.
- **Cause:** Visual Studio Build Tools are not installed, or the "Desktop development with C++" workload was not selected during installation.
- **Fix:** Download the [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/), run the installer, and check the box for **Desktop development with C++**. Then re-run the install script.

### 3. SIBR Viewer: `cudart64_12.dll was not found`
When launching the interactive viewer, a system error appears regarding a missing CUDA runtime.
- **Cause:** The viewer is looking for the CUDA 12 runtime globally, but your system only has it isolated inside the conda environment.
- **Fix:** Our automated setup script automatically copies this file to the `SIBR_viewers/bin` folder. If you installed manually, you must locate `cudart64_12.dll` in your `miniconda3/envs/3dgs_community/Lib/site-packages/torch/lib` directory and copy it directly to the viewer's bin directory.

### 4. Compilation Failures during `pip install ./submodules/...`
If the terminal fills with red error messages during submodule installation:
- **Cause:** Often caused by stale build caches or minor compiler mismatches.
- **Fix:** Try clearing your pip cache and forcing a rebuild:
  ```bash
  pip cache purge
  pip install ./submodules/diff-gaussian-rasterization --no-build-isolation --no-cache-dir --force-reinstall
  ```

### 5. `ModuleNotFoundError: No module named 'diff_gaussian_rasterization'`
This indicates the extension compilation failed silently or was skipped.
- **Fix:** Run the `diagnose.ps1` script to verify your compiler. If the compiler is present, follow the "Compilation Failures" fix above to force a rebuild.

---

## Known Limitations
- **VR/OpenXR:** Requires the specific `gaussian_code_release_openxr` branch (not maintained in the primary Community Edition default branch).
- **VRAM Usage:** Training at full resolution requires significant VRAM (often >12GB). Lower resolution settings via `-r 2` or `-r 4` in `train.py` can mitigate memory out-of-bounds errors on smaller cards.

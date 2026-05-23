# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-05-23

### Added
- **Hardware Abstraction Layer**: Installer now automatically detects GPU architecture using `nvidia-smi` and resolves the correct PyTorch wheels (Stable vs Nightly).
- **Blackwell Support**: Native support for RTX 50-series (sm_120) architectures via PyTorch nightly (`cu128`).
- **One-Command Installation**: Consolidated all setup processes into `scripts/install_windows.ps1` and `scripts/install_linux.sh`.
- **Validation Suite**: Included `diagnostics/verify_install.ps1` for local mini-training loops to validate CUDA and compiler interactions.
- **Diagnostics**: Added `diagnostics/collect_debug_bundle.ps1` for easy GitHub issue reporting and telemetry.
- **Binary Downloader**: Removed massive binaries (COLMAP/SIBR) from the git tree; added automated download scripts (`scripts/download_viewer.ps1` and `scripts/download_colmap.ps1`).
- **Human-Readable Errors**: Enhanced compiler failure catching to instruct users on missing MSVC tools directly.

### Fixed
- Fixed the infamous "pip override bug" where compiling CUDA submodules downgraded or corrupted the conda PyTorch installation.
- Fixed infinite hangs during MSVC location and wheel compilation by introducing `Invoke-SafeCommand` with stream redirection and timeouts.

# Contributing to 3DGS Community Edition

First off, thank you for considering contributing to 3DGS Community Edition! Our goal is to maintain a robust, deployment-ready infrastructure for Gaussian Splatting. 

## How Can I Contribute?

### Reporting Bugs
If you encounter a bug, please use the included diagnostic script before opening an issue:
1. Run `.\diagnostics\collect_debug_bundle.ps1`
2. Attach the generated `debug_bundle.zip` to your GitHub issue.
3. Provide details about your hardware setup and what you were trying to achieve.

### Suggesting Enhancements
We welcome ideas for new features, GUI wrappers, containerization (Docker), or cloud-deployment templates. Please open a discussion or issue outlining your proposal.

### Pull Requests
1. **Fork the repository** and create your branch from `main`.
2. **Keep the installer idempotent**: If you modify `install_windows.ps1` or `install_linux.sh`, ensure that running it twice in a row does not break the environment.
3. **No Large Binaries**: Do not commit datasets, precompiled viewers, or heavy DLLs. If a new binary dependency is required, write a `download_<tool>.ps1` script to fetch it dynamically.
4. **Update Documentation**: Update the `README.md` and `CHANGELOG.md` with your changes.

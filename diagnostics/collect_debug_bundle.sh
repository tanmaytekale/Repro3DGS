#!/bin/bash

BUNDLE_DIR="debug_bundle"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

echo -e "\e[36mCollecting 3DGS Debug Bundle...\e[0m"

# 1. Collect Logs
for log in "install.log" "compile.log" "diagnostics.log"; do
    if [ -f "$log" ]; then
        cp "$log" "$BUNDLE_DIR/"
        echo " Copied $log"
    else
        echo -e "\e[33m Missing $log\e[0m"
    fi
done

# 2. Collect System Info
SYS_INFO="$BUNDLE_DIR/system_info.txt"
echo "--- OS Info ---" > "$SYS_INFO"
uname -a >> "$SYS_INFO"

echo "--- GPU Info ---" >> "$SYS_INFO"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi >> "$SYS_INFO"
else
    echo "nvidia-smi not found" >> "$SYS_INFO"
fi
echo " Copied system info"

# 3. Collect Conda Environment Info
ENV_NAME="3dgs_community"
if conda env list | grep -q "\b$ENV_NAME\b"; then
    echo " Exporting conda environment..."
    conda env export -n $ENV_NAME > "$BUNDLE_DIR/conda_env.yml"
    
    echo " Exporting pip freeze..."
    conda run -n $ENV_NAME --no-capture-output pip freeze > "$BUNDLE_DIR/pip_freeze.txt"
else
    echo -e "\e[33m Environment $ENV_NAME not found. Skipping env export.\e[0m"
fi

# 4. Zip the bundle
ZIP_PATH="debug_bundle.zip"
rm -f "$ZIP_PATH"
if command -v zip &> /dev/null; then
    zip -r "$ZIP_PATH" "$BUNDLE_DIR" > /dev/null
    rm -rf "$BUNDLE_DIR"
    echo -e "\n\e[32mDebug bundle created at: $ZIP_PATH\e[0m"
    echo -e "\e[36mPlease attach this file when opening a GitHub issue.\e[0m"
else
    echo -e "\e[31m'zip' command not found. Logs are stored in the $BUNDLE_DIR directory.\e[0m"
fi

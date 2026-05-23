#!/bin/bash

RUN_MINI_TRAIN=0
for arg in "$@"; do
    case $arg in
        --RunMiniTrain|-RunMiniTrain) RUN_MINI_TRAIN=1 ;;
    esac
done

ENV_NAME="3dgs_community"
PYTHON_CMD="conda run -n $ENV_NAME --no-capture-output python"

echo -e "\n\e[36m==================================================\e[0m"
echo -e "\e[36m 3DGS Verification Summary\e[0m"
echo -e "\e[36m==================================================\e[0m"

# Check Python/Torch
cat << 'EOF' > .verify_torch.py
import torch
import sys
print(f'Python Version: {sys.version.split()[0]}')
print(f'Torch Version: {torch.__version__}')
cuda_avail = torch.cuda.is_available()
print(f'CUDA Available: {cuda_avail}')
if cuda_avail:
    print(f'GPU Detected: {torch.cuda.get_device_name(0)}')
EOF

$PYTHON_CMD .verify_torch.py
rm .verify_torch.py

# Check Extensions
cat << 'EOF' > .verify_ext.py
try:
    import diff_gaussian_rasterization
    import simple_knn
    import fused_ssim
    print('Extensions: COMPILED & IMPORTED SUCCESSFULLY')
except Exception as e:
    print(f'Extensions: FAILED TO IMPORT ({e})')
EOF

EXT_OUT=$($PYTHON_CMD .verify_ext.py)
if echo "$EXT_OUT" | grep -q "SUCCESSFULLY"; then
    echo -e "\e[32m$EXT_OUT\e[0m"
else
    echo -e "\e[31m$EXT_OUT\e[0m"
fi
rm .verify_ext.py

# Check SIBR Viewer (assuming linux version is built/downloaded differently but path exists)
VIEWER_PATH="SIBR_viewers/install/bin/SIBR_gaussianViewer_app"
if [ -f "$VIEWER_PATH" ]; then
    echo -e "\e[32mSIBR Viewer: FOUND\e[0m"
else
    echo -e "\e[31mSIBR Viewer: NOT FOUND (You may need to compile it for Linux)\e[0m"
fi

if [ "$RUN_MINI_TRAIN" -eq 1 ]; then
    echo -e "\n\e[36m==================================================\e[0m"
    echo -e "\e[36m Running Mini-Train Validation\e[0m"
    echo -e "\e[36m==================================================\e[0m"
    
    TEST_DIR=".temp_dataset"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/input"
    
    # Try finding images
    if [ -d "data/input" ]; then
        find data/input -maxdepth 1 -name "*.jpg" | head -n 10 | xargs -I {} cp {} "$TEST_DIR/input/"
        
        IMG_COUNT=$(ls -1 "$TEST_DIR/input" 2>/dev/null | wc -l)
        if [ "$IMG_COUNT" -gt 0 ]; then
            echo -e "\e[33mRunning COLMAP convert.py on $IMG_COUNT frames...\e[0m"
            export PATH="$PWD/colmap:$PATH"
            $PYTHON_CMD convert.py -s $TEST_DIR
            
            if [ -f "$TEST_DIR/sparse/0/cameras.bin" ] || [ -f "$TEST_DIR/sparse/0/cameras.txt" ]; then
                echo -e "\e[32mCOLMAP conversion successful.\e[0m"
                echo -e "\e[33mRunning 10 iterations of train.py...\e[0m"
                
                $PYTHON_CMD train.py -s $TEST_DIR --iterations 10 -m "$TEST_DIR/output" --save_iterations 10
                
                if [ -f "$TEST_DIR/output/point_cloud/iteration_10/point_cloud.ply" ]; then
                    echo -e "\e[32mMini-Train Validation: SUCCESS (Point cloud checkpoint generated)\e[0m"
                else
                    echo -e "\e[31mMini-Train Validation: FAILED (No checkpoints found)\e[0m"
                fi
            else
                echo -e "\e[31mCOLMAP conversion failed. Skipping train.py.\e[0m"
            fi
        else
            echo -e "\e[33mNo images copied to .temp_dataset/input.\e[0m"
        fi
    else
        echo -e "\e[33mNo data/input directory found. Cannot run Mini-Train.\e[0m"
    fi
fi
echo -e "\e[36m==================================================\n\e[0m"

#!/bin/bash
set -e

echo "Installing intel-gpu-tools for intel_gpu_top..."
sudo apt update && sudo apt install -y intel-gpu-tools
echo "intel-gpu-tools installation complete."

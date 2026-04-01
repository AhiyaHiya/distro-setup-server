#!/bin/bash
set -e

readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"

cd /tmp
git clone git@github.com:trapexit/mergerfs-tools.git

cd mergerfs-tools
sudo make install

echo "mergerfs-tools installed successfully"
cd "$SCRIPT_DIR"

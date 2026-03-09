#!/bin/bash
echo "RAM Info:"
free -h | grep -E 'Mem|Swap'
echo ""
echo "Detailed RAM Modules:"
sudo dmidecode --type memory | grep -E 'Size|Type|Speed|Locator'

#!/bin/bash
echo "Storage Overview:"
df -h | grep -E '^/dev|Filesystem'
echo ""
echo "Block Devices (Name, Size, Type, Model, Transport):"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL,TRAN
echo ""
echo "SMART Drive Health (SSD/HDD Detection):"
for dev in $(lsblk -dno NAME | grep '^sd'); do
    echo "Drive /dev/$dev:"
    sudo smartctl -i /dev/$dev | grep -E 'Model|Serial|Rotation|Solid State'
done

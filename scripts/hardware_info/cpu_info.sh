#!/bin/bash
echo "CPU Info:"
lscpu | grep -E 'Model name|Socket|Core|Thread|MHz'

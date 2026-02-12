#!/bin/bash

pipx install yt-dlp==2025.10.14 --dry-run
pipx install yt-dlp==2025.10.14
yt-dlp --version

# For challenge questions, DENO has to be installed too
curl -fsSL https://deno.land/install.sh | sh


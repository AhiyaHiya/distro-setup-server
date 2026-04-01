#!/bin/bash

# pipx install yt-dlp==2026.02.04 --dry-run
pipx install yt-dlp==2026.02.04
yt-dlp --version

# For challenge questions, DENO has to be installed too
curl -fsSL https://deno.land/install.sh | sh


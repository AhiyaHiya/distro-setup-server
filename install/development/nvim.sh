#!/usr/bin/env bash
set -euo pipefail

echo "Setting up Neovim + perfect Bash auto-formatting on Pop!_OS..."

# 1. Update package list and install the three tools we need
sudo apt update
sudo apt install -y neovim shfmt npm

# 2. Install bash-language-server globally via npm
if ! command -v bash-language-server &>/dev/null; then
    echo "Installing bash-language-server..."
    sudo npm install -g bash-language-server
fi

# 3. Create a minimal but perfect Neovim config for Bash
mkdir -p ~/.config/nvim

cat > ~/.config/nvim/init.lua <<'EOF'
vim.g.mapleader = " "

-- Bootstrap lazy.nvim (plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Auto-format Bash with shfmt on every save
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = { sh = { "shfmt" } },
      format_on_save = { timeout_ms = 500, lsp_fallback = true },
    },
  },
})

-- Nice defaults for shell scripts
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
EOF

echo ""
echo "Done! Neovim is ready."
echo ""
echo "From now on, every time you edit a .sh file with"
echo "    nvim myscript.sh"
echo "it will automatically format the file perfectly with shfmt when you save."
echo ""
echo "Enjoy never fixing Bash indentation again!"


-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.completeopt = { "noinsert", "menuone", "noselect" }
vim.opt.cursorline = true
vim.opt.hidden = true
vim.opt.autoindent = true
vim.opt.inccommand = "split"
vim.opt.mouse = "a"
vim.opt.number = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.title = true
vim.opt.wildmenu = true
vim.opt.spell = true
vim.opt.ttyfast = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.wrap = true
vim.opt.showmode = false
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.syntax = "on"
vim.opt.wildoptions:append("pum")

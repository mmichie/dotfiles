-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic Options ------------------------------------------------------
-- Set leaders before lazy setup
vim.g.mapleader = ","
vim.g.maplocalleader = ","

-- General settings
vim.opt.compatible = false
vim.opt.encoding = 'utf-8'
vim.opt.modelines = 0
vim.opt.autoindent = true
vim.opt.showmode = true
vim.opt.showcmd = true
vim.opt.hidden = true
vim.opt.visualbell = true
vim.opt.cursorline = true
vim.opt.ttyfast = true
vim.opt.ruler = true
vim.opt.backspace = 'indent,eol,start'
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.laststatus = 2
vim.opt.history = 1000
vim.opt.undofile = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.autowrite = true
vim.opt.autoread = true
vim.opt.title = true
vim.opt.titlestring = 'NVIM: %F'
vim.opt.termguicolors = true

-- Indentation and Formatting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.wrap = true
vim.opt.textwidth = 80
vim.opt.formatoptions = 'qrn1'

-- Search Settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.showmatch = true
vim.opt.hlsearch = true
vim.opt.gdefault = true

-- File Management
local function ensure_dir(path)
    local ok, err = vim.loop.fs_stat(path)
    if not ok then
        vim.loop.fs_mkdir(path, 511)  -- 511 = 0777 in octal
    end
end

local nvim_data = vim.fn.stdpath('data')
local backup_dir = nvim_data .. '/backup'
local undo_dir = nvim_data .. '/undo'
local swap_dir = nvim_data .. '/swap'

ensure_dir(backup_dir)
ensure_dir(undo_dir)
ensure_dir(swap_dir)

vim.opt.undodir = undo_dir
vim.opt.backupdir = backup_dir
vim.opt.directory = swap_dir
vim.opt.backup = true

-- Basic Key Mappings (non-plugin related) ----------------------------------------------------
-- Window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { silent = true })
vim.keymap.set('n', '<C-j>', '<C-w>j', { silent = true })
vim.keymap.set('n', '<C-k>', '<C-w>k', { silent = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { silent = true })

-- Tab management
vim.keymap.set('n', '<leader>tt', ':tabnew<CR>', { silent = true })
vim.keymap.set('n', '<leader>tc', ':tabclose<CR>', { silent = true })
vim.keymap.set('n', '<leader>tn', ':tabnext<CR>', { silent = true })
vim.keymap.set('n', '<leader>tp', ':tabprevious<CR>', { silent = true })

-- Clear search highlighting
vim.keymap.set('n', '<leader><Space>', ':nohlsearch<CR>', { silent = true })

-- Basic Autocommands ---------------------------------------------------
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Git commit settings
local gitcommit = augroup('gitcommit_settings', { clear = true })
autocmd('FileType', {
    group = gitcommit,
    pattern = 'gitcommit',
    command = 'setlocal textwidth=100'
})

-- Python settings
local python = augroup('ft_python', { clear = true })
autocmd('FileType', {
    group = python,
    pattern = 'python',
    callback = function()
        vim.opt_local.expandtab = true
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.define = [[^\s*\(def\|class\)]]
    end
})

-- Trim trailing whitespace on save
local trim_whitespace = augroup('trim_whitespace', { clear = true })
autocmd('BufWritePre', {
    group = trim_whitespace,
    pattern = '*',
    callback = function()
        local save_cursor = vim.fn.getpos(".")
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setpos(".", save_cursor)
    end
})

-- Git commit message settings
autocmd('FileType', {
    pattern = 'gitcommit',
    callback = function()
        -- Set cursor to the top
        vim.cmd('normal! gg')
        -- Set text width for git commits
        vim.opt_local.textwidth = 100
    end
})

-- Remember cursor position (but not for git commits)
autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        if vim.bo.filetype ~= 'gitcommit'
            and vim.fn.line("'\"") > 0
            and vim.fn.line("'\"") <= vim.fn.line("$") then
                vim.fn.setpos(".", vim.fn.getpos("'\""))
                vim.cmd('normal! zz')
        end
    end
})

-- Load plugins
require("lazy").setup("plugins")

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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
vim.opt.modelines = 0
vim.opt.showmode = true
vim.opt.showcmd = true
vim.opt.hidden = true
vim.opt.visualbell = true
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.history = 1000
vim.opt.undofile = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.autowrite = true
vim.opt.autoread = true
vim.opt.title = false
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
vim.opt.showmatch = true
vim.opt.gdefault = true

-- File Management
local function ensure_dir(path)
    local ok, err = vim.uv.fs_stat(path)
    if not ok then
        vim.uv.fs_mkdir(path, 511)  -- 511 = 0777 in octal
    end
end

local nvim_data = vim.fn.stdpath('data')
local backup_dir = nvim_data .. '/backup'
local undo_dir = nvim_data .. '/undo'
local swap_dir = nvim_data .. '/swap'

ensure_dir(backup_dir)
ensure_dir(undo_dir)
ensure_dir(swap_dir)

-- Enhanced swap file configuration
vim.opt.directory = swap_dir .. '//'  -- Double slash keeps full path
vim.opt.backup = true
vim.opt.backupdir = backup_dir
vim.opt.undodir = undo_dir
vim.opt.swapfile = true
vim.opt.updatetime = 300  -- Faster swap file writing

-- Automatically handle swap files
vim.api.nvim_create_autocmd("SwapExists", {
    pattern = "*",
    callback = function()
        local swap_file = vim.v.swapname
        local modification_time = vim.fn.getftime(swap_file)
        local current_time = os.time()
        -- Delete swap files older than 1 day
        if current_time - modification_time > 86400 then
            vim.fn.delete(swap_file)
            vim.cmd("edit")
        end
    end
})

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
    callback = function()
        vim.opt_local.textwidth = 100
        vim.cmd('normal! gg')
    end
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

-- Format Go files on save
local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
   require('go.format').goimports()
  end,
  group = format_sync_grp,
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
require("lazy").setup("plugins", {
    install = { colorscheme = { "nord" } },
})

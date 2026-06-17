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
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.undofile = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.autowrite = true
vim.opt.termguicolors = true

-- Indentation and Formatting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.wrap = true
vim.opt.textwidth = 80
vim.opt.formatoptions = "qrn1"

-- Search Settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.showmatch = true

-- File Management
local function ensure_dir(path)
    local ok, err = vim.uv.fs_stat(path)
    if not ok then
        -- 448 = 0700: undo files replay edited file contents — never
        -- world-readable.
        vim.uv.fs_mkdir(path, 448)
    end
end

local nvim_data = vim.fn.stdpath("data")
local undo_dir = nvim_data .. "/undo"
local swap_dir = nvim_data .. "/swap"

ensure_dir(undo_dir)
ensure_dir(swap_dir)

vim.opt.directory = swap_dir .. "//" -- Double slash keeps full path
vim.opt.undodir = undo_dir
vim.opt.swapfile = true
vim.opt.updatetime = 300

-- Basic Key Mappings (non-plugin related) ----------------------------------------------------
-- Window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true, desc = "Go to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true, desc = "Go to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true, desc = "Go to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true, desc = "Go to right window" })

-- Tab management
vim.keymap.set("n", "<leader>tt", ":tabnew<CR>", { silent = true, desc = "New tab" })
vim.keymap.set("n", "<leader>tc", ":tabclose<CR>", { silent = true, desc = "Close tab" })
vim.keymap.set("n", "<leader>tn", ":tabnext<CR>", { silent = true, desc = "Next tab" })
vim.keymap.set("n", "<leader>tp", ":tabprevious<CR>", { silent = true, desc = "Previous tab" })

-- Clear search highlighting
vim.keymap.set("n", "<leader><Space>", ":nohlsearch<CR>", { silent = true, desc = "Clear search highlight" })

-- Basic Autocommands ---------------------------------------------------
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Git commit settings
local gitcommit = augroup("gitcommit_settings", { clear = true })
autocmd("FileType", {
    group = gitcommit,
    pattern = "gitcommit",
    callback = function()
        vim.opt_local.textwidth = 100
        vim.cmd("normal! gg")
    end,
})

-- Python settings
local python = augroup("ft_python", { clear = true })
autocmd("FileType", {
    group = python,
    pattern = "python",
    callback = function()
        vim.opt_local.expandtab = true
        vim.opt_local.shiftwidth = 4
        vim.opt_local.tabstop = 4
        vim.opt_local.softtabstop = 4
        vim.opt_local.define = [[^\s*\(def\|class\)]]
    end,
})

-- Trim trailing whitespace on save. Skip filetypes where trailing spaces
-- are meaningful: markdown two-space hard breaks, diff/patch context lines.
local trim_exclude = { markdown = true, diff = true, gitsendemail = true }
local trim_whitespace = augroup("trim_whitespace", { clear = true })
autocmd("BufWritePre", {
    group = trim_whitespace,
    pattern = "*",
    callback = function()
        if trim_exclude[vim.bo.filetype] then return end
        local save_cursor = vim.fn.getpos(".")
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setpos(".", save_cursor)
    end,
})

-- Format Go files on save. Wrapped in pcall so a goimports failure
-- (syntax error, missing binary) surfaces a warning instead of
-- aborting the write.
local go_format = augroup("go_format", { clear = true })
autocmd("BufWritePre", {
    group = go_format,
    pattern = "*.go",
    callback = function()
        local ok, err = pcall(function()
            require("go.format").goimports()
        end)
        if not ok then vim.notify("goimports failed: " .. tostring(err), vim.log.levels.WARN) end
    end,
})

-- Diagnostic signs (set eagerly — this used to live inside neo-tree's
-- lazy config and only applied after the first <leader>e).
vim.diagnostic.config({
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = " ",
            [vim.diagnostic.severity.HINT] = "󰌵",
        },
    },
})

-- Remember cursor position (but not for git commits)
autocmd("BufReadPost", {
    group = augroup("cursor_restore", { clear = true }),
    pattern = "*",
    callback = function()
        if vim.bo.filetype ~= "gitcommit" and vim.fn.line("'\"") > 0 and vim.fn.line("'\"") <= vim.fn.line("$") then
            vim.fn.setpos(".", vim.fn.getpos("'\""))
            vim.cmd("normal! zz")
        end
    end,
})

-- Load plugins
require("lazy").setup("plugins", {
    install = { colorscheme = { "nord" } },
})

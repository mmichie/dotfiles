return {
    -- Plugin Manager
    {
        "folke/lazy.nvim",
        tag = "stable"
    },

    -- Color scheme
    {
        "gbprod/nord.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("nord").setup({})
            vim.cmd.colorscheme("nord")
        end,
    },

    -- Status line
    {
        'nvim-lualine/lualine.nvim',
        dependencies = { 'nvim-tree/nvim-web-devicons' },
        config = function()
            require('lualine').setup({
                options = {
                    theme = 'nord',
                    component_separators = '|',
                    section_separators = { left = '', right = '' },
                },
                sections = {
                    lualine_a = {'mode'},
                    lualine_b = {'branch', 'diff', 'diagnostics'},
                    lualine_c = {'filename'},
                    lualine_x = {'encoding', 'fileformat', 'filetype'},
                    lualine_y = {'progress'},
                    lualine_z = {'location'}
                },
            })
        end,
    },

    -- Syntax highlighting
    {
        'nvim-treesitter/nvim-treesitter',
        -- Pin the master branch. Upstream made `main` (the rewrite) the default
        -- branch, and main removes nvim-treesitter.configs. Without this pin,
        -- `:Lazy update` tracks the default branch and drifts onto main, which
        -- breaks the configs.setup() call below. The exact commit is held in
        -- lazy-lock.json; `:Lazy restore` pins it back.
        branch = "master",
        build = ':TSUpdate',
        config = function()
            -- master branch: the entrypoint is nvim-treesitter.configs, and
            -- highlighting must be enabled explicitly. The old
            -- require('nvim-treesitter').setup({...}) call was silently
            -- ignored — no treesitter highlighting at all for filetypes
            -- nvim does not cover by default.
            require('nvim-treesitter.configs').setup({
                ensure_installed = {
                    "lua", "vim", "vimdoc", "query",
                    "go", "gomod", "gosum", "gowork",
                    "python",
                    "bash",
                    "json", "yaml", "toml",
                    "markdown", "markdown_inline",
                    "nix",
                    "diff", "gitcommit", "gitignore",
                },
                auto_install = true,
                highlight = { enable = true },
            })
        end,
    },

    -- LSP Support
    {
        'neovim/nvim-lspconfig',
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            'hrsh7th/nvim-cmp',
            'hrsh7th/cmp-nvim-lsp',
            'L3MON4D3/LuaSnip',
        },
        config = function()
            -- LSP keymaps on attach
            vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(args)
                    local function map(lhs, rhs, desc)
                        vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = 'LSP: ' .. desc })
                    end
                    map('gd', vim.lsp.buf.definition, 'Go to definition')
                    map('K', vim.lsp.buf.hover, 'Hover documentation')
                    map('<leader>rn', vim.lsp.buf.rename, 'Rename symbol')
                    map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
                    map('gr', vim.lsp.buf.references, 'List references')
                    map('<leader>f', function()
                        vim.lsp.buf.format({ async = true })
                    end, 'Format buffer')
                end,
            })

            -- Add cmp-nvim-lsp capabilities
            local capabilities = require('cmp_nvim_lsp').default_capabilities()

            -- Configure LSP servers
            vim.lsp.config('pyright', { capabilities = capabilities })
            vim.lsp.config('gopls', {
                capabilities = capabilities,
                settings = {
                    gopls = {
                        gofumpt = true,
                        analyses = {
                            nilness = true,
                            shadow = true,
                            unusedparams = true,
                            unusedwrite = true,
                        },
                        staticcheck = true,
                        usePlaceholders = true,
                        hints = {
                            assignVariableTypes = true,
                            compositeLiteralFields = true,
                            compositeLiteralTypes = true,
                            constantValues = true,
                            functionTypeParameters = true,
                            parameterNames = true,
                            rangeVariableTypes = true,
                        },
                    },
                },
            })
            vim.lsp.enable({ 'pyright', 'gopls' })

            -- Completion setup
            local cmp = require('cmp')
            local luasnip = require('luasnip')
            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                    ['<C-n>'] = cmp.mapping.select_next_item(),
                    ['<C-p>'] = cmp.mapping.select_prev_item(),
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                }),
            })
        end
    },

    -- File explorer
    {
        "nvim-neo-tree/neo-tree.nvim",
        branch = "v3.x",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
            "MunifTanjim/nui.nvim",
        },
        keys = {
            { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Toggle Neo-tree" },
            { "\\", "<cmd>Neotree reveal<CR>", desc = "Reveal in Neo-tree" },
        },
        config = function()
            require("neo-tree").setup({
                close_if_last_window = false,
                popup_border_style = "rounded",
                enable_git_status = true,
                enable_diagnostics = true,
                filesystem = {
                    filtered_items = {
                        visible = false,
                        hide_dotfiles = false,
                        hide_gitignored = true,
                        hide_hidden = false,
                    },
                    follow_current_file = {
                        enabled = true,
                        leave_dirs_open = false,
                    },
                    group_empty_dirs = false,
                    hijack_netrw_behavior = "open_current",
                    use_libuv_file_watcher = true,
                },
                window = {
                    position = "left",
                    width = 40,
                    mapping_options = {
                        noremap = true,
                        nowait = true,
                    },
                    mappings = {
                        ["<space>"] = {
                            "toggle_node",
                            nowait = false,
                        },
                        ["<2-LeftMouse>"] = "open",
                        ["<cr>"] = "open",
                        ["<esc>"] = "cancel",
                        ["P"] = { "toggle_preview", config = { use_float = true } },
                        ["l"] = "focus_preview",
                        ["S"] = "open_split",
                        ["s"] = "open_vsplit",
                        ["t"] = "open_tabnew",
                        ["w"] = "open_with_window_picker",
                        ["C"] = "close_node",
                        ["z"] = "close_all_nodes",
                        ["H"] = "toggle_hidden",
                        ["a"] = "add",
                        ["A"] = "add_directory",
                        ["d"] = "delete",
                        ["r"] = "rename",
                        ["y"] = "copy_to_clipboard",
                        ["x"] = "cut_to_clipboard",
                        ["p"] = "paste_from_clipboard",
                        ["c"] = "copy",
                        ["m"] = "move",
                        ["q"] = "close_window",
                        ["R"] = "refresh",
                    }
                },
            })
        end
    },

    -- Fuzzy finder
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        dependencies = { 'nvim-lua/plenary.nvim' },
        keys = {
            { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
            { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
            { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
            { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
        },
    },

    -- Git integration
    {
        'lewis6991/gitsigns.nvim',
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require('gitsigns').setup()
        end
    },

    -- Go Development
    {
        "ray-x/go.nvim",
        dependencies = {
            "ray-x/guihua.lua",
            "neovim/nvim-lspconfig",
            "nvim-treesitter/nvim-treesitter",
        },
        config = function()
            require("go").setup({
                go = 'go',
                gofmt = 'gofumpt',
                tag_transform = false,
                test_template = '',
                test_template_dir = '',
                comment_placeholder = '',
                icons = { breakpoint = '🧘', currentpos = '🏃' },
                verbose = false,
                lsp_cfg = false, -- gopls managed by native vim.lsp.config
                lsp_gofumpt = false,
                lsp_on_attach = false,
            })
        end,
        event = {"CmdlineEnter"},
        ft = {"go", 'gomod'},
        build = ':lua require("go.install").update_all_sync()'
    },

    -- Copilot
    {
        "zbirenbaum/copilot.lua",
        cmd = "Copilot",
        event = "InsertEnter",
        config = function()
            require("copilot").setup({
                panel = {
                    enabled = true,
                    auto_refresh = true,
                    keymap = {
                        jump_prev = "[[",
                        jump_next = "]]",
                        accept = "<CR>",
                        refresh = "gr",
                        open = "<M-CR>"
                    },
                },
                suggestion = {
                    enabled = true,
                    auto_trigger = true,
                    debounce = 75,
                    keymap = {
                        accept = "<M-j>",
                        accept_word = "<M-w>",
                        accept_line = "<M-l>",
                        next = "<M-]>",
                        prev = "<M-[>",
                        dismiss = "<C-]>",
                    },
                },
                filetypes = {
                    yaml = true,
                    markdown = true,
                    help = false,
                    gitcommit = false,
                    gitrebase = false,
                    ["."] = false,
                },
            })

            -- Add a smarter Tab handling function
            local function smart_tab()
                if require("copilot.suggestion").is_visible() then
                    require("copilot.suggestion").accept()
                else
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
                end
            end

            -- Map Tab to the smart function
            vim.keymap.set("i", "<Tab>", smart_tab, { expr = false, silent = true, desc = "Accept Copilot suggestion or insert Tab" })
        end,
    },

}

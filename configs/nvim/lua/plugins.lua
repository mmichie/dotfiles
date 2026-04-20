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

    -- Enhanced Tab Management
    {
        "akinsho/bufferline.nvim",
        dependencies = "nvim-tree/nvim-web-devicons",
        config = function()
            require("bufferline").setup({
                options = {
                    mode = "tabs",
                    separator_style = "slant",
                    always_show_bufferline = true,
                    show_buffer_close_icons = true,
                    show_close_icon = true,
                    color_icons = true
                }
            })
            -- Keymaps for tab navigation
            vim.keymap.set('n', '<S-l>', ':BufferLineCycleNext<CR>')
            vim.keymap.set('n', '<S-h>', ':BufferLineCyclePrev<CR>')
        end
    },

    -- Syntax highlighting
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        config = function()
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
                indent = { enable = true },
            })
        end,
    },

    -- LSP Support
    {
        'neovim/nvim-lspconfig',
        dependencies = {
            'hrsh7th/nvim-cmp',
            'hrsh7th/cmp-nvim-lsp',
            'L3MON4D3/LuaSnip',
        },
        config = function()
            -- LSP keymaps on attach
            vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(args)
                    local opts = { buffer = args.buf }
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                    vim.keymap.set('n', '<leader>f', function()
                        vim.lsp.buf.format({ async = true })
                    end, opts)
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
        },
        config = function()
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
                        hide_by_name = {
                            --"node_modules"
                        },
                        hide_by_pattern = {
                            --"*.meta",
                            --"*/src/*/tsconfig.json",
                        },
                        always_show = {
                            --".gitignored",
                        },
                        never_show = {
                            --".DS_Store",
                            --"thumbs.db"
                        },
                        never_show_by_pattern = {
                            --".null-ls_*",
                        },
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

            vim.keymap.set('n', '\\', '<cmd>Neotree reveal<CR>')
        end
    },

     {
      "folke/snacks.nvim",
      opts = {
        indent = {
          scope = {
            animate = {
              enabled = false
            }
          }
        }
      }
    },

    -- Fuzzy finder
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.8',
        dependencies = { 'nvim-lua/plenary.nvim' },
        config = function()
            local builtin = require('telescope.builtin')
            vim.keymap.set('n', '<leader>ff', builtin.find_files)
            vim.keymap.set('n', '<leader>fg', builtin.live_grep)
            vim.keymap.set('n', '<leader>fb', builtin.buffers)
            vim.keymap.set('n', '<leader>fh', builtin.help_tags)
        end
    },

    -- Terminal Integration
    {
        "akinsho/toggleterm.nvim",
        config = function()
            require("toggleterm").setup({
                size = 20,
                open_mapping = [[<c-\>]],
                hide_numbers = true,
                shade_terminals = true,
                direction = "float",
            })
        end
    },

    -- Git integration
    {
        'lewis6991/gitsigns.nvim',
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
                dap_debug = true,
            })
        end,
        event = {"CmdlineEnter"},
        ft = {"go", 'gomod'},
        build = ':lua require("go.install").update_all_sync()'
    },

    -- Debugging support
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "mfussenegger/nvim-dap-python",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            local dap = require('dap')
            local dapui = require('dapui')

            -- Python debugger setup (debugpy must be installed in the Python environment)
            require('dap-python').setup(vim.fn.exepath('python3'))

            -- Debugger UI
            dapui.setup()

            -- Debugger keymaps
            vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint)
            vim.keymap.set('n', '<leader>dc', dap.continue)
            vim.keymap.set('n', '<leader>ds', dap.step_over)
            vim.keymap.set('n', '<leader>di', dap.step_into)
            vim.keymap.set('n', '<leader>do', dap.step_out)
            vim.keymap.set('n', '<leader>du', dapui.toggle)
        end
    },

    -- Code outline/symbols
    {
        'hedyhli/outline.nvim',
        config = function()
            require('outline').setup()
            vim.keymap.set('n', '<leader>so', ':Outline<CR>')
        end
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
            vim.keymap.set("i", "<Tab>", smart_tab, { expr = false, silent = true })
        end,
    },

    {
        "m4xshen/hardtime.nvim",
        dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
        opts = {
            max_count = 2,
            disabled_keys = {
                ["<Up>"] = {},
                ["<Down>"] = {},
                ["<Left>"] = {},
                ["<Right>"] = {},
            },
            hint = true, -- shows hint when you make inefficient movement
            notification = true, -- shows notification when you make inefficient movement
        }
    },

    {
        "karb94/neoscroll.nvim",
        opts = {},
    },

    {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = {
            "mfussenegger/nvim-dap",
        },
        config = function()
            require("nvim-dap-virtual-text").setup()
        end
    },
}

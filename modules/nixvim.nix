# nixvim.nix -- declarative neovim configuration via NixVim
#
# Replaces the old kickstart.nvim + lazy.nvim setup with a fully Nix-managed config.
# No luarocks, no runtime plugin downloads, no Mason -- everything comes from nixpkgs.
#
# Languages: Python, Go, Rust, TypeScript, Nix, Lua, YAML, JSON, Bash, Markdown
# Not included: C/C++, Java, Bitbake
{ config, lib, pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;  # sets EDITOR=nvim, VISUAL=nvim
    viAlias = true;
    vimAlias = true;

    # ── General options ──────────────────────────────────────────────
    globals = {
      mapleader = " ";
      maplocalleader = " ";
      have_nerd_font = true;
    };

    opts = {
      number = true;
      relativenumber = false;
      mouse = "a";
      showmode = false;
      clipboard = "unnamedplus";
      breakindent = true;
      undofile = true;
      ignorecase = true;
      smartcase = true;
      signcolumn = "yes";
      updatetime = 250;
      timeoutlen = 300;
      splitright = true;
      splitbelow = true;
      list = true;
      listchars = "tab:» ,trail:·,nbsp:␣";
      inccommand = "split";
      cursorline = true;
      scrolloff = 20;
      tabstop = 2;
      shiftwidth = 2;
      expandtab = true;
      termguicolors = true;
    };

    # ── Keymaps ──────────────────────────────────────────────────────
    keymaps = [
      # Clear search highlight
      { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<CR>"; }

      # Diagnostics
      { mode = "n"; key = "<leader>q"; action = "<cmd>lua vim.diagnostic.setloclist()<CR>"; options.desc = "Open diagnostic quickfix"; }

      # Window navigation
      { mode = "n"; key = "<C-h>"; action = "<C-w><C-h>"; options.desc = "Move to left window"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w><C-l>"; options.desc = "Move to right window"; }
      { mode = "n"; key = "<C-j>"; action = "<C-w><C-j>"; options.desc = "Move to lower window"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w><C-k>"; options.desc = "Move to upper window"; }

      # Terminal escape
      { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>"; options.desc = "Exit terminal mode"; }

      # Format buffer
      { mode = ""; key = "<leader>f"; action = "<cmd>lua require('conform').format({ async = true, lsp_format = 'fallback' })<CR>"; options.desc = "Format buffer"; }

      # Trouble (diagnostics panel)
      { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; options.desc = "Diagnostics (Trouble)"; }
      { mode = "n"; key = "<leader>xb"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>"; options.desc = "Buffer diagnostics (Trouble)"; }
      { mode = "n"; key = "<leader>xs"; action = "<cmd>Trouble symbols toggle focus=false<CR>"; options.desc = "Symbols (Trouble)"; }
      { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble qflist toggle<CR>"; options.desc = "Quickfix list (Trouble)"; }
    ];

    # ── Autocommands ─────────────────────────────────────────────────
    autoCmd = [
      {
        event = "TextYankPost";
        desc = "Highlight on yank";
        callback.__raw = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      }
      {
        event = "FileType";
        pattern = "go";
        desc = "Go uses tabs; render them narrower than the default 8";
        callback.__raw = ''
          function()
            vim.opt_local.expandtab = false
            vim.opt_local.tabstop = 4
            vim.opt_local.shiftwidth = 4
            vim.opt_local.softtabstop = 0
          end
        '';
      }
      {
        event = [ "BufWritePost" "BufReadPost" ];
        desc = "Run nvim-lint on save and open";
        callback.__raw = ''
          function() require("lint").try_lint() end
        '';
      }
    ];

    # ── Colorscheme ──────────────────────────────────────────────────
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavour = "frappe";
        background = {
          light = "latte";
          dark = "frappe";
        };
        integrations = {
          cmp = true;
          gitsigns = true;
          treesitter = true;
          telescope.enabled = true;
          which_key = true;
          mini.enabled = true;
        };
      };
    };

    # ── Plugins ──────────────────────────────────────────────────────

    # Telescope (fuzzy finder with fzf + ripgrep)
    plugins.telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
      extensions.ui-select.enable = true;
      settings.pickers = {
        live_grep = {
          file_ignore_patterns = [ ".git/" ".direnv" ".venv" "node_modules" ];
          additional_args.__raw = ''function() return { "--hidden" } end'';
        };
        find_files = {
          file_ignore_patterns = [ ".git/" ".direnv" ".venv" "node_modules" ];
          hidden = true;
        };
      };
      keymaps = {
        "<leader>sf" = { action = "find_files"; options.desc = "Search files"; };
        "<leader>sg" = { action = "live_grep"; options.desc = "Search by grep"; };
        "<leader>sh" = { action = "help_tags"; options.desc = "Search help"; };
        "<leader>sk" = { action = "keymaps"; options.desc = "Search keymaps"; };
        "<leader>sd" = { action = "diagnostics"; options.desc = "Search diagnostics"; };
        "<leader>sr" = { action = "resume"; options.desc = "Search resume"; };
        "<leader>s." = { action = "oldfiles"; options.desc = "Search recent files"; };
        "<leader><leader>" = { action = "buffers"; options.desc = "Find buffers"; };
        "<leader>sw" = { action = "grep_string"; options.desc = "Search current word"; };
        "<leader>ss" = { action = "builtin"; options.desc = "Search Telescope builtins"; };
      };
    };

    # Treesitter (syntax highlighting, indentation)
    plugins.treesitter = {
      enable = true;
      settings = {
        ensure_installed = [
          "bash" "diff" "go" "gomod" "gosum"
          "html" "json" "jsonc" "lua" "luadoc"
          "markdown" "markdown_inline"
          "nix" "python" "query" "rust"
          "toml" "typescript" "vim" "vimdoc" "yaml"
        ];
        auto_install = true;
        highlight.enable = true;
        indent.enable = true;
      };
    };

    # LSP
    plugins.lsp = {
      enable = true;
      servers = {
        # Python
        pyright.enable = true;

        # Go
        gopls = {
          enable = true;
          settings.gopls = {
            gofumpt = true;
            staticcheck = true;
            usePlaceholders = true;
            completeUnimported = true;
            analyses = {
              unusedparams = true;
              unusedwrite = true;
              shadow = true;
              nilness = true;
            };
            hints = {
              assignVariableTypes = true;
              compositeLiteralFields = true;
              constantValues = true;
              functionTypeParameters = true;
              parameterNames = true;
              rangeVariableTypes = true;
            };
          };
        };

        # TypeScript
        ts_ls.enable = true;

        # Nix
        nil_ls.enable = true;

        # YAML
        yamlls.enable = true;

        # JSON
        jsonls.enable = true;

        # Markdown
        marksman.enable = true;

        # Lua (for neovim config editing)
        lua_ls = {
          enable = true;
          settings.Lua = {
            completion.callSnippet = "Replace";
            diagnostics.globals = [ "vim" ];
          };
        };

        # Bash
        bashls.enable = true;
      };

      keymaps = {
        lspBuf = {
          "gd" = { action = "definition"; desc = "Goto definition"; };
          "gD" = { action = "declaration"; desc = "Goto declaration"; };
          "gI" = { action = "implementation"; desc = "Goto implementation"; };
          "gr" = { action = "references"; desc = "Goto references"; };
          "<leader>D" = { action = "type_definition"; desc = "Type definition"; };
          "<leader>rn" = { action = "rename"; desc = "Rename"; };
          "<leader>ca" = { action = "code_action"; desc = "Code action"; };
        };
        extra = [
          { mode = "n"; key = "<leader>ds"; action.__raw = "require('telescope.builtin').lsp_document_symbols"; options.desc = "Document symbols"; }
          { mode = "n"; key = "<leader>ws"; action.__raw = "require('telescope.builtin').lsp_dynamic_workspace_symbols"; options.desc = "Workspace symbols"; }
        ];
      };
    };

    # Autocompletion
    plugins.cmp = {
      enable = true;
      settings = {
        snippet.expand = ''function(args) require('luasnip').lsp_expand(args.body) end'';
        completion.completeopt = "menu,menuone,noinsert";
        mapping = {
          "<C-n>" = "cmp.mapping.select_next_item()";
          "<C-p>" = "cmp.mapping.select_prev_item()";
          "<C-b>" = "cmp.mapping.scroll_docs(-4)";
          "<C-f>" = "cmp.mapping.scroll_docs(4)";
          "<C-y>" = "cmp.mapping.confirm({ select = true })";
          "<C-Space>" = "cmp.mapping.complete()";
        };
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
        ];
      };
    };
    plugins.luasnip.enable = true;
    plugins.cmp-nvim-lsp.enable = true;
    plugins.cmp-path.enable = true;
    plugins.cmp_luasnip.enable = true;

    # Formatting
    plugins.conform-nvim = {
      enable = true;
      settings = {
        format_on_save = {
          timeout_ms = 500;
          lsp_format = "fallback";
        };
        formatters_by_ft = {
          go = [ "goimports" ];
          json = [ "prettier" ];
          jsonc = [ "prettier" ];
          lua = [ "stylua" ];
          markdown = [ "prettier" ];
          nix = [ "nixfmt" ];
          python = [ "ruff_format" ];
          sh = [ "shfmt" ];
          typescript = [ "prettier" ];
          yaml = [ "prettier" ];
        };
      };
    };

    # Linting (nvim-lint) -- triggered manually via autocmd below
    plugins.lint = {
      enable = true;
      lintersByFt = {
        go = [ "golangcilint" ];
      };
    };

    # Git signs in gutter
    plugins.gitsigns = {
      enable = true;
      settings.signs = {
        add.text = "+";
        change.text = "~";
        delete.text = "_";
        topdelete.text = "‾";
        changedelete.text = "~";
      };
    };

    # Which-key (keybinding helper)
    plugins.which-key = {
      enable = true;
      settings.spec = [
        { __unkeyed-1 = "<leader>c"; group = "Code"; mode = [ "n" "x" ]; }
        { __unkeyed-1 = "<leader>d"; group = "Document"; }
        { __unkeyed-1 = "<leader>r"; group = "Rename"; }
        { __unkeyed-1 = "<leader>s"; group = "Search"; }
        { __unkeyed-1 = "<leader>w"; group = "Workspace"; }
        { __unkeyed-1 = "<leader>t"; group = "Toggle"; }
        { __unkeyed-1 = "<leader>h"; group = "Git Hunk"; mode = [ "n" "v" ]; }
        { __unkeyed-1 = "<leader>x"; group = "Trouble"; }
      ];
    };

    # Mini.nvim (surround, ai textobjects, statusline)
    plugins.mini = {
      enable = true;
      modules = {
        ai = { n_lines = 500; };
        surround = {};
        statusline = { use_icons = true; };
      };
    };

    # Todo comments highlighting
    plugins.todo-comments = {
      enable = true;
      settings.signs = false;
    };

    # Fidget (LSP progress indicator)
    plugins.fidget.enable = true;

    # Sleuth (auto-detect tabstop/shiftwidth)
    plugins.sleuth.enable = true;

    # AI code completion (Copilot-compatible inline suggestions)
    plugins.copilot-lua = {
      enable = true;
      settings = {
        suggestion = {
          enabled = true;
          auto_trigger = true;
          keymap = {
            accept = "<Tab>";
            accept_word = false;
            accept_line = false;
            next = "<M-]>";
            prev = "<M-[>";
            dismiss = "<C-]>";
          };
        };
        panel.enabled = false;
        filetypes = {
          markdown = true;
          yaml = true;
          nix = true;
        };
      };
    };

    # Diffview (git diff viewer)
    plugins.diffview.enable = true;

    # Trouble (diagnostics, quickfix and references panel)
    plugins.trouble = {
      enable = true;
      settings = { };
    };

    # File icons used by telescope, trouble and diffview. Enabling explicitly
    # silences the nixvim deprecation warning about auto-enabling it.
    plugins.web-devicons.enable = true;



    # Extra tools available in PATH for formatters/linters
    extraPackages = with pkgs; [
      # Formatters (LSP servers are managed by NixVim)
      nixfmt-rfc-style
      prettier
      ruff
      shfmt
      stylua
      # Go: goimports (via gotools) replaces gofmt and fixes imports too
      gotools
      # Go linter wired into nvim-lint
      golangci-lint
    ];
  };
}

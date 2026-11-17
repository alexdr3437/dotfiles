# Base keymaps: the ones that need no plugin. Plugin keymaps live with their plugin.
{ ... }:
let
  # goto_next/goto_prev are deprecated: jump, then float the diagnostic under the cursor
  diagnosticJump = count: ''
    function()
      vim.diagnostic.jump({
        count = ${toString count},
        on_jump = function(_, bufnr)
          vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
        end,
      })
    end
  '';
in
{
  programs.nixvim.keymaps = [
    # clear the search highlight and, if gitsigns is loaded, the <leader>gD diff overlay
    {
      mode = "n";
      key = "<Esc>";
      action.__raw = ''
        function()
          vim.cmd("nohlsearch")
          if _M.gitdiff then
            _M.gitdiff.clear()
          end
        end
      '';
      options.desc = "Clear search highlight and git diff overlay";
    }

    # K: the line's diagnostic if there is one, else hover. Global, so nvim's own LSP K stands down.
    {
      mode = "n";
      key = "K";
      action.__raw = ''
        function()
          if vim.diagnostic.open_float({ scope = "line", focus = false }) then
            return
          end

          local hover = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/hover" })
          if not vim.tbl_isempty(hover) then
            vim.lsp.buf.hover()
            return
          end

          -- neither: plain K ('keywordprg')
          vim.cmd("normal! K")
        end
      '';
      options.desc = "Diagnostic under cursor, else hover";
    }

    # Reflow to textwidth
    {
      mode = "v";
      key = "<leader>q";
      action = "gq";
      options.desc = "Reflow selection to textwidth";
    }

    # Diagnostics. Note [ = next and ] = previous, matching [q/]q below.
    {
      mode = "n";
      key = "[d";
      action.__raw = diagnosticJump 1;
      options.desc = "Go to next [D]iagnostic message";
    }
    {
      mode = "n";
      key = "]d";
      action.__raw = diagnosticJump (-1);
      options.desc = "Go to previous [D]iagnostic message";
    }
    {
      mode = "n";
      key = "<leader>e";
      action.__raw = "vim.diagnostic.open_float";
      options.desc = "Show diagnostic [E]rror messages";
    }

    # Quickfix
    {
      mode = "n";
      key = "[q";
      action = "<cmd>cnext<CR>";
      options.desc = "Next quickfix item";
    }
    {
      mode = "n";
      key = "]q";
      action = "<cmd>cprev<CR>";
      options.desc = "Previous quickfix item";
    }
    {
      mode = "n";
      key = "<leader>q";
      action = "<cmd>copen<CR>";
      options.desc = "Open [Q]uickfix list";
    }

    # Window navigation
    {
      mode = "n";
      key = "<C-h>";
      action = "<C-w><C-h>";
      options.desc = "Move focus to the left window";
    }
    {
      mode = "n";
      key = "<C-l>";
      action = "<C-w><C-l>";
      options.desc = "Move focus to the right window";
    }
    {
      mode = "n";
      key = "<C-j>";
      action = "<C-w><C-j>";
      options.desc = "Move focus to the lower window";
    }
    {
      mode = "n";
      key = "<C-k>";
      action = "<C-w><C-k>";
      options.desc = "Move focus to the upper window";
    }

    # Terminal
    {
      mode = "t";
      key = "<Esc><Esc>";
      action = "<C-\\><C-n>";
      options.desc = "Exit terminal mode";
    }
  ];
}

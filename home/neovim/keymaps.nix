# Base keymaps: the ones that need no plugin. Plugin keymaps live with their plugin.
{ ... }:
let
  # vim.diagnostic.goto_next/goto_prev are deprecated (removal targeted at 0.13,
  # which is what the nightly already is). jump() with on_jump reproduces what
  # goto_next did: move, then open a float for the diagnostic under the cursor.
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
    # Clear transient highlighting. Search highlight, plus the sticky git diff
    # overlay from <leader>gD -- both are "I turned this on to look at something
    # and now I am done" state, and <Esc> is already the reflex for that.
    #
    # Guarded rather than assumed: this file is the no-plugin baseline, so it has
    # to keep working if git.nix is not in the imports.
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

    # K: the diagnostic on this line if there is one, hover otherwise.
    #
    # Mapped globally on purpose, not in lsp.nix's LspAttach keymaps. nvim
    # installs its own K -> vim.lsp.buf.hover() when a server attaches, but only
    # while K is still unmapped (lsp.lua checks maparg first). Claiming it here
    # makes that check fail, so nvim stands down and there is no race over which
    # LspAttach handler registered last.
    #
    # Layered rather than replacing hover outright: open_float returns nil when
    # the cursor line carries no diagnostic, and that nil is the signal to fall
    # through. Delete the first branch to make K show diagnostics unconditionally.
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

          -- No diagnostic and no hover-capable server: plain K, i.e. whatever
          -- 'keywordprg' points at.
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

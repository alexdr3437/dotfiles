# Base editor config: everything that is plain vim.g / vim.opt and needs no plugin.
{ ... }:
{
  programs.nixvim = {
    globals = {
      # <space> as the leader key, set before any keymap is defined
      mapleader = " ";
      maplocalleader = " ";

      # Nerd Font is installed and selected in the terminal
      have_nerd_font = true;
    };

    opts = {
      # Line numbers
      number = true;
      relativenumber = true;

      # No soft wrapping; hard-wrap with textwidth/formatoptions instead
      wrap = false;
      textwidth = 110;
      # t: wrap text, q: allow gq formatting, n: lists,
      # j: smart join, r: continue comments on <CR>
      formatoptions = "tqnjr";
      breakindent = true;

      # Tabs: real tabs, 4 wide
      tabstop = 4;
      softtabstop = 4;
      shiftwidth = 4;
      expandtab = false;

      # Search
      hlsearch = true;
      ignorecase = true;
      smartcase = true;
      # Preview substitutions live, as you type
      inccommand = "split";

      # UI
      mouse = "a";
      # Mode is already in the status line
      showmode = false;
      signcolumn = "yes";
      cursorline = false;
      list = false;
      scrolloff = 20;

      # Splits open where you look
      splitright = true;
      splitbelow = true;

      # Share the OS clipboard
      clipboard = "unnamedplus";

      # Persistent undo
      undofile = true;

      # Responsiveness
      updatetime = 250;
      timeoutlen = 1000;
    };
  };
}

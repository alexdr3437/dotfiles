# neovim: remaining port

Tracking what still has to move from the old lua/lazy config in
`files/dotfiles/nvim/` to the nixvim config in `home/neovim/`.
Compared 2026-09-18.

## High impact

- [x] **Completion engine** — nvim-cmp + LuaSnip, sources `nvim_lsp`/`luasnip`/`path`,
      original keymaps kept. See `plugins/completion.nix`.
- [x] **Formatting** — conform.nvim, `<leader>f`, format-on-save. See `plugins/format.nix`.
- [x] **Copilot** — `copilot.lua`, auto-trigger, accept on `<C-y>`. See `plugins/copilot.nix`.
- [x] **LSP servers** — added `basedpyright`, `ruff`, `ts_ls`, `zls`, `harper_ls`,
      `dts_lsp`. All six were already known to nixvim, so no custom server
      definition was needed. See `lsp.nix`.
- [x] **LSP server settings** — clangd flags + root markers, rust_analyzer
      settings and debounce, lua_ls runtime/globals/library, nixd nixfmt.
      See `lsp.nix`.

## Editing / UX plugins

- [x] **which-key.nvim** — see `plugins/which-key.nix`.
- [x] **todo-comments.nvim** — see `plugins/todo-comments.nix`.
- [x] `mini.ai` (`n_lines = 500`) and `mini.surround` — default mappings, both at
      `n_lines = 500`. See `plugins/textobjects.nix`.
- [ ] `undotree` — `<leader>u`.
- [ ] `outline.nvim` — `<leader>o`, `symbol_folding.autofold_depth = false`.
- [ ] `snipe.nvim` buffer menu — was `<leader>s`, which now collides with the
      `<leader>sf`/`<leader>sg`/`<leader>sw` session pickers. Needs a new key.
- [ ] `lazygit.nvim` — `<leader>lg`.
- [ ] `nvim-colorizer.lua`.
- [ ] `render-markdown.nvim` — code blocks off, render in `n`/`c` modes.
- [ ] `baleia.nvim` — `:BaleiaColorize`, `:BaleiaLogs`, and the `BufReadPost`
      autocmd that auto-colorizes a buffer containing ANSI escapes.
- [ ] `vim-indent-object`.
- [ ] `vim-just` syntax — the `just` LSP is enabled but the ft plugin is not.
- [ ] `fidget.nvim` (LSP progress).
- [ ] Lua LSP support for the nvim config itself — old config used `neodev`;
      `lazydev` is the current equivalent.
- [ ] Telescope extensions: `fzf-native` (sorter performance) and `ui-select`
      (dropdown for `vim.ui.select`).
- [ ] `blame.nvim` — `<leader>b`. Mostly covered by gitsigns `<leader>gb`/`<leader>gB`;
      decide whether it is still wanted.

## Config details

- [ ] **Inlay hints toggle** on LspAttach. Was `<leader>th`, which `plugins/themes.nix`
      has since taken for the theme picker, so it needs a new key.
- [ ] **Document highlight** — `vim.lsp.buf.document_highlight` on CursorHold/CursorHoldI,
      cleared on CursorMoved/CursorMovedI and LspDetach.
- [ ] **Rust highlight overrides** — `DiagnosticUnnecessary` fg `NONE`,
      `@lsp.type.unresolvedReference.rust` → `Normal`,
      `@lsp.mod.readingFromConfig.rust` → `Normal`. Stops inactive `#[cfg]` code
      from being greyed out.
- [ ] **Treesitter parser list** — `plugins/treesitter.nix` is a bare enable. The old
      config installed an explicit parser list and had a `FileType` autocmd that
      deliberately skipped the `rust` and `just` parsers, because the rust parser
      can retain gigabytes in macro-heavy workspaces.
- [ ] **Per-filetype indents** for cpp and python. Note the old
      `after/ftplugin/cpp.nvim` and `python.nvim` never loaded — ftplugin files
      have to be `.lua` or `.vim`, so that setting was silently dead.
- [ ] `TelescopeNormal`/`TelescopeBorder` bg `NONE` — probably already handled by
      transparent.nvim; confirm before porting.

## Added beyond the port

- [x] **codecompanion.nvim** — new, not a port. `chat` on the `claude_code` ACP
      adapter (Claude Pro subscription, via the logged-in `claude`), `inline`/`cmd`
      on copilot, `cli` on `claude`. No API key anywhere. `<leader>c` group.
      See `plugins/codecompanion.nix`.
- [ ] **Never export `ANTHROPIC_API_KEY` into the session env.** An API key
      outranks the stored subscription in Claude Code's credential precedence, so
      a globally-set key would silently move chat off the subscription and onto
      metered billing. Same applies to `CLAUDE_CODE_OAUTH_TOKEN`.
- [ ] **Pin a copilot model id** for `inline`/`cmd`. The list is fetched live and
      depends on entitlements — run `ga` in the chat buffer to see it, then pin a
      mini model. `chat` needs nothing: it inherits the CLI's own default.
- [ ] `CLAUDE_CODE_EXECUTABLE` currently resolves to the nixpkgs `claude-code`
      (2.1.272) that `claude-agent-acp` is wrapped against, a few patches behind
      `~/.local/bin/claude` (2.1.278). Both read the same `~/.claude`
      credentials, so it works; decide whether one install is worth the impure
      path.
- [ ] `:CodeCompanionCLI Install` writes CodeCompanion's hooks into Claude Code's
      own settings, which is what turn-boundary features like
      `CodeCompanionCodeReview` need. That file lives outside the nix store, so
      decide whether to run it by hand or manage it from this repo.
- [ ] `codecompanion-history` (nixvim has a module) if persisted chats turn out
      to matter.

## Decided against / not active

- ~~`typescript-tools.nvim`~~ — `ts_ls` covers it, and the lua config ran both at
  once, which meant two servers attached to every TS buffer.
- ~~`trouble.nvim`~~ — declined 2026-09-18. `<leader>pD` already fuzzy-finds
  diagnostics and `<leader>q`/`[q`/`]q` already walk the quickfix list, and its
  symbols mode would overlap outline.nvim.
- `Comment.nvim` — nvim >= 0.10 ships `gc` built in.
- The kickstart modules in `lua/kickstart/plugins/` (autopairs, neo-tree, lint,
  indent_line, DAP debug) were all commented out in the old `init.lua`, so
  nothing is lost. Revisit only if wanted now.
- `ThePrimeagen/99` (`<leader>9v`, `<leader>9s`) — not packaged in nixpkgs, would
  need a `buildVimPlugin` from source.

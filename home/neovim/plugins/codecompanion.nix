# codecompanion.nvim: chat buffer, inline edits, and a terminal wrapper around
# agent CLIs. Three interactions, three backends -- and deliberately no API key
# anywhere, because every one of them rides a subscription that is already
# authenticated on this machine:
#
#   chat   -> claude_code over ACP, which drives the logged-in `claude` CLI and
#             bills the Claude Pro subscription.
#   inline -> copilot, over the auth copilot.lua already put in
#             ~/.config/github-copilot. ACP cannot serve this: upstream supports
#             ACP adapters for the chat interaction only, so inline needs an HTTP
#             adapter and copilot is the one that needs no key.
#   cli    -> `claude` itself, for work that reads the repo and writes files.
#
# `background` (chat titles, compaction) already defaults to copilot upstream, so
# it is left alone rather than restated.
#
# The CLI half is the reason this plugin is here rather than avante: `#{this}`
# expands a visual selection to `@path (lines N-M)` followed by the snippet, and
# Claude Code resolves `@path` natively, so the agent opens the file for
# surrounding context instead of reasoning from the pasted lines alone.
{ nvimPkgs, ... }:
let
  # Body shared by <leader>cb and <leader>cnb. `fresh` picks which chat buffer
  # the selection lands in: false reuses `last_chat()` and only creates one when
  # there is none, true always opens another.
  addSelection = fresh: ''
    function()
      local cc = require("codecompanion")
      local config = require("codecompanion.config")
      local markdown = require("codecompanion.utils.markdown")
      local context = require("codecompanion.utils.context").get(vim.api.nvim_get_current_buf())

      local chat = ${if fresh then "nil" else "cc.last_chat()"}
      if not chat then
        -- stop_context_insertion, because the selection is added below with the
        -- `@path (lines N-M)` header rather than the plugin's own wording.
        chat = cc.chat({ stop_context_insertion = true })
        if not chat then
          return vim.notify("Could not create chat buffer", vim.log.levels.WARN)
        end
      end

      chat:add_buf_message({
        role = config.constants.USER_ROLE,
        content = string.format(
          "from %s (lines %d-%d):\n%s\n",
          context.relative_path,
          context.start_line,
          context.end_line,
          markdown.form_codeblock(table.concat(context.lines, "\n"), { ft = context.filetype })
        ),
      })
      chat.ui:open()
    end
  '';
in
{
  programs.nixvim = {
    # The ACP bridge between CodeCompanion and Claude Code. Its nixpkgs wrapper
    # `--set-default`s CLAUDE_CODE_EXECUTABLE to the nixpkgs claude-code, which
    # is a second Claude Code install a few patches behind ~/.local/bin/claude --
    # but it reads the same credentials in ~/.claude, and it is pinned rather
    # than self-updating. Set CLAUDE_CODE_EXECUTABLE in the adapter env below to
    # point it at the native binary instead.
    extraPackages = [ nvimPkgs.claude-agent-acp ];

    plugins.codecompanion = {
      enable = true;

      # plenary comes in through the nixpkgs package's own `dependencies`, so it
      # does not need listing.
      #
      # Everything here goes through nixvim's freeform `settings`. The module
      # still declares the pre-v19 `strategies` option, which v19 renamed to
      # `interactions`, so none of these keys are checked at eval time -- a typo
      # is silent in nix and shows up as a missing feature in nvim.
      settings = {
        # Load-bearing workaround, not configuration.
        #
        # The claude_code adapter ships `env = { CLAUDE_CODE_OAUTH_TOKEN =
        # "CLAUDE_CODE_OAUTH_TOKEN" }`, meaning "read that variable from the
        # environment". When it is unset, `get_env_vars` falls all the way
        # through its prefix checks to `env_replaced[k] = v` and hands the
        # adapter the *literal string* "CLAUDE_CODE_OAUTH_TOKEN" as a token. The
        # adapter's auth handler only tests for non-empty, so it exports that
        # garbage to the agent -- and an OAuth token outranks the stored
        # subscription: with it set, `claude auth status` flips authMethod from
        # "claude.ai" to "oauth_token" and drops subscriptionType entirely.
        #
        # A function is the only way out, since `extend` is a tbl_deep_extend and
        # cannot delete a key. Returning nil leaves the key absent from the
        # spawn env, the auth handler returns false, and -- because a false auth
        # hook is not fatal -- CodeCompanion falls through to ACP negotiation.
        # The bridge advertises `authMethods: []` when `claude` is already logged
        # in, so the connection is considered authenticated with no token.
        adapters.acp.claude_code.__raw = ''
          function()
            return require("codecompanion.adapters").extend("claude_code", {
              env = {
                CLAUDE_CODE_OAUTH_TOKEN = function()
                  return nil
                end,
              },
            })
          end
        '';

        interactions = {
          # Model left unset on both: claude_code takes whatever the logged-in
          # CLI defaults to, and copilot's list is fetched live from
          # api.githubcopilot.com and depends on entitlements, so pinning an id
          # here would be a guess that fails at request time rather than at eval
          # time. `ga` in the chat buffer lists what is actually available.
          chat.adapter = "claude_code";
          inline.adapter = "copilot";

          # Generates a single ex command into the cmdline. Cheapest task here.
          cmd.adapter = "copilot";

          cli = {
            agent = "claude_code";

            # `agents` ships empty, so :CodeCompanionCLI does nothing until one
            # is declared. A bare PATH lookup on purpose: this drives the
            # native-installer binary in ~/.local/bin, which is the one holding
            # the subscription login.
            agents.claude_code = {
              cmd = "claude";
              description = "Claude Code CLI";
              provider = "terminal";
            };
          };
        };

        # Join the <leader>p pickers in telescope.nix instead of falling back to
        # the plugin's own vim.ui.select menu.
        display.action_palette.provider = "telescope";
      };
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>cc";
        action = "<cmd>CodeCompanionChat Toggle<CR>";
        options.desc = "[C]odeCompanion [c]hat toggle";
      }

      # `CodeCompanionChat` without `Toggle` always builds another chat buffer,
      # so this starts a second conversation from normal mode the way
      # <leader>cnb does from visual mode. The previous chat stays open and
      # <leader>cc goes back to whichever was last active.
      {
        mode = "n";
        key = "<leader>cnc";
        action = "<cmd>CodeCompanionChat<CR>";
        options.desc = "[C]odeCompanion [n]ew [c]hat";
      }

      # Fullscreen toggle. The plugin has no maximize/zoom of its own, so this
      # promotes the chat window to its own tab (`wincmd T`) and drops back by
      # closing that tab. Going via a tab rather than `wincmd o` is what keeps
      # the splits underneath intact -- they are still sitting in the tab the
      # chat was promoted out of.
      #
      # `filetype == "codecompanion"` is the hook rather than the plugin's Lua
      # API: the ui sets it on the chat buffer, and it does not match the CLI
      # interaction's terminal buffer, so this never grabs the wrong window.
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = ''
          function()
            local function find_chat()
              -- Current tab first, so a chat visible here wins over one parked
              -- in some other tab.
              local tabs = { vim.api.nvim_get_current_tabpage() }
              for _, t in ipairs(vim.api.nvim_list_tabpages()) do
                if t ~= tabs[1] then
                  table.insert(tabs, t)
                end
              end

              for _, tab in ipairs(tabs) do
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
                  if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "codecompanion" then
                    return win, tab
                  end
                end
              end
            end

            local win, tab = find_chat()
            if not win then
              return vim.cmd("CodeCompanionChat Toggle")
            end

            -- Alone in its tab is the zoomed state.
            if #vim.api.nvim_tabpage_list_wins(tab) == 1 then
              if #vim.api.nvim_list_tabpages() > 1 then
                vim.cmd(vim.api.nvim_tabpage_get_number(tab) .. "tabclose")
                -- tabclose destroys the window it was in, so the chat has to be
                -- re-opened explicitly or the way back out of fullscreen just
                -- makes it vanish.
                return vim.cmd("CodeCompanionChat Toggle")
              end
              -- Only window in the only tab: already fullscreen, and `wincmd T`
              -- would just fail here.
              return
            end

            vim.api.nvim_set_current_win(win)
            vim.cmd("wincmd T")
          end
        '';
        options.desc = "[C]odeCompanion chat [f]ullscreen toggle";
      }

      # The chat-buffer twin of <leader>ca below: this one feeds the chat
      # adapter, <leader>ca feeds the agent running in the terminal.
      #
      # Hand-rolled rather than `<cmd>CodeCompanionChat Add<CR>` purely for the
      # header on the pasted block: CodeCompanion.add hardcodes "Here is some
      # code from <abs path>:" with no config key behind it, and this is the
      # whole of that function otherwise. The header here matches the
      # `@path (lines N-M)` shape `#{this}` gives <leader>ca.
      #
      # utils.context.get reads the live `v`/`.` positions when called from
      # visual mode, so a function mapping gets the selection without the
      # command's `range` plumbing.
      {
        mode = "v";
        key = "<leader>cb";
        action.__raw = addSelection false;
        options.desc = "[C]odeCompanion add selection to chat [b]uffer";
      }

      # Same thing into a chat of its own. `last_chat()` is skipped entirely, so
      # this is the way to start a second conversation instead of piling another
      # snippet onto the running one. The old chat is not closed -- <leader>cc
      # toggles whichever was last active.
      {
        mode = "v";
        key = "<leader>cnb";
        action.__raw = addSelection true;
        options.desc = "[C]odeCompanion selection to [n]ew chat [b]uffer";
      }

      # The two that do the thing this plugin was added for. In visual mode both
      # carry the selection; in normal mode they fall back to the whole buffer.
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>cp";
        action.__raw = ''function() return require("codecompanion").cli({ prompt = true }) end'';
        options.desc = "[C]odeCompanion CLI [p]rompt";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ca";
        # focus = false keeps the cursor where it is, which is what makes it
        # usable as "add this too" while reading around a codebase.
        action.__raw = ''function() return require("codecompanion").cli("#{this}", { focus = false }) end'';
        options.desc = "[C]odeCompanion [a]dd context to CLI agent";
      }

      {
        mode = "n";
        key = "<leader>cd";
        # submit = true: there is no prompt left to write for this one.
        action.__raw = ''
          function()
            return require("codecompanion").cli("#{diagnostics} Can you fix these?", {
              focus = false,
              submit = true,
            })
          end
        '';
        options.desc = "[C]odeCompanion send [d]iagnostics to CLI agent";
      }

      # No <CR>: this prefills the cmdline so the prompt can be typed after it.
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ci";
        action = ":CodeCompanion ";
        options = {
          desc = "[C]odeCompanion [i]nline";
          silent = false;
        };
      }

      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>cA";
        action = "<cmd>CodeCompanionActions<CR>";
        options.desc = "[C]odeCompanion [A]ction palette";
      }
    ];
  };
}

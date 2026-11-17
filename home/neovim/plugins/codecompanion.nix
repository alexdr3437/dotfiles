# codecompanion.nvim, on subscriptions only, no API keys:
#   chat   -> claude_code or codex over ACP (`ga` in the chat buffer switches)
#   inline -> copilot (ACP only serves chat)
#   cli    -> `claude` in a terminal; `#{this}` passes the selection as `@path (lines N-M)`
{ nvimPkgs, ... }:
let
  # body of <leader>cb and <leader>cnb; `fresh` always opens a new chat
  addSelection = fresh: ''
    function()
      local cc = require("codecompanion")
      local config = require("codecompanion.config")
      local markdown = require("codecompanion.utils.markdown")
      local context = require("codecompanion.utils.context").get(vim.api.nvim_get_current_buf())

      local chat = ${if fresh then "nil" else "cc.last_chat()"}
      if not chat then
        -- the selection is added below, under its own `from <path> (lines N-M):` header
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
    # ACP bridges to nixpkgs' claude-code and codex, which use the logins in ~/.claude and ~/.codex
    extraPackages = [
      nvimPkgs.claude-agent-acp
      nvimPkgs.codex-acp
    ];

    plugins.codecompanion = {
      enable = true;

      # freeform settings, unchecked at eval time: a typo shows up as a missing feature in nvim
      settings = {
        # Workaround: with CLAUDE_CODE_OAUTH_TOKEN unset the adapter sends the variable's name
        # as the token, which outranks the subscription login. Returning nil drops the key.
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

        # `chat-gpt` auth uses the login in ~/.codex instead of an API key
        adapters.acp.codex.__raw = ''
          function()
            return require("codecompanion.adapters").extend("codex", {
              defaults = {
                auth_method = "chat-gpt",
              },
              env = {
                OPENAI_API_KEY = function()
                  return nil
                end,
              },
            })
          end
        '';

        interactions = {
          # models unset: each subscription advertises its own
          chat.adapter = "claude_code";
          inline.adapter = "copilot";

          # Generates a single ex command into the cmdline. Cheapest task here.
          cmd.adapter = "copilot";

          cli = {
            agent = "claude_code";

            # bare PATH lookup: the binary in ~/.local/bin holds the subscription login
            agents.claude_code = {
              cmd = "claude";
              description = "Claude Code CLI";
              provider = "terminal";
            };
          };
        };

        # join the <leader>p pickers in telescope.nix
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

      # a second chat; the first stays open
      {
        mode = "n";
        key = "<leader>cnc";
        action = "<cmd>CodeCompanionChat<CR>";
        options.desc = "[C]odeCompanion [n]ew [c]hat";
      }

      # Fullscreen toggle: move the chat window to its own tab and back, leaving the splits intact
      {
        mode = "n";
        key = "<leader>cf";
        action.__raw = ''
          function()
            local function find_chat()
              -- current tab first
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
                -- tabclose destroys the window, so re-open the chat
                return vim.cmd("CodeCompanionChat Toggle")
              end
              -- only window in the only tab: already fullscreen
              return
            end

            vim.api.nvim_set_current_win(win)
            vim.cmd("wincmd T")
          end
        '';
        options.desc = "[C]odeCompanion chat [f]ullscreen toggle";
      }

      # add the selection to the chat, under a `from <path> (lines N-M):` header
      {
        mode = "v";
        key = "<leader>cb";
        action.__raw = addSelection false;
        options.desc = "[C]odeCompanion add selection to chat [b]uffer";
      }

      # the same, into a new chat
      {
        mode = "v";
        key = "<leader>cnb";
        action.__raw = addSelection true;
        options.desc = "[C]odeCompanion selection to [n]ew chat [b]uffer";
      }

      # visual mode: the selection; normal mode: the whole buffer
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
        # focus = false keeps the cursor in place
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

{ ... }:
{

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
  programs.zed-editor = {
    enable = true;

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "super-f" = "terminal_panel::Toggle";

          # Project tree.
          "ctrl-shift-e" = "project_panel::ToggleFocus";

          # Agent panel.
          "super-a" = "agent::ToggleFocus";
          "super-shift-a" = "agent::NewThread";
          "alt-a" = "agent::Toggle";
        };
      }

      # From the editor: reveal the current file in the project tree.
      {
        context = "!AcpThread > Editor && mode == full";
        bindings = {
          "ctrl-shift-e" = "pane::RevealInProjectPanel";
        };
      }

      # Keyboard-first project tree navigation.
      {
        context = "ProjectPanel && not_editing";
        bindings = {
          # Vim-style movement in the project tree.
          "h" = "project_panel::CollapseSelectedEntry";
          "j" = "menu::SelectNext";
          "k" = "menu::SelectPrevious";
          "l" = "project_panel::ExpandSelectedEntry";

          # Open selected file/directory.
          "o" = "project_panel::Open";
          "enter" = "project_panel::Open";

          "i" = "workspace::FocusCenterPane";

          # File operations.
          "r" = "project_panel::Rename";
          "a" = "project_panel::NewFile";
          "shift-a" = "project_panel::NewDirectory";
          "/" = "file_finder::Toggle";
        };
      }

      # Agent panel bindings.
      {
        context = "AgentPanel";
        bindings = {
          "super-shift-a" = "agent::NewThread";
          "super-a" = "agent::ToggleFocus";
          "alt-a" = "agent::Toggle";
        };
      }

      # Agent thread/editor bindings.
      {
        context = "AcpThread > Editor";
        bindings = {
          "ctrl-enter" = "agent::ChatWithFollow";
          "ctrl-shift-enter" = "agent::SendImmediately";
          "ctrl-alt-p" = "agent::ManageProfiles";
          "ctrl-alt-l" = "agent::ManageSkills";
          "ctrl-alt-/" = "agent::ToggleModelSelector";
          "ctrl-i" = "agent::ToggleProfileSelector";
          "ctrl-f" = "agent::ToggleSearch";
        };
      }
    ];

    userSettings = {
      theme = {
        mode = "system";
        dark = "Ayu Mirage";
        light = "Ayu Light";
      };
      preview_tabs = {
        enabled = true;
        enable_preview_from_file_finder = true;
      };
      hour_format = "hour24";
      vim_mode = true;
      vim = {
        toggle_relative_line_numbers = true;
      };
      project_panel = {
        auto_reveal_entries = true;
        auto_fold_dirs = false;
      };
    };
  };
}

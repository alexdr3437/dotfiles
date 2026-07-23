# Zed Keyboard Navigation Cheatsheet

Personal notes for using Zed without reaching for the mouse, especially for navigating the project directory tree and interacting with the Agent panel.

## Project Tree / Project Panel

The goal is to use the Project Panel like a keyboard-driven file tree, while keeping directory context visible.

### Core Workflow

From an editor buffer:

| Shortcut | Action |
| --- | --- |
| `Ctrl+Shift+E` | Reveal/focus the current file in the Project Panel |
| `Ctrl+B` | Toggle the left dock/project panel visibility |

Once inside the Project Panel:

| Shortcut | Action |
| --- | --- |
| `j` | Move selection down |
| `k` | Move selection up |
| `h` | Collapse selected folder |
| `l` | Expand selected folder |
| `o` | Open selected file |
| `Enter` | Open selected file |
| `Space` | Open selected file, Zed default |
| `r` | Rename selected file/folder |
| `a` | Create new file |
| `Shift+A` | Create new directory |
| `F2` | Rename, Zed default |
| `Delete` / `Backspace` | Trash selected file/folder |
| `Ctrl+C` | Copy selected file/folder |
| `Ctrl+X` | Cut selected file/folder |
| `Ctrl+V` | Paste file/folder |
| `Ctrl+Left` | Collapse all entries |
| `Ctrl+Right` | Expand all entries |

### Useful Project Panel Settings

```nix
project_panel = {
  # Keep the project tree synced to the currently active file.
  auto_reveal_entries = true;

  # Show the actual directory hierarchy instead of compressing
  # one-child directory chains.
  auto_fold_dirs = false;
};
```

## Agent Panel / AI Chat

Useful shortcuts for interacting with the Zed Agent panel.

### Recommended Personal Bindings

These are not all default Zed bindings; these are intended custom bindings.

| Shortcut | Action |
| --- | --- |
| `Super+A` | Toggle/focus the Agent panel |
| `Super+Shift+A` | Open a fresh Agent chat/thread |
| `Super+Alt+A` | Toggle Agent panel visibility |
| `Ctrl+Enter` | Send message / chat, when focused in the Agent message editor |
| `Ctrl+Shift+Enter` | Send immediately, when focused in Agent thread editor |
| `Ctrl+Alt+P` | Manage Agent profiles |
| `Ctrl+Alt+L` | Manage Agent skills |
| `Ctrl+Alt+/` | Toggle Agent model selector |
| `Ctrl+I` | Toggle Agent profile selector |
| `Ctrl+F` | Search inside the current Agent thread, when Agent thread is focused |

### Zed Default Agent-ish Shortcuts

From the workspace:

| Shortcut | Action |
| --- | --- |
| `Ctrl+?` | Toggle focus to the Agent panel |

Inside the Agent panel/thread:

| Shortcut | Action |
| --- | --- |
| `Ctrl+N` | New Agent thread |
| `Ctrl+F` | Search current Agent thread |
| `Ctrl+Alt+P` | Manage profiles |
| `Ctrl+Alt+L` | Manage skills |
| `Ctrl+Alt+/` | Toggle model selector |
| `Ctrl+I` | Toggle profile selector |
| `Shift+Tab` | Cycle session mode |
| `Alt+L` | Cycle favorite models |
| `Ctrl+Enter` | Chat/send, depending on Agent input mode |
| `Ctrl+Shift+Enter` | Send immediately |
| `Ctrl+Shift+Backspace` | Remove first queued message |
| `Ctrl+Alt+E` | Edit first queued message |
| `Ctrl+Alt+S` | Toggle steering for first queued message |
| `Ctrl+Alt+Backspace` | Clear message queue |
| `Ctrl+Shift+V` | Paste raw |

## Notes

- `Ctrl+Shift+E` is the main project-tree workflow:
  1. Start in a file.
  2. Press `Ctrl+Shift+E`.
  3. Zed reveals that file in the Project Panel.
  4. Use `h/j/k/l` to move around the surrounding directory context.

- For projects with many files named `mod.rs`, this is much better than fuzzy-finding by filename alone.

- `agent::ToggleFocus` is best for jumping to/from the Agent panel.
- `agent::Toggle` is best for showing/hiding the Agent panel.
- `agent::NewThread` starts a fresh Agent chat/thread.
`

{ inputs, pkgs, ... }:
# Voice dictation: hex (github:anomalyco/hex), local-first, replaced voxtype.
#
# One `hex service` per user, started with graphical-session.target by hex's
# home-manager module. Transcription runs through transcribe.cpp's Vulkan
# backend; ggml picks the discrete GPU when there is one, so on the desktop it is
# the RTX 4060 (set GGML_VK_VISIBLE_DEVICES=<index> in the service environment if
# it ever lands on the Intel iGPU). The window (settings, history) needs a Vulkan
# driver too; modules/nvidia.nix provides it.
#
# Shortcuts: mango has no GlobalShortcuts portal, so hex gets its keys from
# config.conf (files/dotfiles/mango): hold Ctrl+Super to dictate, Escape while
# holding cancels. The binds run `hex dictation start|stop|cancel`, which only
# talk to the running service. Paste goes through wtype (virtual keyboard
# protocol); hex reads no input devices, so no uinput, udev rule or input group.
#
# Models live in ~/.local/share/hex, downloaded by the hex-model user service on
# first login (installModel). `hex` opens the window, `hex model list` the models,
# `journalctl --user -u hex` the log.
#
# inputs.hex.nixosModules.hex is not imported: `inputs` is a _module.args here
# (flake.nix), and an import that depends on it is an infinite recursion. The
# module only adds the package anyway. Home-manager gets inputs as a specialArg.
let
  hex = inputs.hex.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home-manager.users.alex =
    { inputs, ... }:
    {
      imports = [ inputs.hex.homeManagerModules.hex ];

      # Fixed upstream in hex 5edf737 (rune 4f6a53cb, hex PR #1162); the limit stays as headroom.
      # hex leaked 3 file descriptors per dictation (3.1.0 and 3.3.0): each wtype paste
      # makes mango resend wl_keyboard keymaps (wtype's, then ours twice) and hex never
      # closes the fds. At the default 1024 soft limit the window died after ~320
      # dictations ("Too many open files") while the service kept running without it,
      # so the indicator and window were gone until a restart. 65536 is ~21,000
      # dictations. Check with: ls /proc/$(systemctl --user show -p MainPID --value hex)/fd | wc -l
      systemd.user.services.hex.Service.LimitNOFILE = 65536;

      programs.hex = {
        enable = true;
        package = hex;
        autostart = true;
        # Cohere Transcribe (2.4 GB, 14 languages): fewer errors than Parakeet on hex's English
        # benchmark (1.27 % vs 1.60 % word error rate). It does not
        # stream, so the whole clip is transcribed after release and Labs › Live text shows
        # nothing; parakeet_unified_en is the streaming one. Activation (every switch and
        # boot) re-applies this, so a model picked in the window lasts until then.
        model = "cohere_transcribe";
        installModel = true;
        # Applied on every switch and boot (`hex settings apply`); app rules made in the window that
        # are not declared here are replaced, since the whole list is one setting.
        # Terminal: lowercase in ghostty, a built-in string step. No model: a mode only
        # rewrites with one when its post_processing is enabled, and omitted means off. Hex
        # names a Wayland app after its .desktop entry, so both spellings are listed.
        settings."dictation_processing.modes" = [
          {
            name = "Terminal";
            applications = [
              "Ghostty"
              "com.mitchellh.ghostty"
            ];
            transformations = [ "lowercase" ];
          }
        ];
      };
    };
}

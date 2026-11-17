{ inputs, pkgs, ... }:
# Voice dictation: hex (github:anomalyco/hex), local, on the GPU through Vulkan.
# Keys are bound in mango's config.conf (hold Ctrl+Super); it pastes with wtype.
# hex's NixOS module is not imported: it needs `inputs`, an infinite recursion here.
let
  hex = inputs.hex.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home-manager.users.alex =
    { inputs, ... }:
    {
      imports = [ inputs.hex.homeManagerModules.hex ];

      # headroom: hex before 5edf737 leaks fds on every dictation
      systemd.user.services.hex.Service.LimitNOFILE = 65536;

      programs.hex = {
        enable = true;
        package = hex;
        autostart = true;
        # most accurate English model; not streaming (parakeet_unified_en is)
        model = "cohere_transcribe";
        installModel = true;
        # lowercase in ghostty; hex may report either app name
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

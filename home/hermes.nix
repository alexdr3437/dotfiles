{
  config,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.services.hermes-agent;
  upstream = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Nix supplies the dependencies. Do not reuse receipts/binaries left by
  # `hermes setup` in ~/.hermes/tools: they belong to a different installer.
  runtime = upstream.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      mkdir -p "$out/tools"
      for command in hermes hermes-agent hermes-acp; do
        wrapProgram "$out/bin/$command" \
          --set HERMES_RUNTIME_DIR "$out/tools"
      done
    '';
  });

  desktop = runtime.hermesDesktop.override {
    extraEnv = {
      HERMES_HOME = cfg.hermesHome;
      HERMES_MANAGED = "home-manager";
    };
  };

  # Upstream's `hermes desktop` tries to build a source checkout. Nix ships
  # the already-built Electron application as a separate derivation instead.
  cli = pkgs.symlinkJoin {
    name = "hermes-nix";
    paths = [ runtime ];
    postBuild = ''
      rm "$out/bin/hermes"
      ln -s ${pkgs.writeShellScript "hermes" ''
        case "''${1-}" in
          desktop|gui)
            shift
            exec ${desktop}/bin/hermes-desktop "$@"
            ;;
          *) exec ${runtime}/bin/hermes "$@" ;;
        esac
      ''} "$out/bin/hermes"
    '';
  };
in
{
  imports = [ inputs.hermes-agent.homeManagerModules.default ];

  programs.hermes-agent = {
    enable = true;
    package = cli;
    desktop = {
      enable = true;
      package = desktop;
    };
  };

  services.hermes-agent = {
    enable = true;
    package = runtime;
    workingDirectory = config.home.homeDirectory;
    # The desktop starts its own backend; no always-on messaging daemon.
    gateway.enable = false;
    backend.mode = "none";

    settings = {
      # Schema version of the pinned Hermes input. Review when updating it.
      _config_version = 49;
      agent = {
        max_turns = 150;
        reasoning_effort = "medium";
      };
      model = {
        provider = "openai-codex";
        base_url = "https://chatgpt.com/backend-api/codex";
        default = "gpt-5.6-sol";
      };
      terminal = {
        backend = "local";
        cwd = config.home.homeDirectory;
      };
      web.backend = "brave-free";
      browser.backend = "browser-use";
      computer_use.backend = "cua";
      platform_toolsets.cli = [
        "browser"
        "clarify"
        "code_execution"
        "computer_use"
        "connections"
        "cronjob"
        "delegation"
        "file"
        "image_gen"
        "memory"
        "session_search"
        "skills"
        "terminal"
        "todo"
        "tts"
        "vision"
        "web"
      ];
      telemetry.shared_metrics = {
        enabled = false;
        send = false;
      };
    };

    # Replace rather than merge on activation: Nix is the configuration's
    # source of truth, including removal of settings. This remains writable
    # for Hermes, but runtime edits are reset by the next rebuild.
    configFile = (pkgs.formats.yaml { }).generate "hermes-config.yaml" cfg.settings;

    # OAuth tokens stay in ~/.hermes/auth.json and can refresh normally.
    # Never put credentials in settings, authFile, or the world-readable store.
  };
}

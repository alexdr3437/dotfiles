{ lib, pkgs, ... }:
let
  # libsystemd for the idle check (logind IdleHint, set by swayidle); the patch makes
  # --on-idle=true parse. Options only seed a fresh state dir: later changes go through Web Control.
  fahclient = pkgs.fahclient.override {
    stdenv = pkgs.stdenvAdapters.overrideMkDerivationArgs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.systemdLibs ];
      patches = (old.patches or [ ]) ++ [ ./fah-client-on-idle-option.patch ];
    }) pkgs.stdenv;
  };
  user = "foldingathome";
  stateDir = "/var/lib/foldingathome";
in
{
  # Folds on the RTX 4060. One-time setup in Web Control (https://app.foldingathome.org):
  # enable the GPU and set the machine to Fold.
  services.foldingathome = {
    enable = true;
    package = fahclient;
    # team: nixpkgs defaults to the NixOS team (236565); user: null = Anonymous.
    extraArgs = [
      # one thread to feed the GPU, no CPU-only units
      "--cpus=1"
      "--on-idle=true"
      # logs go to the journal
      "--log-color=false"
    ];
  };

  # systemd 260 mounts a non-root StateDirectory noexec, so the downloaded cores cannot run.
  # Use a plain directory and a static user instead, with upstream's hardening.
  users.users.${user} = {
    isSystemUser = true;
    group = user;
  };
  users.groups.${user} = { };
  systemd.tmpfiles.rules = [ "Z ${stateDir} 0750 ${user} ${user} -" ];
  systemd.services.foldingathome.serviceConfig = {
    DynamicUser = lib.mkForce false;
    StateDirectory = lib.mkForce "";
    WorkingDirectory = lib.mkForce stateDir;
    User = user;
    Group = user;
    ProtectSystem = "full";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
  };

  # let the client inhibit sleep while folding (keep_awake)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.inhibit-block-sleep" &&
          subject.user == "${user}")
        return polkit.Result.YES;
    });
  '';
}

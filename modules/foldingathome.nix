{ lib, pkgs, ... }:
let
  # fah-client (v8) can fold only while the machine is idle: on Linux that reads
  # logind's seat IdleHint over sd-bus, which swayidle sets after `hint_min` minutes
  # (idle.sh in ~/.config/mango). nixpkgs builds the client without libsystemd, so the
  # check is compiled out and "on idle" would never start; add the library back. The
  # patch makes `--on-idle=true` land as a boolean (upstream inserts it as a number and
  # then drops it with "wrong type").
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
  # Folding@home on the RTX 4060 (the desktop runs on the iGPU). GPU folding is
  # OpenCL/CUDA inside the client's FHS sandbox; /run/opengl-driver is bind-mounted
  # into it so the nvidia libraries are found without extra wiring.
  #
  # One-time setup in Web Control (https://app.foldingathome.org, it talks to
  # 127.0.0.1:7396): enable the GPU, set the machine to Fold, and optionally link an
  # account / set a username. Those choices are stored in /var/lib/foldingathome and
  # override the defaults below from then on.
  services.foldingathome = {
    enable = true;
    package = fahclient;
    # team: nixpkgs defaults to the NixOS team (236565); user: null = Anonymous.
    extraArgs = [
      # one CPU thread feeds the GPU work unit and nothing is left for CPU-only units
      "--cpus=1"
      # fold only while logind says the seat is idle (see idle.sh); Web Control can toggle it
      "--on-idle=true"
      # logs go to the journal
      "--log-color=false"
    ];
  };

  # The client downloads the folding cores (FahCore_xx) into its state directory and
  # executes them from there. systemd 260 exposes a StateDirectory= of a non-root
  # service through an idmapped mount with noexec (DynamicUser or not), so every core
  # fails to start with exit code 255. Hand the service a plain directory instead:
  # tmpfiles creates it (Z also chowns what the StateDirectory era left owned by
  # nobody) and the unit runs as a static system user, as upstream's unit does, with
  # upstream's hardening in place of what DynamicUser implied.
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

  # keep_awake (on by default) asks logind to inhibit sleep while folding; without this
  # rule polkit refuses it for a system user and the client logs an exception per WU.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.login1.inhibit-block-sleep" &&
          subject.user == "${user}")
        return polkit.Result.YES;
    });
  '';
}

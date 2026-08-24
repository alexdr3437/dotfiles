{ pkgs, ... }:
let
  wispr-flow = pkgs.appimageTools.wrapType2 {
    pname = "wispr-flow";
    version = "1.6.7-1.0.3";

    src = pkgs.fetchurl {
      url = "https://github.com/wispr-flow-linux/wispr-flow-linux/releases/download/v1.0.3%2Bwispr1.6.7/wispr-flow-1.6.7-1.0.3-x86_64.AppImage";
      hash = "sha256-T9/evAykYnc20TVc7sX3Bwf8aTkTkxEtDr8FNavIMfA=";
    };
  };
in
{
  environment.systemPackages = [
    wispr-flow
  ];

  systemd.user.services.wispr-flow = {
    description = "Wispr Flow";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];

    serviceConfig = {
      ExecStart = "${wispr-flow}/bin/wispr-flow";
      Restart = "always";
      RestartSec = 2;
    };
  };
}

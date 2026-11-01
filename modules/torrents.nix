{ pkgs, ... }:

let
  user = "alex";
  mediaRoot = "/srv/media";

  # The desktop app and the headless service share one profile, and qBittorrent runs one
  # instance per profile: started while the service runs, the app just hands over to it and
  # exits. So `qbittorrent` (launcher, command line, magnet links) stops the service, runs the
  # app, which serves the same web UI on :8080 from the profile, and starts the service again
  # when the app exits. A second launch while the app is open goes straight to it.
  qbittorrentLauncher = pkgs.writeShellApplication {
    name = "qbittorrent";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      umask 002
      if ! systemctl is-active --quiet qbittorrent-nox.service; then
        exec ${pkgs.qbittorrent}/bin/qbittorrent "$@"
      fi
      systemctl stop qbittorrent-nox.service
      trap 'systemctl start qbittorrent-nox.service' EXIT
      trap 'exit 1' HUP INT TERM
      ${pkgs.qbittorrent}/bin/qbittorrent "$@"
    '';
  };

  qbittorrentDesktop = pkgs.symlinkJoin {
    name = "qbittorrent-desktop";
    paths = [ pkgs.qbittorrent ];
    postBuild = ''
      rm "$out/bin/qbittorrent"
      ln -s ${qbittorrentLauncher}/bin/qbittorrent "$out/bin/qbittorrent"
    '';
  };

  qbtImportMovie = pkgs.writeShellApplication {
    name = "qbt-import-movie";

    runtimeInputs = with pkgs; [
      coreutils
      findutils
    ];

    text = ''
      set -euo pipefail

      category="$1"
      content_path="$2"
      torrent_name="$3"

      [ "$category" = "movies" ] || exit 0

      completed_root="${mediaRoot}/torrents"
      movies_root="${mediaRoot}/Movies"

      content_path="$(realpath -e "$content_path")"

      case "$content_path" in
        "$completed_root"/*) ;;
        *)
          printf 'Refusing source outside %s: %s\n' "$completed_root" "$content_path" >&2
          exit 1
          ;;
      esac

      safe_name="$(printf '%s' "$torrent_name" | tr '/\n\r' '___')"

      case "$safe_name" in
        ""|"."|"..") exit 1 ;;
      esac

      is_video() {
        case "$1" in
          *.mkv|*.mp4|*.m4v|*.avi|*.webm|*.MKV|*.MP4|*.M4V|*.AVI|*.WEBM) return 0 ;;
          *) return 1 ;;
        esac
      }

      source_file=""
      largest_size=-1

      choose_video() {
        candidate="$1"
        is_video "$candidate" || return 0

        size="$(stat -c '%s' "$candidate")"

        if [ "$size" -gt "$largest_size" ]; then
          source_file="$candidate"
          largest_size="$size"
        fi
      }

      if [ -f "$content_path" ]; then
        choose_video "$content_path"
      else
        while IFS= read -r -d $'\0' candidate; do
          choose_video "$candidate"
        done < <(find "$content_path" -type f -print0)
      fi

      [ -n "$source_file" ] || exit 0

      destination_dir="$movies_root/$safe_name"
      mkdir -p "$destination_dir"

      extension="''${source_file##*.}"
      destination_file="$destination_dir/$safe_name.$extension"

      if [ -e "$destination_file" ]; then
        [ "$source_file" -ef "$destination_file" ] && exit 0
        printf 'Destination already exists: %s\n' "$destination_file" >&2
        exit 1
      fi

      ln "$source_file" "$destination_file"
    '';
  };
in
{
  users.groups.media = { };

  users.users.${user}.extraGroups = [ "media" ];
  users.users.sonarr.extraGroups = [ "media" ];

  services.jellyfin = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  services.sonarr = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  environment.systemPackages = [
    qbittorrentDesktop
    qbtImportMovie
  ];

  # Headless qBittorrent from boot, sharing the GUI's profile in ~alex (web UI
  # on :8080, https://torrent.home). It is bound to proton0 in its own settings,
  # so it stays offline until Proton connects.
  systemd.services.qbittorrent-nox = {
    description = "qBittorrent (headless)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      User = user;
      UMask = "0002";
      ExecStart = "${pkgs.qbittorrent-nox}/bin/qbittorrent-nox";
      Restart = "on-failure";
    };
  };

  # lets the qbittorrent wrapper above stop and start the service without a password
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "qbittorrent-nox.service" &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.user == "${user}") {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 2775 ${user} media -"
    "d ${mediaRoot}/torrents 2775 ${user} media -"
    "d ${mediaRoot}/Movies 2775 ${user} media -"
    "d ${mediaRoot}/Shows 2775 ${user} media -"
  ];
}

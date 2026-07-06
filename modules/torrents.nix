{ pkgs, ... }:

let
  user = "alex";
  mediaRoot = "/srv/media";

  qbittorrentWithUmask = pkgs.symlinkJoin {
    name = "qbittorrent-with-umask";
    paths = [ pkgs.qbittorrent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      rm "$out/bin/qbittorrent"
      makeWrapper ${pkgs.qbittorrent}/bin/qbittorrent "$out/bin/qbittorrent" \
        --run 'umask 002'
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
    qbittorrentWithUmask
    qbtImportMovie
  ];

  systemd.tmpfiles.rules = [
    "d ${mediaRoot} 2775 ${user} media -"
    "d ${mediaRoot}/torrents 2775 ${user} media -"
    "d ${mediaRoot}/Movies 2775 ${user} media -"
    "d ${mediaRoot}/Shows 2775 ${user} media -"
  ];
}

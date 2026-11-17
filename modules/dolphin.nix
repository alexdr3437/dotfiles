{ pkgs, ... }:
{
  # Dolphin outside Plasma, plus what it needs from a desktop
  environment.systemPackages = with pkgs.kdePackages; [
    dolphin
    dolphin-plugins # git / mercurial status in the view
    kio-extras # sftp:, smb:, trash:, thumbnails for images and documents
    kio-fuse # non-KIO apps can open files from remote kio locations
    ffmpegthumbs # video thumbnails
    kdegraphics-thumbnailers # pdf / dvi / raw thumbnails
    breeze-icons # icon theme KDE apps expect
    qtsvg # svg icons
    ark # archives, and Dolphin's Extract/Compress menu
  ];

  # folders open in Dolphin, archives in Ark
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
  }
  // builtins.listToAttrs (
    map
      (t: {
        name = "application/${t}";
        value = "org.kde.ark.desktop";
      })
      [
        "zip"
        "x-7z-compressed"
        "x-tar"
        "x-compressed-tar"
        "x-bzip2-compressed-tar"
        "x-xz-compressed-tar"
        "x-zstd-compressed-tar"
        "gzip"
        "x-rar"
        "vnd.rar"
      ]
  );

  # Qt apps read kdeglobals and use the breeze style
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  # drop the stale .desktop cache (ksycoca) on activation and at session start (nixpkgs #292632)
  system.userActivationScripts.rebuildSycoca = ''
    rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/ksycoca"*
  '';
  systemd.user.services.nixos-rebuild-sycoca = {
    description = "Drop the KDE service cache (ksycoca) so it is rebuilt from the current system";
    wantedBy = [ "graphical-session-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      rm -f "''${XDG_CACHE_HOME:-$HOME/.cache}/ksycoca"*
    '';
  };

  # kbuildsycoca needs an applications.menu for "Open with"
  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <Include><All/></Include>
    </Menu>
  '';
}

{ pkgs, ... }:
{
  # Dolphin as the file manager, without Plasma (modules/kde.nix is gone).
  # Outside Plasma it needs a few things the desktop used to provide:
  # KIO workers + thumbnailers, an icon theme for its own UI, the Qt platform
  # theme that makes it read ~/.config/kdeglobals (colours, fonts, the
  # ghostty TerminalApplication set there), and the service cache below.
  environment.systemPackages = with pkgs.kdePackages; [
    dolphin
    dolphin-plugins # git / mercurial status in the view
    kio-extras # sftp:, smb:, trash:, thumbnails for images and documents
    kio-fuse # non-KIO apps can open files from remote kio locations
    ffmpegthumbs # video thumbnails
    kdegraphics-thumbnailers # pdf / dvi / raw thumbnails
    breeze-icons # KDE apps' fallback icon theme; nothing else ships the names they use
    qtsvg # svg icons
  ];

  # Folders open in Dolphin. System-level default (/etc/xdg/mimeapps.list): the
  # user's ~/.config/mimeapps.list is written by apps registering their URL
  # handlers at runtime, so it stays theirs; it only wins where it sets a key.
  # Without this xdg-open picked zathura's comic-book entry for inode/directory.
  xdg.mime.defaultApplications."inode/directory" = "org.kde.dolphin.desktop";

  # breeze style + plasma-integration platform theme: Dolphin looks like itself and
  # honours kdeglobals. Any other Qt app (qbittorrent) follows suit.
  qt = {
    enable = true;
    platformTheme = "kde";
    style = "breeze";
  };

  # KDE apps look up "Open with" candidates and mime handlers in ksycoca, a cache
  # of the .desktop files. Store paths change on every switch, so drop the cache
  # on activation and at session start; it is rebuilt on first use. (Same hack
  # the plasma6 module uses, nixpkgs #292632.)
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

  # kbuildsycoca wants an applications.menu (Plasma ships plasma-applications.menu
  # and sets XDG_MENU_PREFIX). A minimal menu that includes every installed
  # .desktop file is enough for Dolphin's "Open with" dialog.
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

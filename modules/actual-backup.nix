{ pkgs, ... }:
{
  programs.ssh.extraConfig = ''
    Host actual-backup-linode
      HostName linode
      User restic
      IdentityFile /home/alex/.ssh/id_ed25519
      IdentitiesOnly yes
      UserKnownHostsFile /home/alex/.ssh/known_hosts
  '';

  services.restic.backups.actual = {
    initialize = true;
    repository = "sftp:actual-backup-linode:/srv/restic/actual";
    passwordFile = "/etc/restic/actual-password";
    paths = [ "/var/lib/private/actual" ];

    backupPrepareCommand = "${pkgs.systemd}/bin/systemctl stop actual.service";
    backupCleanupCommand = "${pkgs.systemd}/bin/systemctl start actual.service";

    extraBackupArgs = [ "--tag actual-budget" ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
    runCheck = true;
    checkOpts = [ "--read-data-subset=5%" ];

    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}

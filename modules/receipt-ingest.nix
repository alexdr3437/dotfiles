{ inputs, pkgs, ... }:
let
  package = inputs.receipt-ingest.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # The Syncthing folder the phone's scans land in (modules/syncthing.nix).
  receipts = "/home/alex/receipts";
  database = "/home/alex/.local/share/receipt-ingest/receipts.db";
in
{
  # `receipt-ingest view` to browse what has been recorded, `receipt-ingest process <pdf>`
  # to run one file by hand. It reads the same database by default.
  environment.systemPackages = [ package ];

  # Sends every `Scanned Document*.pdf` in ~/receipts to the model, records the result in
  # the database and renames the file, then exits. Runs as alex, like Syncthing, so the
  # files and the database stay plain user files, and so it works without a login session.
  systemd.services.receipt-ingest = {
    description = "Parse scanned receipts in ${receipts}";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    environment = {
      RECEIPT_DIR = receipts;
      RECEIPT_DB = database;
    };

    serviceConfig = {
      Type = "oneshot";
      User = "alex";
      Group = "users";
      ExecStart = "${package}/bin/receipt-ingest-service";
      # NOUS_API_KEY=... ; root-only, kept out of the world-readable store. Create it by hand:
      #   sudo install -d -m 700 /etc/receipt-ingest
      #   sudo install -m 600 /dev/null /etc/receipt-ingest/env && sudoedit /etc/receipt-ingest/env
      EnvironmentFile = "/etc/receipt-ingest/env";
    };
  };

  # Start the service when a file is created, renamed or removed in the folder. Syncthing
  # writes to a hidden temporary name and renames it into place, so this fires once the scan
  # is complete (path units ignore dot files).
  systemd.paths.receipt-ingest = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = receipts;
  };

  # Backstop: retries receipts that hit a temporary failure, and catches anything that
  # arrived in the instant between the service's last scan of the folder and its exit.
  systemd.timers.receipt-ingest = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}

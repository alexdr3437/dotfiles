{ inputs, pkgs, ... }:
let
  package = inputs.receipt-ingest.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Syncthing folder (modules/syncthing.nix)
  receipts = "/home/alex/receipts";
  database = "/home/alex/.local/share/receipt-ingest/receipts.db";
in
{
  # CLI: `receipt-ingest view`, `receipt-ingest process <pdf>`
  environment.systemPackages = [ package ];

  # parses new scans into the database and renames them; runs as alex, like Syncthing
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
      # NOUS_API_KEY=...; root-only (mode 600), created by hand
      EnvironmentFile = "/etc/receipt-ingest/env";
    };
  };

  # run when the folder changes (Syncthing renames finished files into place)
  systemd.paths.receipt-ingest = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = receipts;
  };

  # hourly backstop for failed and missed scans
  systemd.timers.receipt-ingest = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}

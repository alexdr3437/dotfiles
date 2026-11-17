{ ... }:
let
  # The device that holds `Receipts`, and that folder's ID there (not its label): both are
  # shown in the Syncthing app on that device.
  sourceDeviceId = "PKB7KAW-TLNVHEK-L3JNRT4-IYWCKJT-JRGCCCK-UQO4RBF-MYPMPOB-IDXMEQK";
  receiptsFolderId = "A3D5-E245";
in
{
  # Runs as alex so the files in ~/receipts are plain user files. Web GUI on 127.0.0.1:8384.
  services.syncthing = {
    enable = true;
    user = "alex";
    group = "users";
    dataDir = "/home/alex";
    configDir = "/home/alex/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      devices.receipts-source.id = sourceDeviceId;

      # Two-way: renames and deletions made here reach the source, and vice versa. The folder
      # has to be Send & Receive on the source too.
      folders.receipts = {
        id = receiptsFolderId;
        label = "Receipts";
        path = "/home/alex/receipts";
        type = "sendreceive";
        devices = [ "receipts-source" ];
      };
    };
  };
}

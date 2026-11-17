{ ... }:
let
  # device ID and folder ID (not the label), from the Syncthing app on the source device
  sourceDeviceId = "PKB7KAW-TLNVHEK-L3JNRT4-IYWCKJT-JRGCCCK-UQO4RBF-MYPMPOB-IDXMEQK";
  receiptsFolderId = "A3D5-E245";
in
{
  # runs as alex; web GUI on 127.0.0.1:8384
  services.syncthing = {
    enable = true;
    user = "alex";
    group = "users";
    dataDir = "/home/alex";
    configDir = "/home/alex/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      devices.receipts-source.id = sourceDeviceId;

      # the folder must be Send & Receive on the source too
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

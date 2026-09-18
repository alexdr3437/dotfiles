{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/linode-image.nix")
    ./default.nix
  ];

  virtualisation.diskSize = 4096;
}

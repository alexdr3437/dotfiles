{ lib, ... }:

# Short names like https://jellyfin.home for every tailnet device.
#
# dnsmasq answers *.home with this machine's Tailscale IP; Tailscale split DNS (admin console: nameserver
# 100.95.167.47, restricted to domain "home") sends those queries here. Caddy then routes each name to its
# service, using its own local CA.

let
  tailscaleIp = "100.95.167.47";
  homeAssistant = "100.108.62.20";

  services = {
    jellyfin = "localhost:8096";
    actual = "localhost:5006";
    sonarr = "localhost:8989";
    torrent = "localhost:8080";
    ha = "${homeAssistant}:8123";
  };
in
{
  services.dnsmasq = {
    enable = true;
    # Tailscale owns resolv.conf; don't put dnsmasq in front of it.
    resolveLocalQueries = false;
    settings = {
      interface = "tailscale0";
      except-interface = "lo";
      bind-dynamic = true;
      no-resolv = true;
      local = "/home/";
      address = "/home/${tailscaleIp}";
    };
  };

  services.caddy = {
    enable = true;
    globalConfig = ''
      skip_install_trust
    '';
    virtualHosts = lib.mapAttrs' (
      name: upstream:
      lib.nameValuePair "${name}.home" {
        extraConfig = ''
          tls internal
          reverse_proxy ${upstream}
        '';
      }
    ) services;
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [
      53
      80
      443
    ];
    allowedUDPPorts = [ 53 ];
  };
}

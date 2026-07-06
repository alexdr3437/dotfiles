{ pkgs, ... }:
{
  services.tailscale.enable = true;

  systemd.services.tailscale-proton-routes = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];

    path = [ pkgs.iproute2 ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      ip rule add pref 100 to 100.64.0.0/10 lookup 52 2>/dev/null || true
      ip -6 rule add pref 100 to fd7a:115c:a1e0::/48 lookup 52 2>/dev/null || true
    '';

    preStop = ''
      ip rule del pref 100 to 100.64.0.0/10 lookup 52 2>/dev/null || true
      ip -6 rule del pref 100 to fd7a:115c:a1e0::/48 lookup 52 2>/dev/null || true
    '';
  };
}

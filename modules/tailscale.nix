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

  # Proton's own packets, and traffic from its tunnel address (qBittorrent), bypass a
  # Tailscale exit node. The fwmark changes per connection, so read it on up.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "proton-bypass-tailscale" ''
        [ "$1" = proton0 ] || exit 0

        ip=${pkgs.iproute2}/bin/ip

        $ip rule del pref 5200 2>/dev/null || true
        while $ip -4 rule del pref 5201 2>/dev/null; do :; done
        while $ip -6 rule del pref 5201 2>/dev/null; do :; done

        if [ "$2" = up ]; then
          mark="$(${pkgs.wireguard-tools}/bin/wg show proton0 fwmark)"
          [ -n "$mark" ] && [ "$mark" != off ] || exit 0
          $ip rule add pref 5200 fwmark "$mark" lookup main

          table="$($ip rule | ${pkgs.gawk}/bin/awk -v m="$mark" '$0 ~ "not from all fwmark " m " lookup" {print $NF; exit}')"
          [ -n "$table" ] || exit 0

          for addr in $($ip -o addr show dev proton0 scope global | ${pkgs.gawk}/bin/awk '{print $4}'); do
            $ip rule add pref 5201 from "''${addr%/*}" lookup "$table"
          done
        fi
      '';
    }
  ];
}

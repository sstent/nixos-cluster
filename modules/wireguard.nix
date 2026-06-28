{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [ wireguard-tools nftables ];

  systemd.services.wireguard-wg0 = {
    description = "WireGuard via shared wg0.conf";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = with pkgs; [ nftables iproute2 iptables bash ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RequiresMountsFor = "/mnt/Public/config/wireguard";
      ExecStart = "${pkgs.wireguard-tools}/bin/wg-quick up /mnt/Public/config/wireguard/wg0.conf";
      ExecStop = "${pkgs.wireguard-tools}/bin/wg-quick down /mnt/Public/config/wireguard/wg0.conf";
    };
  };

  systemd.timers.wireguard-sync = {
    description = "Poll for WireGuard config changes every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "1m";
      Unit = "wireguard-sync.service";
    };
  };

  systemd.services.wireguard-sync = {
    description = "Sync WireGuard peers dynamically";
    after = [ "wireguard-wg0.service" ];
    bindsTo = [ "wireguard-wg0.service" ];
    path = with pkgs; [ nftables iproute2 iptables bash ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wireguard-tools}/bin/wg syncconf wg0 <(${pkgs.wireguard-tools}/bin/wg-quick strip /mnt/Public/config/wireguard/wg0.conf)'";
    };
  };
}

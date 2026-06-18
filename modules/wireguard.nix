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

  systemd.paths.wireguard-sync = {
    description = "Watch for WireGuard config changes";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathModified = "/mnt/Public/config/wireguard/wg0.conf";
    };
  };

  systemd.services.wireguard-sync = {
    description = "Sync WireGuard peers dynamically";
    path = with pkgs; [ nftables iproute2 iptables bash ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wireguard-tools}/bin/wg syncconf wg0 <(${pkgs.wireguard-tools}/bin/wg-quick strip /mnt/Public/config/wireguard/wg0.conf)'";
    };
  };
}

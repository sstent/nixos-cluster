{ config, pkgs, lib, ... }:
let
  espClusterManager = pkgs.writeShellScriptBin "esphome-cluster-manager" ''
    # Simple placeholder manager that creates sentinel file for systemd condition.
    # In a real setup, this would acquire a Consul lock before starting ESPhome.
    mkdir -p /run
    touch /run/esphome-cluster-leader
    exec ${pkgs.esphome}/bin/esphome $@
  '';
in{
  # Ensure data directory exists
  systemd.tmpfiles.rules = [ "d /mnt/esphome 0775 esphome esphome - -" ];

  services.esphome = {
    enable = true;
    configDir = "/mnt/esphome";
    # Prevent auto-start on boot; will be started by the cluster manager when lock held.
    wantedBy = lib.mkForce [];
    unitConfig.ConditionPathExists = "/run/esphome-cluster-leader";
  };

  # Cluster manager service (placeholder)
  systemd.services.esphome-cluster-manager = {
    description = "ESPhome Cluster Manager";
    after = [ "consul.service" "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${espClusterManager}/bin/esphome-cluster-manager";
      Restart = "always";
      RestartSec = 5;
      TimeoutStopSec = 60;
    };
  };
}

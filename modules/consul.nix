{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  # virtualisation.docker.enable = true;

  services.consul = {
    package = pkgs.consul_1_9;
    enable = true;
    webUi = true;
    extra_config = {
      bootstrap = false;
      bootstrap_expect = 7;
      encrypt = config.sops.secrets.consul_encrypt;
      performance = {
        raft_multiplier = 5;
      };
      recursors = [
        "192.168.1.1"
        "8.8.8.8"
      ];

      retry_join = [
        "192.168.1.221"
        "192.168.1.222"
        "192.168.1.225"
        "192.168.1.226"
        "192.168.1.227"
        "192.168.1.223"
        "192.168.1.224"
      ];
    };
  };
}

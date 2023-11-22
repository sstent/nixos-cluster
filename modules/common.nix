{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./mnt-public.nix
    ./mnt-clusterstore.nix
    ./nomad.nix
    ./consul.nix
    ./odroid-m1-setleds.nix
    ./odroid-m1.nix
    inputs.sops-nix.nixosModules.sops
  ];

  ##secretstore path variable
  options._secretstore = lib.mkOption {
    type = lib.types.str;
    default = "${inputs.self}/secrets";
    description = "Path to the Secrets storage";
  };

  config = {
    system.stateVersion = "23.11"; # Did you read the comment?

    sops = {
      defaultSopsFile = "${config._secretstore}/host-secrets.yaml";
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };

    # Enable nix flakes
    nix.package = pkgs.nixFlakes;
    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    environment.systemPackages = [
      pkgs.git
      pkgs.ncdu
      pkgs.killall
      pkgs.dig
    ];

    networking.search = ["node.dc1.consul" "service.dc1.consul"];
    # networking.firewall.enable = false;

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.extraUsers.root.initialPassword = lib.mkForce "odroid";
    users.users."root".openssh.authorizedKeys.keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAwn26AL26A0Yt4sE+rm5//p8QKuNGI/ezAdNJX9QAjRErjEWnsiUr+w0O78912A2RCakdZYZJo6p1RuLYq6u27mjdLU1hhJs1t/ZFUjevKP33Q8hjptnV3s/G/iPfl0h4kQDStNySgJJ7cGh8Dhj906BrQbns3U2WgVZWwhaYvFiSjZA9UWwvB+n/jN9YeSShfdqGYw8/WlFZiOZrz4poO6/DUOAiztvzrpaQFDtI2f9TdGL1ttvYk04jDCRO1cM1LjgWir+WToalgyAqxfgnlvbv8g16RQo//8qhRdMqQPJKnIRewy/VLN1VbNbO2+z5f6BYbYlfioDXmuzMb86jfQ== id_rsa"];
  };
}

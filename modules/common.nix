{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  imports = [
    ./mnt-public.nix
    ./nomad.nix
    ./odroid-m1-setleds.nix
    ./odroid-m1.nix
    # inputs.sops-nix.nixosModules.sops
  ];

  # ##secretstore path variable
  # options._secretstore = lib.mkOption {
  #   type = lib.types.str;
  #   default = "${inputs.self}/secrets";
  #   description = "Path to the Secrets storage";
  # };

  config = {
    system.stateVersion = "23.11"; # Did you read the comment?

    # sops = {
    #   defaultSopsFile = "${config._secretstore}/host-secrets.yaml";
    #   age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    # };

  # Enable nix flakes
  nix.package = pkgs.nixFlakes;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

    environment.systemPackages = [
      pkgs.git
      pkgs.ncdu
    ];

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.extraUsers.root.initialPassword = lib.mkForce "odroid";
  }
  ;
}

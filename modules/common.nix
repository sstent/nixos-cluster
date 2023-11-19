{ lib, pkgs, config, inputs,  ... }: {
  
            imports = [
            ./mnt-public.nix
            ./nomad.nix
            ./odroid-m1-setleds.nix
            ./odroid-m1.nix
          ];



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
{
  description = "nix-configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = github:Mic92/sops-nix;
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    ...
  } @ inputs: let
    globalModules = [
      {
        system.configurationRevision = self.rev or self.dirtyRev or null;
      }
      ./modules/common.nix
    ];
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;
    nixosConfigurations = {
      odroid5 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/odroid5];
      };
      odroid6 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/odroid6];
      };
      odroid7 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/odroid7];
      };
      odroid8 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/odroid8];
      };
      opti1 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/opti1];
      };
      opti2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/opti2];
      };
      opti3 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs;};
        modules =
          globalModules
          ++ [./hosts/opti3];
      };
      iso-optiplex = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ pkgs, ... }: {
            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIfbw6iQZOe3SSRY2dysVZhWb3wHrZRXHMLscUfh4tfM sstent@nixos"
            ];
            environment.systemPackages = with pkgs; [ git just sops ];
          })
        ];
      };
      rpi3 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          {
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
          ./hosts/rpi3
        ];
      };
      sd-rpi3 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {inherit inputs;};
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          {
            system.configurationRevision = self.rev or self.dirtyRev or null;
          }
          ./hosts/rpi3
        ];
      };
    };
  };
}

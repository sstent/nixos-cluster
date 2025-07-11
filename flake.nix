{
  description = "nix-configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = github:Mic92/sops-nix;
  };

  outputs = {
    self,
    nixpkgs,
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
    };
  };
}

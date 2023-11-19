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
      odroid8 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        extraSpecialArgs = { inherit inputs outputs lib;};
        modules =
          globalModules
          ++ [./hosts/odroid8];
      };
    };
  };
}

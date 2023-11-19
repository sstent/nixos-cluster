{
  description = "nix-configurations";

   inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nix-darwin, agenix, home-manager, ... }@inputs: 
  let 
    globalModules = [ 
      { 
        system.configurationRevision = self.rev or self.dirtyRev or null; 
      }
      ./default.nix 
    ];
  in
  {
    nixosConfigurations = {
      odroid8 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = globalModules
          ++ [ ./hosts/odroid8.nix ];
      };
    };

  };
}

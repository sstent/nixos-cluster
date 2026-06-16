deploy NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul switch 

deploy-debug NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --show-trace --verbose --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul switch 

deploy-dry NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul dry-activate

deploy-all: 
    just deploy opti1
    just deploy odroid6
    just deploy odroid7 odroid6
    just deploy odroid8 odroid6

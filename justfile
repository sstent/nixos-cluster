deploy NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul switch 

deploy-debug NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --show-trace --verbose --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul switch 

deploy-dry NODE BUILD_HOST=NODE: 
	nix run nixpkgs#nixos-rebuild -- --flake .#{{NODE}} --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{BUILD_HOST}}.node.dc1.consul dry-activate

deploy-all: 
	just deploy opti1
	just deploy opti2
	just deploy opti3
	just deploy odroid6
	just deploy odroid7
	just deploy odroid8

# Edit encrypted host secrets in $EDITOR
secrets-edit FILE="secrets/host-secrets.yaml":
	sops {{FILE}}

# View decrypted host secrets
secrets-view FILE="secrets/host-secrets.yaml":
	sops -d {{FILE}}

# Re-encrypt secrets with updated keys from .sops.yaml
secrets-updatekeys FILE="secrets/host-secrets.yaml":
	sops updatekeys -y {{FILE}}

# Rotate data encryption key for secrets file
secrets-rotate FILE="secrets/host-secrets.yaml":
	sops rotate -i {{FILE}}

deploy NODE: 
	nixos-rebuild --flake .#{{NODE}} --fast --target-host root@{{NODE}}.node.dc1.consul --build-host root@{{NODE}}.node.dc1.consul switch 

deploy-all: 
    just deploy odroid5
    just deploy odroid6
    just deploy odroid7
    just deploy odroid8

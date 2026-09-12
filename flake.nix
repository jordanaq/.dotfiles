{
  description = "tsiru-cloud — server-only fork of ~/.dotfiles (branch: server)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The public personal site (Zola source + build) served at the apex
    # domain. github.com/jordanaq/tsiru-pet — public, so the box can fetch it
    # over HTTPS with no credentials. Its own package output is the built
    # static site; system/caddy.nix serves it.
    tsiru-pet = {
      url = "git+https://github.com/jordanaq/tsiru-pet?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # rocmSupport intentionally NOT set (no GPU)
      };
    in {
      nixosConfigurations.tsiru-cloud = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./system/configuration.nix
        ];
      };

      homeConfigurations.tsiru = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./user/home.nix
        ];
        extraSpecialArgs = { inherit inputs; inherit system; };
      };
    };
}

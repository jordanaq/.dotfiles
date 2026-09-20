{
  description = "tsiru-cloud — server-only fork of ~/.dotfiles (branch: server)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Public personal site (Zola). Repo is public, so the box can fetch it over
    # HTTPS with no credentials; its package output is the built site (served by caddy).
    tsiru-pet = {
      url = "git+https://github.com/jordanaq/tsiru-pet?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Quartz v5, the notes.<domain> static-site generator. Pinned by flake.lock
    # (not ?ref=main) for reproducibility; flake = false (used as a source tree).
    quartz = {
      url = "github:jackyzha0/quartz";
      flake = false;
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
      # Lets you `nix build .#collabora-code` independently of the machine build,
      # to verify the CODE AppImage wrapper before a full nixos-rebuild switch.
      packages.${system}.collabora-code =
        pkgs.callPackage ./system/office/collabora-code.nix { };

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

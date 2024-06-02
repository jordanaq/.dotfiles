{
  description = "Entrypoint flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    catppuccin.url = "github:catppuccin/nix";
  };

  outputs = inputs@{ self, nixpkgs, catppuccin, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      nix-colors = import nix-colors;
      hyprland = import hyprland;
    in {
    nixosConfigurations = {
      tsiru-nixos = lib.nixosSystem {
        inherit system;

        modules = [
          ./system/configuration.nix
          ./system/audio/default.nix
        ];

      };
    };

    homeConfigurations = {
      tsiru = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./user/home.nix
          catppuccin.homeManagerModules.catppuccin
        ];

        extraSpecialArgs = {
          inherit nix-colors;
          inherit hyprland;
        };
      };
    };
  };
}

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
      hyprland = import hyprland;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
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
            inherit hyprland;
          };
        };
      };

      hardware.opengl = {
        package = pkgs-unstable.mesa.drivers;
        driSupport32Bit = true;
        package32 = pkgs-unstable.pkgsi686Linux.mesa.drivers;
        extraPackages = with pkgs; [
          amdvlk
        ];
        extraPackages32 = with pkgs; [
          driversi686Linux.amdvlk
        ];
      };
  };
}

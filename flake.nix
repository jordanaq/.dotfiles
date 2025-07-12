{
  description = "Entrypoint flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs = { self, nixpkgs, catppuccin, home-manager, nixos-wsl, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in {
      nixosConfigurations = {
        tsiru-nixos = lib.nixosSystem {
          inherit system;

          modules = [
            ./system/configuration.nix
            ./system/audio/default.nix

            nixos-wsl.nixosModules.default
            {
              system.stateVersion = "24.11";
              wsl.enable = true;
              wsl.defaultUser = "tsiru";
            }
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
            inherit inputs;
            inherit system;
          };
        };
      };
    };
}

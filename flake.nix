{
  description = "Entrypoint flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:/hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, catppuccin, home-manager, nixvirt, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      hyprland = import hyprland;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          rocmSupport = true;
        };
      };
      pkgs-unstable = hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in {
      nixosConfigurations = {
        tsiru-nixos = lib.nixosSystem {
          inherit system;

          specialArgs = { inherit inputs; };

          modules = [
            ./system/configuration.nix
            ./system/audio/default.nix
            (nixvirt.nixosModules.default)

            home-manager.nixosModules.home-manager {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
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
            (nixvirt.homeModules.default)
          ];

          extraSpecialArgs = {
            inherit inputs;
            inherit system;
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

{
  description = "Entrypoint flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    gbrain-src = {
      url = "github:garrytan/gbrain";
      flake = false;
    };

    hermes-agent.url = "github:NousResearch/hermes-agent";

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
        # torch is pinned to the CPU build for now.
        #
        # GPU torch cannot build on this nixpkgs rev: torch 2.13 pins AOTriton
        # 0.12b (cmake/External/aotriton.cmake) but nixpkgs ships aotriton
        # 0.11.1b, so every ROCm-enabled torch source build dies on a missing
        # 0.12b symbol. Five attempts (each a full multi-hour recompile) showed
        # the patches are not worth chasing right now — see the TODO below.
        # Nothing here actually needs GPU torch: calibre -> piper-tts (TTS) and
        # gbrain's hindsight env are the only consumers. CPU torch comes from the
        # binary cache, so home-manager builds at all.
        #
        # TODO(rocm-torch): restore the GPU build once nixpkgs pairs torch with
        # aotriton 0.12b (or with a torch matching 0.11.1b). What the attempts
        # established, so nobody re-walks it:
        #   1. the CK "SDPA" step runs add_make_kernel_pt.sh, whose shebang is
        #      /bin/bash (absent in the sandbox) -> must be patched; and
        #      -DUSE_ROCM_CK_SDPA=OFF is useless (torch sets it internally):
        #        substituteInPlace <ck script> --replace-fail '#!/bin/bash' '#!${bash}/bin/bash'
        #   2. -DDISABLE_AOTRITON (injected via add_definitions at
        #      'include(cmake/External/aotriton.cmake)') clears the aotriton code
        #      in attention.cu / attention_backward.cu, but NOT
        #      native/transformers/hip/flash_attn/aot/*.hip;
        #   3. -DUSE_FLASH_ATTENTION=OFF is ALSO re-forced internally (the aot
        #      .hip still compiled), so that file list must be patched in
        #      aten/src/ATen/CMakeLists.txt, not switched off;
        #   4. the correct long-term fix is aotriton 0.12b, which means building
        #      AOTriton's Triton GPU kernels locally (heavy) — or a nixpkgs bump
        #      once upstream pins the two together.
        # Full recipe + evidence: `dotfiles-config` skill.
        overlays = [
          (final: prev:
            let
              cpuTorch = set: set.torch.override { rocmSupport = false; };
              withCpuTorch = py: py.override {
                packageOverrides = _: set: { torch = cpuTorch set; };
              };
            in
            {
              python3 = withCpuTorch prev.python3;
              python312 = withCpuTorch prev.python312;
              python313 = withCpuTorch prev.python313;
              python314 = withCpuTorch prev.python314;
            })
        ];
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
            catppuccin.homeModules.catppuccin
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

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          rustc
          cargo
          wasm-pack
          just
          nodejs
          pnpm
          perl
          lld
        ];
      };
    };
}
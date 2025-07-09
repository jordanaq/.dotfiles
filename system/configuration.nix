# System-wide configuration

{ config, lib, pkgs, ... }:

let
  uname = "tsiru";
  homedir = /home/${uname};
in {
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Boot
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelModules = [
      "amdgpu"
      "v4l2loopback"
      "v4l2loopback-dc"
    ];

    extraModulePackages = with pkgs; [
      linuxPackages.v4l2loopback
    ];

    extraModprobeConfig = ''
      options v4l2loopback devices=1 exclusive_caps=1
    '';
  };

  # Networking
  networking = {
    hostName = "${uname}-nixos";
    wireless = {
      enable = true;
      networks = {
        "apartment-wifi" = {
          pskRaw = "1c491d1b9c5f0f243fd31d186a27403af4f92872e805c46335dda3c543b6c60c";
        };
      };
    };
    nameservers = [
      "9.9.9.9"
      "149.112.112.112"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers = [ uname ];
    };
  };

  # Time zone
  time.timeZone = "America/New_York";


  # User
  users.users.${uname} = {
    isNormalUser = true;
    extraGroups = [
      "render"
      "networkmanager"
      "video"
      "wheel"
    ];
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    bash
    catppuccin-sddm-corners
    git
    linuxKernel.packages.linux_6_6.v4l2loopback
    vim
    wget
    xorg.xinit
    xorg.xrandr
  ];

  nixpkgs.config = {
    allowUnfree = true;
    rocmTargets = [ "gfx1012" ];
  };

  programs.steam.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    config.common.default = "hyprland";
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
      kdePackages.xdg-desktop-portal-kde
    ];
  };

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;

    xkb = {
      layout = "us";
      variant = "";
    };

    displayManager.setupCommands = ''
      ${pkgs.xorg.xrandr}/bin/xrandr --output DP-2 --primary --mode 2560x1440 --pos 1440x868 --refresh 144
      ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --mode 2560x1440 --pos 0x0 --rotation right --refresh 120
    '';
  };

  services.displayManager = {
    sddm = {
      enable = true;
      theme = "catppuccin-sddm-corners";
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;  # Optional: Enable XWayland support
  };

  # services.xserver.libinput.enable = true;
  services.pulseaudio = {
    enable = true;
    extraConfig = ''
      set-default-sink alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_Q3_FA300243-00.analog-stereo
    '';
  };

  hardware.bluetooth.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages32 = with pkgs.pkgsi686Linux; [
      gnutls
      mesa
      vulkan-loader
    ];
  };

  hardware.amdgpu = {
    opencl.enable = true;
    amdvlk.enable = true;
  };

  fileSystems."/mnt" = {
    device = "/dev/disk/by-uuid/16615F903483D493";
    fsType = "ntfs";
    options = [
      "users"
      "nofail"
      "x-gvfs-show"
      "rw"
    ];
  };

  # Experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Set system state
  system.stateVersion = "25.05";
}

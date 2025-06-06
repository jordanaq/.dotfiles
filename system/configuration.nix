# System-wide configuration

{ config, lib, pkgs, ... }:

{
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
    hostName = "tsiru-nixos";
    wireless = {
      enable = true;
      networks = {
        "ATT2dzN9ZY" = {
          psk = "7grh9t4xgj7d";
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
      AllowUsers = [ "tsiru" ];
    };
  };

  # Time zone
  time.timeZone = "America/New_York";


  # User
  users.users.tsiru = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [ ];
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

  nixpkgs.config.allowUnfree = true;
  programs.steam.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
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

  hardware.graphics.enable = true;

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

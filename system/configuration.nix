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
    vim
    wget
    git
    linuxKernel.packages.linux_6_6.v4l2loopback
    bash
    greetd.tuigreet
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

  services.displayManager.ly = {
    enable = true;
  };

  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # services.xserver.libinput.enable = true;
  hardware.pulseaudio = {
    enable = true;
    extraConfig = ''
      set-default-sink alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_Q3_FA300243-00.analog-stereo
    '';
  };

  hardware.bluetooth.enable = true;

  hardware.opengl.enable = true;

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

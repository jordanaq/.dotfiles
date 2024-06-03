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
  time.timeZone = "America/Los_Angeles";


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
  ];

  hardware.pulseaudio = {
    enable = true;
    extraConfig = ''
      set-default-sink alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_Q3_FA300243-00.analog-stereo
    '';
  };

  hardware.bluetooth.enable = true;

  hardware.opengl.enable = true;

  # Experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Set system state
  system.stateVersion = "unstable";
}

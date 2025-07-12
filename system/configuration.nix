# System-wide configuration

{ config, lib, pkgs, ... }:

let
  uname = "tsiru";
  homedir = /home/${uname};
in {
  imports =
    [
      ./hardware-configuration.nix
      # <nixos-wsl/modules>
    ];


  wsl.enable = true;
  wsl.defaultUser = "tsiru";


  # Time zone
  time.timeZone = "America/New_York";


  # User
  users.users.${uname} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
  };


  # System-wide packages
  environment.systemPackages = with pkgs; [
    bash
    fish
    git
    vim
    wget
  ];

  programs.nix-ld.enable = true;

  nixpkgs.config.allowUnfree = true;


  # Experimental features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Set system state
  system.stateVersion = "24.11";
}

# tsiru-cloud — lean server base configuration
# Server-only branch of ~/.dotfiles. Services: SearXNG (behind Caddy) + SSH.

{ config, lib, pkgs, domain, ... }:

let
  uname = "tsiru";
in {
  imports = [
    ./hardware-configuration.nix
    ./constants.nix
    ./searx.nix
    ./caddy.nix
  ];

  # --- Boot ---------------------------------------------------------------
  # ⚠️ VERIFY against the Linode before `nixos-rebuild switch`: copy the
  # EXACT boot.loader.* block from the box's current /etc/nixos/configuration.nix.
  # Linode KVM boxes vary between legacy-BIOS GRUB and UEFI systemd-boot;
  # the wrong choice can leave the box unbootable.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # For a legacy-BIOS Linode, use instead:
  #   boot.loader.grub.enable = true;
  #   boot.loader.grub.device = "/dev/sda";

  system.stateVersion = "25.05";
  time.timeZone = "America/New_York";

  networking = {
    hostName = "tsiru-cloud";
    domain = domain;
    nameservers = [ "9.9.9.9" "149.112.112.112" ];

    # Default deny. Public web traffic only via Caddy:
    #   80  → ACME HTTP-01 challenge
    #   443 → HTTPS (Caddy-terminated TLS)
    #   22  → SSH
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 ];
    };
  };

  # --- SSH: key-only, single user ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ uname ];
    };
  };

  # --- User ---
  users.users.${uname} = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJG/FR6CFiwPbzcImspqocZLKHR1gptTKW/S/Sj92Xst tsiru@tsiru-nixos"
    ];
  };

  # --- Minimal CLI tooling (+ home-manager for the standalone HM switch) ---
  environment.systemPackages = with pkgs; [
    bat
    curl
    fd
    fzf
    git
    htop
    jq
    neovim
    ripgrep
    rsync
    tmux
    tree
    unzip
    wget
    home-manager
  ];
  programs.fish.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
}

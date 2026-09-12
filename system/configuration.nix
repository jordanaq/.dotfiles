# tsiru-cloud — lean server base configuration
# Server-only branch of ~/.dotfiles. Services: SearXNG + Calibre (calibre-web +
# content server) behind Caddy, plus SSH.
#
# Linode/LISH boot + networking settings below are taken from nixpkgs'
# maintained profile `nixos/modules/virtualisation/linode-config.nix`
# (the current equivalent of the old "Install NixOS on Linode" guide).
# We hand-pick them instead of importing that module because it also defines
# `fileSystems."/"` and `boot.kernelParams`, which would CONFLICT with this
# repo's own `hardware-configuration.nix` and the nixpkgs defaults.

{ config, lib, pkgs, domain, ... }:

let
  uname = "tsiru";
in {
  imports = [
    ./hardware-configuration.nix
    ./constants.nix
    ./searx.nix
    ./caddy.nix
    ./calibre.nix
    ./fail2ban.nix
  ];

  # --- Boot ---------------------------------------------------------------
  # ⚠️ VERIFY against the Linode before `nixos-rebuild switch`: compare with the
  # box's current /etc/nixos/configuration.nix. Linode boots via its OWN host
  # "GRUB 2" kernel, which reads the GRUB menu from disk — so the system must
  # use GRUB, NOT systemd-boot.
  boot = {
    # The initrd virtio/disk modules (virtio_pci, virtio_scsi, ahci, sd_mod)
    # come from the generated system/hardware-configuration.nix — not duplicated
    # here. virtio_net is NOT in that file, so it stays.
    kernelModules = [ "virtio_net" ];

    # LISH (out-of-band serial console) — essential when SSH is unavailable.
    kernelParams = [ "console=ttyS0,19200n8" ];

    loader = {
      # Give LISH time to connect; mkForce because the image generator may try
      # to set 0.
      timeout = lib.mkForce 10;

      grub = {
        enable = true;
        # Linode disks are partitionless; force past GRUB's blocklist warning.
        # GRUB runs from the host, so nothing is actually installed to disk.
        forceInstall = true;
        device = "nodev";
        # Serial terminal so GRUB itself is usable over LISH.
        extraConfig = ''
          serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1;
          terminal_input serial;
          terminal_output serial
        '';
      };
    };
  };

  system.stateVersion = "25.05";
  time.timeZone = "America/New_York";

  networking = {
    hostName = "tsiru-cloud";
    domain = domain;
    nameservers = [ "9.9.9.9" "149.112.112.112" ];

    # Linode networking conventions (single eth0, DHCP). Matches Linode's own
    # images so their docs/support tooling behave as expected.
    usePredictableInterfaceNames = false;
    useDHCP = false;
    interfaces.eth0 = {
      useDHCP = true;
      # Linode expects IPv6 privacy extensions disabled.
      tempAddress = "disabled";
    };

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

  # --- Minimal CLI tooling + home-manager (for the standalone HM switch) ---
  # inetutils/mtr/sysstat are what Linode support asks for when troubleshooting.
  environment.systemPackages = with pkgs; [
    bat
    curl
    fd
    fzf
    git
    htop
    inetutils
    jq
    mtr
    neovim
    ripgrep
    rsync
    sysstat
    tmux
    tree
    unzip
    wget
    home-manager
  ];
  programs.fish.enable = true;

  # Grow the root filesystem to fill the disk after a Linode disk resize.
  fileSystems."/".autoResize = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
}

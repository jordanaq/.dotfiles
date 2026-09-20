# tsiru-cloud — lean server base configuration (server-only branch).
# Services live in ./web, ./office, ./mail, ./monitoring, ./security, ./networking; see README.

# Linode/LISH boot + networking params taken from nixpkgs' linode-config.nix but
# hand-picked — importing that module would conflict (it defines fileSystems."/"
# and boot.kernelParams).

{ config, lib, pkgs, domain, ... }:

let
  uname = "tsiru";
in {
  imports = [
    ./backup
    ./constants.nix
    ./hardware-configuration.nix
    ./mail
    ./monitoring
    ./networking
    ./office
    ./security
    ./web
  ];

  # --- Boot ---------------------------------------------------------------
  # ⚠️ VERIFY against the Linode's current /etc/nixos/configuration.nix before
  # `nixos-rebuild switch`. Linode boots via its own host "GRUB 2" kernel reading
  # GRUB from disk — so the system MUST use GRUB, NOT systemd-boot.
  boot = {
    # virtio_pci/scsi, ahci, sd_mod come from hardware-configuration.nix; only
    # virtio_net (absent there) is needed here.
    kernelModules = [ "virtio_net" ];

    # LISH (out-of-band serial console) — essential when SSH is unavailable.
    kernelParams = [ "console=ttyS0,19200n8" ];

    loader = {
      # Time for LISH to connect; mkForce because the image generator may set 0.
      timeout = lib.mkForce 10;

      grub = {
        enable = true;
        # Partitionless Linode disks: force past GRUB's blocklist warning; GRUB
        # runs from the host, so nothing is actually installed to disk.
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

    # Matches Linode image defaults (single eth0, DHCP).
    usePredictableInterfaceNames = false;
    useDHCP = false;
    interfaces.eth0 = {
      useDHCP = true;
      # Linode expects IPv6 privacy extensions disabled.
      tempAddress = "disabled";
    };

    # Default deny. TCP only — no UDP; ICMP governed by allowPing (default true).
    #   22   → SSH (TAILNET-ONLY, closed to the public internet — pentest 2026-09-15;
    #          reachable via trustedInterfaces=[tailscale0]; use Linode LISH if down)
    #   80   → ACME HTTP-01 challenge (Caddy)
    #   443  → HTTPS (Caddy-terminated TLS: web, webmail, admin, JMAP/CalDAV)
    #   25   → SMTP (inbound mail / MX)
    # NOT opened: 465/587 (SMTP submission) and 993 (IMAPS). The only mail client
    #   (Bulwark) is JMAP-only over :443; the only SMTP-submission consumer
    #   (Vaultwarden) relays via loopback 127.0.0.1:587, which needs no firewall
    #   hole. Stalwart listeners for 465/993 are deleted; submission rebinds
    #   loopback-only. See system/mail/stalwart/default.nix.
    # NOT opened: 4190 (ManageSieve). Pentest F-11: Linode filters it upstream and
    #   nothing serves it (Sieve is managed over JMAP) — see system/mail/stalwart/default.nix.
    firewall = {
      enable = true;
      allowedTCPPorts = lib.mkForce [ 80 443 25 ];  # mkForce: exact public allowlist; CLOSES :22 (default [22 80 443] would otherwise leak a public SSH). SSH stays reachable over Tailscale via trustedInterfaces=[tailscale0].
    };
  };

  # --- Secret file modes (self-healing) ---
  # /etc/secrets/* are created by hand (README "Files to create"), so Nix owns no
  # permissions. On 2026-09-13 they drifted to 0644, leaking the Spaceship API key
  # (full DNS control) to every local service user. `z` re-applies mode/owner on
  # every boot and silently skips missing files (safe on fresh box). root-only =
  # read by the service manager (systemd EnvironmentFile, lego); root:stalwart =
  # read by Stalwart itself at runtime.
  systemd.tmpfiles.rules = [
    "z /etc/secrets/bulwark.env 0600 root root"
    "z /etc/secrets/caddy.env 0600 root root"
    "z /etc/secrets/coolwsd.env 0600 root root"
    "z /etc/secrets/scaleway.smtp-password 0600 root root"
    "z /etc/secrets/scaleway.smtp-user 0600 root root"
    "z /etc/secrets/searxng.env 0600 root root"
    "z /etc/secrets/spaceship.env 0600 root root"
    "z /etc/secrets/vaultwarden.env 0600 root root"
    "z /etc/secrets/smtp2go.smtp-password 0640 root stalwart"
    "z /etc/secrets/stalwart-admin-password 0640 root stalwart"
  ];

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
    openssl
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
  # Prebuilt-Stalwart overlay is declared in system/mail/stalwart/default.nix,
  # beside the package it defines.
}

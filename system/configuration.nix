# tsiru-cloud — lean server base configuration
# Server-only branch of ~/.dotfiles.
# Services: SearXNG, Calibre (calibre-web + content server), LinkStack, the
# public personal site, the vault notes site, Stalwart + Bulwark (mail), and
# Vaultwarden — all behind Caddy — plus Tailscale, Uptime Kuma, fail2ban, and
# SSH. See the per-service modules in this directory and the README.
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
    ./notes-site.nix
    ./caddy.nix
    ./calibre.nix
    ./linkstack.nix
    ./stalwart.nix
    ./bulwark.nix
    ./fail2ban.nix
    ./tailscale.nix
    ./uptime-kuma.nix
    ./vaultwarden.nix
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

    # Default deny. Public traffic is only Caddy's web ports plus the mail
    # ports Stalwart listens on. TCP only — mail uses no UDP, and ICMP/ping is
    # governed separately (allowPing, default true).
    #   22   → SSH
    #   80   → ACME HTTP-01 challenge (Caddy)
    #   443  → HTTPS (Caddy-terminated TLS: web, webmail, admin, JMAP/CalDAV)
    #   25   → SMTP (inbound mail from other servers)
    #   465  → SMTP submission (implicit TLS)
    #   587  → SMTP submission (STARTTLS)
    #   993  → IMAPS (implicit TLS)
    # NOT opened: 4190 (ManageSieve key management). Pentest F-11: Linode
    #   filters the port upstream, so no internet client could reach it, and
    #   nothing here speaks ManageSieve (Sieve is managed over JMAP). Opening it
    #   only advertised a service that did not exist — see the listener note in
    #   system/stalwart.nix.
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 80 443 25 465 587 993 ];
    };
  };

  # --- Secret file modes (self-healing) ---
  # /etc/secrets/* are created by hand (see "Secrets" in the README), so nothing
  # in Nix owns their permissions. On 2026-09-13 they had drifted to 0644 —
  # leaving the Spaceship API key (i.e. full DNS control) readable by *every*
  # local service user: linkstack's php-fpm, bulwark, vaultwarden, searxng. A
  # DNS takeover is not a dead end either: it can point a vhost elsewhere or
  # satisfy a Let's Encrypt DNS-01 challenge, which CAA does not prevent.
  #
  # `z` re-applies mode/owner on every boot and silently skips files that do not
  # exist yet, so this is safe on a fresh box. Modes match what each consumer
  # actually needs: root-only for the ones the service manager reads as root
  # (systemd `EnvironmentFile`/lego), root:stalwart for the ones Stalwart reads
  # itself at runtime.
  systemd.tmpfiles.rules = [
    "z /etc/secrets/bulwark.env 0600 root root"
    "z /etc/secrets/caddy.env 0600 root root"
    "z /etc/secrets/scaleway.smtp-password 0600 root root"
    "z /etc/secrets/scaleway.smtp-user 0600 root root"
    "z /etc/secrets/searxng.env 0600 root root"
    "z /etc/secrets/spaceship.env 0600 root root"
    "z /etc/secrets/vaultwarden.env 0600 root root"
    "z /etc/secrets/smtp2go.smtp-password 0640 root stalwart"
    "z /etc/secrets/stalwart-admin.hash 0640 root stalwart"
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
  # Prebuilt Stalwart 0.16 + CLI (nixpkgs still pins 0.15.5). Drop once nixpkgs
  # bumps past 0.16 — see the overlay's header comment.
  nixpkgs.overlays = [ (import ./stalwart-overlay.nix) ];
}

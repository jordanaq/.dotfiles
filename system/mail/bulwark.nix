# Bulwark — self-hosted JMAP webmail client for Stalwart, served at
# webmail.<domain>.
#
# Not in nixpkgs; we package it here. Bulwark ships a PREBUILT standalone
# bundle (server.js + .next/ + vendored node_modules): fetch the release
# tarball, drop it in the store, run with Node. No build step, PHP, or DB.
#
# STATE MODEL (mirrors LinkStack): the app tree is rsync'd --delete out of the
# read-only store into /var/lib/bulwark/app on every activation, because ALL
# mutable state lives outside it, in ADMIN_CONFIG_DIR / ADMIN_STATE_DIR (the
# wizard writes operator config to ADMIN_CONFIG_DIR). So a version bump fully
# replaces code without touching state, and stale .next chunks can't survive.
#
# PROVIDER: Bulwark only speaks JMAP to Stalwart (no IMAP mode); we point it
# at the public HTTPS JMAP endpoint, fronted by Caddy.
{ config, lib, pkgs, domain, ... }:

let
  # Bump to upgrade. Hash recompute:  nix store prefetch-file <url>
  version = "1.10.0";

  user = "bulwark";
  group = "bulwark";
  dataDir = "/var/lib/bulwark";
  appDir = "${dataDir}/app";

  # Loopback port Caddy proxies; not exposed directly.
  port = 3100;

  vhost = "webmail.${domain}";
  jmapUrl = "https://mail.${domain}";

  bulwarkSrc = pkgs.fetchurl {
    url = "https://github.com/bulwarkmail/webmail/releases/download/${version}/bulwark-standalone-${version}-linux-amd64.tar.gz";
    hash = "sha256:399c9bfc755ae420c24a98b91f6907c861a02c81c409a68661fd3a30baa31c27";
  };

  # Unpack the release into the store as a read-only reference copy. The tarball
  # has a single top-level `bulwark-standalone/` directory (hence sourceRoot).
  bulwark = pkgs.stdenvNoCC.mkDerivation {
    pname = "bulwark";
    inherit version;
    src = bulwarkSrc;
    sourceRoot = "bulwark-standalone";
    dontConfigure = true;
    dontBuild = true;
    # The bundle vendors its own node_modules; no fixup/wrapping needed.
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r . $out/
      runHook postInstall
    '';
  };
in
{
  # --- Deploy the app into the mutable data directory -----------------------
  systemd.services.bulwark-setup = {
    description = "Deploy Bulwark into ${appDir}";
    before = [ "bulwark.service" ];
    requiredBy = [ "bulwark.service" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    wants = [ "systemd-tmpfiles-setup.service" ];

    # Re-run when the packaged release changes (i.e. on a version bump).
    restartTriggers = [ bulwark ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = group;
      StateDirectory = "bulwark";
    };

    script = ''      set -euo pipefail
      # --delete: app tree fully replaced; state lives outside it.
      # -rlp + --no-owner/--no-group: unprivileged unit can't set ownership
      # from root-owned store tree.
      # --chmod: store dirs are 0555; without it rsync can't create children.
      ${pkgs.rsync}/bin/rsync -rlp --delete --no-owner --no-group \
        --chmod=D755,F644 \
        ${bulwark}/ ${appDir}/
    '';
  };

  # --- Service --------------------------------------------------------------
  systemd.services.bulwark = {
    description = "Bulwark — JMAP webmail for Stalwart";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "stalwart.service" ];
    wants = [ "network-online.target" "stalwart.service" ];

    serviceConfig = {
      User = user;
      Group = group;
      StateDirectory = "bulwark";
      WorkingDirectory = appDir;
      ExecStart = "${pkgs.nodejs_22}/bin/node ${appDir}/server.js";
      Restart = "on-failure";
      RestartSec = 5;

      Environment = [
        "NODE_ENV=production"
        "NEXT_TELEMETRY_DISABLED=1"
        "PORT=${toString port}"
        "HOSTNAME=127.0.0.1"
        # Setting JMAP_SERVER_URL skips the first-run setup wizard entirely.
        "JMAP_SERVER_URL=${jmapUrl}"
        "ADMIN_CONFIG_DIR=${dataDir}/admin"
        "ADMIN_STATE_DIR=${dataDir}/state"

        # Office via Collabora
        "WOPI_CLIENT_URL=https://office.${domain}"
        "WOPI_HOST_URL=https://webmail.${domain}"
      ];
      # SESSION_SECRET=... (required; encrypts sessions + settings sync)
      EnvironmentFile = "/etc/secrets/bulwark.env";
    };
  };

  # --- Writable state the app owns (survives upgrades) ----------------------
  systemd.tmpfiles.settings."10-bulwark" = {
    "${dataDir}/admin".d = { inherit user group; mode = "0700"; };
    "${dataDir}/state".d = { inherit user group; mode = "0700"; };
    "${appDir}".d = { inherit user group; mode = "0755"; };
  };

  # --- Service account ------------------------------------------------------
  users.users.${user} = {
    isSystemUser = true;
    inherit group;
    home = dataDir;
    description = "Bulwark webmail service user";
  };
  users.groups.${group} = { };

  # --- Caddy vhost declared in system/web/caddy.nix (kept with the others) ---
  # Reverse-proxies https://${vhost} -> 127.0.0.1:${port}.
  #
  # Deploy checklist:
  #   1. DNS: A record ${vhost} -> <LINODE_IP> (cert via Caddy HTTP-01).
  #   2. Create /etc/secrets/bulwark.env (0600): SESSION_SECRET=<64+ random
  #      chars>, before the first switch or the unit fails to start.
  #   3. First login uses the mail account (tsiru@${domain}) — accounts live
  #      in Stalwart, not here.
}

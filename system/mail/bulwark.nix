# Bulwark — self-hosted JMAP webmail client for Stalwart, served at
# webmail.<domain>.
#
# Bulwark is NOT in nixpkgs, so this file packages it itself. Unlike LinkStack,
# Bulwark publishes a PREBUILT standalone bundle (server.js + .next/ + vendored
# node_modules), so there is no npm/composer build step — we fetch the release
# tarball, drop it on disk and run it with Node. No PHP, no database.
#
# STATE MODEL (mirrors the LinkStack pattern): the app tree is copied out of the
# read-only store into /var/lib/bulwark/app on every activation, and the sync
# uses --delete because ALL mutable state lives OUTSIDE the app tree, in the
# ADMIN_CONFIG_DIR / ADMIN_STATE_DIR dirs declared below (that is the documented
# split — the wizard writes operator config to ADMIN_CONFIG_DIR). So a version
# bump fully replaces the code without touching state, and stale .next chunks
# from an old release can never survive.
#
# PROVIDER: Bulwark always talks JMAP to Stalwart (there is no IMAP mode). We
# point it at the public HTTPS JMAP endpoint, which Caddy fronts.
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
      # --delete: the app tree is fully replaced; state lives outside it.
      # -rlp + --no-owner/--no-group: this unit is unprivileged and cannot set
      # ownership from the root-owned store tree.
      # --chmod: store dirs are 0555, so without it rsync cannot create children.
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

  # --- Caddy vhost is declared in system/web/caddy.nix (kept with the others) ---
  # It reverse-proxies https://${vhost} -> 127.0.0.1:${port}.
  #
  # Deployment checklist:
  #   1. DNS: A record ${vhost} -> <LINODE_IP> (Caddy gets the cert via HTTP-01).
  #   2. Create /etc/secrets/bulwark.env (0600) with:
  #        SESSION_SECRET=<64+ random chars>
  #      before the first switch, or the unit fails to start.
  #   3. First login uses the mail account (tsiru@${domain}) — accounts live in
  #      Stalwart, not here; Bulwark has no separate user database.
}

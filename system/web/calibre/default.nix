# Calibre library hosting. /srv/calibre is the MASTER copy (219 books, ~15 GB) —
# deliberately NO second copy (backup out of scope; server disk is the only source).
#
# Two writable frontends serve the one library: calibre-web -> 127.0.0.1:8083
# (library.<domain>) and calibre-server -> 127.0.0.1:8081 (calibre.<domain>).
# Calibre supports only ONE writer: writing from calibredb AND the browser at the same
# instant yields a transient "database is locked" — retryable on local disk, not
# corruption. Don't write from both at once.
#
# ⚠️ ORDERING: /srv/calibre must EXIST with metadata.db before the first
# nixos-rebuild switch (calibre-web's ExecStartPre `test -f` hard-fails the unit).
# ⚠️ ONE-TIME on box: auth.userDb is not auto-created; init the users DB first.
{ pkgs, ... }:

{
  # Both service users share the one library; each module auto-creates only its own
  # default group, so define a shared `calibre` group and point both services at it.
  users.groups.calibre = { };

  services.calibre-web.group = "calibre";
  services.calibre-server.group = "calibre";

  # setgid, so files created by either service inherit the `calibre` group.
  systemd.tmpfiles.rules = [
    "d /srv/calibre 2775 root calibre -"
  ];

  # --- Content server: remote `calibredb` read+write, and OPDS ---
  services.calibre-server = {
    enable = true;
    libraries = [ "/srv/calibre" ];
    host = "127.0.0.1";
    port = 8081;
    openFirewall = false; # Caddy fronts it on the same host
    auth = {
      enable = true;
      mode = "basic";
      userDb = "/var/lib/calibre-server/users.sqlite";
    };
  };

  # --- calibre-web: browser UI (browse, read, upload, edit metadata) ---
  services.calibre-web = {
    enable = true;

    # Catppuccin Macchiato re-skin: no theme plugin system, so rewrite caliBlur's
    # palette at build time + append fixups to the override file it loads last.
    # Activate with Theme = "caliBlur! Dark Theme" in the admin UI (config_theme = 1).
    package = pkgs.calibre-web.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        ${pkgs.python3}/bin/python3 ${./catppuccin-macchiato.py} css \
          $out/lib/python*/site-packages/calibreweb/cps/static/css/caliBlur.css \
          $out/lib/python*/site-packages/calibreweb/cps/static/css/caliBlur_override.css
        ${pkgs.python3}/bin/python3 ${./catppuccin-macchiato.py} images \
          $out/lib/python*/site-packages/calibreweb/cps/static/css/images/caliblur
        cat ${./catppuccin-macchiato-override.css} >> \
          $out/lib/python*/site-packages/calibreweb/cps/static/css/caliBlur_override.css
      '';
    });
    listen = {
      ip = "127.0.0.1"; # module default is ::1; Caddy proxies over 127.0.0.1
      port = 8083;
    };
    openFirewall = false;
    options = {
      calibreLibrary = "/srv/calibre";
      enableBookUploading = true;  # allow adding books from the browser
      enableBookConversion = true; # uses pkgs.calibre's ebook-convert
      enableKepubify = true;       # Kobo-friendly KEPUB conversion
    };
  };
}

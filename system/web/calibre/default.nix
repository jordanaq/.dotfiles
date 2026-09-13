# Calibre library hosting.
#
# The library at /srv/calibre is the MASTER copy of Tsiru's Calibre library
# (219 books, ~15 GB). There is deliberately NO second copy — backup is out of
# scope by explicit choice, so treat the server disk as the only source.
#
# Two frontends serve the one library:
#   * calibre-web      -> 127.0.0.1:8083   (library.<domain>, via Caddy)
#   * calibre-server   -> 127.0.0.1:8081   (calibre.<domain>, via Caddy)
#
# BOTH ARE WRITABLE (calibre-web: upload/edit from the browser; calibre-server:
# `calibredb` add/edit + OPDS). Calibre officially supports only ONE writer, so
# writing from calibredb AND the browser at the same instant can yield a
# transient "database is locked". On a LOCAL disk that is retry-able, NOT
# corruption (corruption is a network-filesystem pathology, and the library is
# on the box's own disk). Discipline: don't write from both at once.
#
# ⚠️ ORDERING: the library directory must EXIST and contain metadata.db BEFORE
# the first `nixos-rebuild switch` — calibre-web's ExecStartPre runs
# `test -f /srv/calibre/metadata.db` and hard-fails the unit otherwise.
#
# ⚠️ ONE-TIME, on the box: `auth.userDb` is NOT auto-created, so calibre-server
# will not start until the users DB is initialised (see the plan / deploy notes).
{ pkgs, ... }:

{
  # Both service users must read/write the one shared library. The calibre-web
  # and calibre-server modules each auto-create ONLY their own default group, so
  # we define a shared `calibre` group and point both services at it.
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

    # Catppuccin Macchiato re-skin of the dark theme. calibre-web has no theme
    # plugin system, so we rewrite caliBlur's colour palette inside the package
    # at build time and append the hand-written fixups to the override file it
    # already loads last. Activate with Theme = "caliBlur! Dark Theme" in the
    # calibre-web admin UI (that sets config_theme = 1).
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

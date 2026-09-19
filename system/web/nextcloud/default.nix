{ pkgs, domain, ... }:

let
  cloudDomain = "cloud.${domain}";
in {
  imports = [
    ./office.nix
  ];

  services.nextcloud = {
    enable = true;
    hostName = "${cloudDomain}";

    package = pkgs.nextcloud34;

    https = true;

    config = {
      dbtype = "sqlite";

      adminuser = "admin";
      adminpassFile = "/etc/secrets/nextcloud-admin-pass";
    };

    settings = {
      overwriteprotocol = "https";
      trusted_proxies = [ "127.0.0.1" "::1" ];
      default_phone_region = "US";
    };

    maxUploadSize = "256M";

    # phpfpm pool — aggressive memory floor for a single-user instance:
    #  - "ondemand" spawns a PHP worker only on request (no warm spares at idle)
    #  - max_requests recycles workers so they shed memory instead of leaking it
    #  - idle children are reaped after 10s
    poolSettings = {
      "pm"                   = "ondemand";
      "pm.max_children"      = "6";
      "pm.max_requests"      = "500";
      "pm.process_idle_timeout" = "10s";
    };

    # Shared opcode/APCu cache capped to 64M (few apps; plenty).
    phpOptions."opcache.memory_consumption" = "64";


    configureRedis = false;
    caching.apcu = true;

    extraAppsEnable = true;
    extraApps = {
      inherit (pkgs.nextcloud34Packages.apps) richdocuments;
    };
  };

  services.nginx.virtualHosts."${cloudDomain}".listen =
    [ { addr = "127.0.0.1"; port = 8082; } ];
}

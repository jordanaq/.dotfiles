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

    poolSettings = {
      "pm.max_children"     = "8";
      "pm.start_servers"    = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
    };


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

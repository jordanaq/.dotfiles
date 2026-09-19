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

      # The admin account was provisioned by the FIRST setup run; adminpassFile
      # has since been deleted (good hygiene). But the module still wires it into
      # nextcloud-setup.service's LoadCredential, so with the file gone that unit
      # fails on every boot (status=243/CREDENTIALS, "Failed to set up
      # credentials"). Nulling BOTH (the option pair is assertively coupled)
      # removes the credential requirement — on an already-installed instance
      # setup then only runs maintenance/trusted_domains/app-enable, which is
      # the correct post-provision state. Only keep these set on a FRESH install.
      adminuser     = null;
      adminpassFile = null;
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

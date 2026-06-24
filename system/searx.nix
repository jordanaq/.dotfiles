{ pkgs, ... }:

{
  services.searx = {
    enable = true;
    package = pkgs.searxng;

    # Do I need this?
    redisCreateLocally = true;

    # Local only
    openFirewall = true;

    # Generate secrets here:
    environmentFile = "/etc/searxng/searxng.env";

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        method = "POST";

        secret_key = "$SEARXNG_SECRET";

        public_instance = false;
        limiter = false;
      };

      ui = {
        default_locale = "en";
        default_theme = "simple";
        theme_args.simplestyle = "auto";
      };

      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        formats = [ "html" "json" ];
      };

      general = {
        debug = false;
        instance_name = "Local SearXNG";
        enable_metrics = false;
      };
    };
  };
}

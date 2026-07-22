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
        # 0.0.0.0 so the Firecrawl containers can reach SearXNG via
        # host.docker.internal:8888 (their /search backend). The NixOS
        # firewall still gates outside access; `openFirewall` was already true.
        bind_address = "0.0.0.0";
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

      engines = [
        {
          name = "Exa";
          engine = "json_engine";
          shortcut = "exa";
          categories = [ "general" ];
          disabled = false;
          timeout = 10.0;

          search_url = "https://api.exa.ai/search";
          method = "POST";
          headers = {
            "x-api-key" = "$EXA_API_KEY";
            "Content-Type" = "application/json";
          };
          request_body = ''
            {{
              "query": "{query}",
              "numResults": 10,
              "type": "fast",
              "contents": {{ "highlights": true }}
            }}
          '';

          results_query = "results";
          url_query = "url";
          title_query = "title";
          content_query = "highlights/0";
        }
      ];
    };
  };
}

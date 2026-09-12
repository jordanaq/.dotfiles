# SearXNG — loopback-only, fronted by Caddy (system/caddy.nix).
# Self-contained: no Firecrawl, no Docker, nothing reaches it but Caddy.
{ domain, pkgs, ... }:

{
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    redisCreateLocally = true;

    # Caddy proxies from the same host; nothing else needs to reach it.
    # Bind loopback and do NOT open the port to the world.
    openFirewall = false;

    environmentFile = "/etc/secrets/searxng.env";

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        method = "POST";
        # Served at the subdomain root — no subpath prefixing needed.
        base_url = "https://search.${domain}/";
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
        instance_name = "tsiru-cloud SearXNG";
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

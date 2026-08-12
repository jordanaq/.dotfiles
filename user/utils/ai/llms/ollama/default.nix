# Ollama server configuration.
#
# Owns the `services.ollama` block plus its environment variables. The model
# pull/import services live in `services.nix` so this file stays focused on the
# daemon itself.
{ config, pkgs, ... }:

{
  services.ollama = {
    # Disabled 2026-08-12: ollama's ROCm runner shares the RX 9070 XT with
    # Hyprland and is suspected of triggering the amdgpu gfx-ring hangs that
    # reset the GPU and crash the compositor. Flip back to `true` to re-enable.
    enable = false;
    port = 11434;
    # 0.0.0.0 (not 127.0.0.1) so the rootless-Docker Firecrawl containers can
    # reach Ollama via host.docker.internal for local /extract. The NixOS
    # firewall default-denies inbound, so LAN machines still can't reach it;
    # localhost (Hermes inference) keeps working because 0.0.0.0 includes it.
    host = "0.0.0.0";
    package = pkgs.ollama-rocm.override {
      rocmPackages = pkgs.rocmPackages.gfx1201;
    };

    environmentVariables = {
      OLLAMA_MODELS = "${config.home.homeDirectory}/.local/share/ollama/models";
      OLLAMA_CONTEXT_LENGTH = "262144";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_GPU_OVERHEAD = "2147483648";
      OLLAMA_KEEP_ALIVE = "2m";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      OLLAMA_LLM_LIBRARY = "rocm_v7_2";
      # Let the embedding model remain available alongside the active LLM.
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_NUM_PARALLEL = "1";
      # Keep enough VRAM available for the desktop and other GPU workloads.
      LLAMA_ARG_N_GPU_LAYERS = "16";

      # Restrict ROCm discovery to the discrete RX 9070 XT.
      ROCR_VISIBLE_DEVICES = "GPU-fb707245ca77dfde";
    };
  };
}

# Ollama server configuration.
#
# Owns the `services.ollama` block plus its environment variables. The model
# pull/import services live in `services.nix` so this file stays focused on the
# daemon itself.
{ config, inputs, lib, pkgs, system, ... }:

let
  common = import ../common.nix { inherit config inputs lib pkgs system; };
in {
  services.ollama = {
    enable = true;
    port = common.port;
    host = common.host;
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

#!/usr/bin/env python3
"""Generate the "Nous Portal" provider block of VS Code's chatLanguageModels.json
from the Nous Portal model catalog (the /v1/models JSON the portal already serves).

Why: the catalog is machine-readable (id, name, context_length,
supported_parameters, architecture.input_modalities, top_provider), so the BYOK
entry does not have to be hand-maintained. This script reads it and emits an
entry with correct per-model capabilities, so agent mode is never fed a model
that cannot call tools.

Catalog source: the local Hermes subscription proxy by default
(http://127.0.0.1:8645/v1/models). The proxy attaches the Portal credential
itself, so no API key is needed here — and because the request is to
127.0.0.1, urllib is fine (Cloudflare blocks urllib against the inference API
directly; the proxy exists precisely to avoid that).

Other providers keep their settings, including OpenRouter's
`${input:chat.lm.secret.<id>}` reference into VS Code's secret storage.
A static "Copilot" provider (below)
is emitted too, so the gpt-6-luna context override survives regeneration.

Usage:
  ./generate-chat-language-models.py                 # CURATED set (below)
  ./generate-chat-language-models.py --all           # every tool-capable model
  ./generate-chat-language-models.py --all --dry-run # print, do not write
  ./generate-chat-language-models.py --base-url https://inference-api.nousresearch.com/v1
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from pathlib import Path

PROXY = "http://127.0.0.1:8645/v1"
PROVIDER_NAME = "Nous Portal"
DEFAULT_OUT = Path(__file__).resolve().parent / "chatLanguageModels.json"

# Curated default. Edit this list to change what VS Code offers; the metadata
# (context, vision, tool calling) is always pulled from the catalog, never
# hand-written. Ids absent from the catalog are reported, not silently dropped.
CURATED = [
    "~deepseek/deepseek-flash-latest",
    "nvidia/nemotron-3-super-120b-a12b",
    "z-ai/glm-5.3-flash",
    "minimax/minimax-m3",
    "qwen/qwen3.5-397b-a17b",
    "mistralai/devstral-2512",
    "z-ai/glm-5.3",
    "deepseek/deepseek-v4-pro",
    "moonshotai/kimi-k3",
    "openai/gpt-5.6-sol",
    "google/gemini-3.1-pro-preview",
    "x-ai/grok-4.7",
    "anthropic/claude-sonnet-4.6",
]

MAX_OUTPUT_TOKENS = 32000  # what we ask VS Code to send; capped per model

# Providers emitted verbatim rather than derived from the catalog. VS Code
# merges these into its own list; the Copilot block raises the context window
# VS Code assumes for gpt-6-luna so agent mode doesn't truncate early.
STATIC_PROVIDERS = [
    {
        "name": "Copilot",
        "vendor": "copilot",
        "settings": {
            "gpt-6-luna": {"contextSize": 872000},
        },
    },
]

# Provider names this script owns. Every OTHER provider in the target file is
# kept as-is (so hand-added BYOK entries are not clobbered).
MANAGED_NAMES = {PROVIDER_NAME} | {p["name"] for p in STATIC_PROVIDERS}


def fetch_catalog(base_url: str) -> list[dict]:
    url = base_url.rstrip("/") + "/models"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer sk-unused",  # proxy ignores it; a direct
            "User-Agent": "Mozilla/5.0 Chrome/126.0",  # portal needs a real UA
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        body = json.load(resp)
    return body["data"]


def usable(entry: dict) -> bool:
    """Tool-capable chat models only — agent mode needs tool calling."""
    params = entry.get("supported_parameters") or []
    if "tools" not in params:
        return False
    model_id = entry["id"]
    if ":batch" in model_id:
        return False
    if "embedding" in model_id or entry.get("architecture", {}).get("output_modalities") == []:
        return False
    return True


def to_model(entry: dict) -> dict:
    ctx = entry.get("context_length") or 128000
    max_out = min(
        (entry.get("top_provider") or {}).get("max_completion_tokens") or MAX_OUTPUT_TOKENS,
        MAX_OUTPUT_TOKENS,
    )
    inputs = (entry.get("architecture") or {}).get("input_modalities") or []
    model = {
        "id": entry["id"],
        "name": entry.get("name") or entry["id"],
        "url": "http://127.0.0.1:8645/v1/chat/completions",
        "toolCalling": True,
        "maxInputTokens": max(ctx - max_out, 4096),
        "maxOutputTokens": max_out,
    }
    if "image" in inputs:
        model["vision"] = True
    return model


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--base-url", default=PROXY, help=f"catalog base URL (default {PROXY})")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="target chatLanguageModels.json")
    ap.add_argument("--all", action="store_true", help="every tool-capable model, not just CURATED")
    ap.add_argument("--dry-run", action="store_true", help="print the result, write nothing")
    args = ap.parse_args()

    catalog = {e["id"]: e for e in fetch_catalog(args.base_url)}
    print(f"catalog: {len(catalog)} models from {args.base_url}")

    if args.all:
        chosen = [e for e in catalog.values() if usable(e)]
        chosen.sort(key=lambda e: e["id"])
        missing: list[str] = []
    else:
        missing = [m for m in CURATED if m not in catalog]
        chosen = [catalog[m] for m in CURATED if m in catalog]
    for m in missing:
        print(f"  WARNING: curated id not in catalog: {m}", file=sys.stderr)

    unusable = [e["id"] for e in chosen if not usable(e)]
    for m in unusable:
        print(f"  WARNING: {m} does not advertise tool support", file=sys.stderr)

    provider = {
        "name": PROVIDER_NAME,
        "vendor": "customendpoint",
        "apiType": "chat-completions",
        "apiKey": "sk-unused",  # the proxy attaches the real Portal credential
        "models": [to_model(e) for e in chosen],
    }

    out = Path(args.out)
    existing = json.loads(out.read_text()) if out.exists() else []
    kept = [p for p in existing if p.get("name") not in MANAGED_NAMES]
    result = kept + [provider, *STATIC_PROVIDERS]

    if args.dry_run:
        print(json.dumps(provider, indent=1)[:2000])
        return 0

    out.write_text(json.dumps(result, indent="\t") + "\n")
    print(f"wrote {out}: {len(provider['models'])} Nous models, {len(kept)} other providers kept")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

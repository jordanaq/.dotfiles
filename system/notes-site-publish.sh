#!/usr/bin/env bash
# Server-side publisher for https://notes.<domain>.
#
# Runs on the box (systemd service + timer, see ./notes-site.nix). The vault is
# NOT on this machine, but its bare git remote IS — the desktop pushes to
# ~/Documents/Obsidian-Vault.git on this host — so the build needs no network
# credentials at all: clone from that local path, build, publish.
#
#   usage: notes-publish <quartz-src> <quartz-config> [index-md]
#     quartz-src    pinned Quartz tree from the flake (read-only store path)
#     quartz-config this repo's quartz.config.yaml (the source of truth)
#     index-md      optional landing page for the site root. Concepts/ has no
#                   index.md of its own, so without this `/` 404s (Quartz emits
#                   no root index). Injected into the CLONE only — never into
#                   the vault — and only when the vault doesn't supply its own.
set -euo pipefail

BUILD="${BUILD:-/var/lib/notes-build}"
DOCROOT="${DOCROOT:-/var/lib/notes-site}"
VAULT_REPO="${VAULT_REPO:-/home/tsiru/Documents/Obsidian-Vault.git}"
VAULT_BRANCH="${VAULT_BRANCH:-main}"
VAULT_SUBDIR="${VAULT_SUBDIR:-Concepts}"

QUARTZ_SRC="${1:?usage: notes-publish <quartz-src> <quartz-config> [index-md]}"
QUARTZ_CFG="${2:?usage: notes-publish <quartz-src> <quartz-config> [index-md]}"
INDEX_MD="${3:-}"

# Stage the pinned Quartz tree, re-copying only when the flake input moves
# (its store path is the cache key). node_modules comes along for free: it is
# wiped with the tree, so npm ci re-runs only when the source actually changed.
stage_quartz() {
  local stamp="$BUILD/quartz/.source-rev"
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$QUARTZ_SRC" ]; then
    return
  fi
  rm -rf "$BUILD/quartz"
  # Store paths are read-only, but their MODE must survive the copy — dropping
  # the exec bit makes quartz/bootstrap-cli.mjs unrunnable ("Permission
  # denied"). Keep the mode, then add write for us.
  cp -r --no-preserve=ownership "$QUARTZ_SRC" "$BUILD/quartz"
  chmod -R u+rwX "$BUILD/quartz"
  cp "$QUARTZ_CFG" "$BUILD/quartz/quartz.config.yaml"
  printf '%s\n' "$QUARTZ_SRC" >"$stamp"
}

sync_vault() {
  if [ -d "$BUILD/vault/.git" ]; then
    git -C "$BUILD/vault" fetch --quiet --prune origin "$VAULT_BRANCH"
    git -C "$BUILD/vault" reset --quiet --hard FETCH_HEAD
  else
    rm -rf "$BUILD/vault"
    git clone --quiet --branch "$VAULT_BRANCH" "$VAULT_REPO" "$BUILD/vault"
  fi
}

mkdir -p "$BUILD" "$DOCROOT"
stage_quartz
sync_vault

rev="$(git -C "$BUILD/vault" rev-parse HEAD)"

# The injected landing page is part of what gets published, so its content has
# to be part of the change key — otherwise editing it would never republish.
index_sum=""
if [ -n "$INDEX_MD" ] && [ -f "$INDEX_MD" ]; then
  index_sum="$(sha256sum "$INDEX_MD" | cut -d' ' -f1)"
fi
key="$rev:$index_sum"

if [ -f "$BUILD/published.rev" ] && [ "$(cat "$BUILD/published.rev")" = "$key" ]; then
  exit 0 # nothing to publish since the last run
fi

# Site root. Only fill in for the vault: if Concepts/ ships its own index.md,
# that wins. Injected into the clone, never into the vault.
if [ -n "$index_sum" ] && [ ! -f "$BUILD/vault/$VAULT_SUBDIR/index.md" ]; then
  cp "$INDEX_MD" "$BUILD/vault/$VAULT_SUBDIR/index.md"
fi

cd "$BUILD/quartz"
[ -d node_modules ] || npm ci --no-audit --no-fund

# Bound the heap: the box has ~1.3 GB free and the node build is transiently
# hungry. Single-threaded as well, for the same reason.
NODE_OPTIONS="--max-old-space-size=768" \
  npm run quartz -- build -d "$BUILD/vault/$VAULT_SUBDIR" -o "$BUILD/out" --concurrency=1

# Trailing slash: sync the CONTENTS of out/ into the docroot Caddy serves.
rsync -a --delete "$BUILD/out/" "$DOCROOT/"
printf '%s\n' "$key" >"$BUILD/published.rev"
echo "published $rev ($(find "$DOCROOT" -name '*.html' | wc -l) pages)"

#!/usr/bin/env bash
# Server-side publisher for https://notes.<domain>.
#
# Runs on the box (systemd service + timer, see ./notes-site.nix). The vault is
# NOT on this machine, but its bare git remote IS — the desktop pushes to
# ~/Documents/Obsidian-Vault.git on this host — so the build needs no network
# credentials at all: clone from that local path, build, publish.
#
#   usage: notes-publish <quartz-src> <quartz-config>
#     quartz-src    pinned Quartz tree from the flake (read-only store path)
#     quartz-config this repo's quartz.config.yaml (the source of truth)
#
# Skips the expensive part (npm ci + build) unless the vault's HEAD moved, so a
# 5-minute timer costs one `git fetch` when nothing changed.
set -euo pipefail

BUILD="${BUILD:-/var/lib/notes-build}"
DOCROOT="${DOCROOT:-/var/lib/notes-site}"
VAULT_REPO="${VAULT_REPO:-/home/tsiru/Documents/Obsidian-Vault.git}"
VAULT_BRANCH="${VAULT_BRANCH:-main}"
VAULT_SUBDIR="${VAULT_SUBDIR:-Concepts}"

QUARTZ_SRC="${1:?usage: notes-publish <quartz-src> <quartz-config>}"
QUARTZ_CFG="${2:?usage: notes-publish <quartz-src> <quartz-config>}"

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
if [ -f "$BUILD/published.rev" ] && [ "$(cat "$BUILD/published.rev")" = "$rev" ]; then
  exit 0 # vault unchanged since the last publish
fi

cd "$BUILD/quartz"
[ -d node_modules ] || npm ci --no-audit --no-fund

# Bound the heap: the box has ~1.3 GB free and the node build is transiently
# hungry. Single-threaded as well, for the same reason.
NODE_OPTIONS="--max-old-space-size=768" \
  npm run quartz -- build -d "$BUILD/vault/$VAULT_SUBDIR" -o "$BUILD/out" --concurrency=1

# Trailing slash: sync the CONTENTS of out/ into the docroot Caddy serves.
rsync -a --delete "$BUILD/out/" "$DOCROOT/"
printf '%s\n' "$rev" >"$BUILD/published.rev"
echo "published $rev ($(find "$DOCROOT" -name '*.html' | wc -l) pages)"

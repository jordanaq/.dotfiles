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
  if [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$QUARTZ_SRC" ]; then
    rm -rf "$BUILD/quartz"
    # Store paths are read-only, but their MODE must survive the copy — dropping
    # the exec bit makes quartz/bootstrap-cli.mjs unrunnable ("Permission
    # denied"). Keep the mode, then add write for us.
    cp -r --no-preserve=ownership "$QUARTZ_SRC" "$BUILD/quartz"
    chmod -R u+rwX "$BUILD/quartz"
    printf '%s\n' "$QUARTZ_SRC" >"$stamp"
  fi
  # The config is THIS repo's source of truth and is copied on EVERY run, not
  # just when the Quartz tree is re-staged. It is a few KB, and gating it behind
  # the source stamp meant a config-only edit (enabling a plugin, changing
  # ignorePatterns, ...) was silently never applied: the build kept using the
  # stale copy left in the tree from the last re-stage.
  # `install -m 644`, not bare `cp`: a fresh `cp` gives the new file the
  # SOURCE's permission bits, and store paths are 444 — so the very first copy
  # landed read-only and every later copy died with "Permission denied"
  # (which is how the ca8a257 deploy wedged the unit into a restart loop).
  install -m 644 "$QUARTZ_CFG" "$BUILD/quartz/quartz.config.yaml"
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

# Obsidian inline snippets (Templater/Dataview) cannot be evaluated by Quartz,
# so they land in the page as literal code. 100 notes carry exactly:
#   Last Modified: `=dateformat(this.file.mtime, "DDDD, HH:mm")`
#
# Date source, most truthful first:
#   1. the note's own frontmatter `last_modified:` (46 notes; DATE ONLY — the
#      vault records no time of day here)
#   2. the last commit date for that file
# There is deliberately NO time in the output: the only time-bearing source is
# the commit timestamp, which is often the 23:00 daily auto-commit rather than
# an edit, so an HH:mm would be an artifact dressed up as fact.
# Runs on the BUILD CLONE only.
render_dates() {
  local f rel when long
  while IFS= read -r -d '' f; do
    grep -q 'this\.file\.mtime' "$f" 2>/dev/null || continue
    rel="${f#"$BUILD/vault/"}"

    # NOTE: start this with sed, not grep — grep exits 1 on "no match", and
    # under `set -e`/pipefail a failing command substitution in an assignment
    # kills the whole script mid-loop (which is exactly how this bug shipped
    # once: the snippet silently stayed raw).
    when="$(sed -nE 's/^last_modified:[[:space:]]*"?([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p' "$f" 2>/dev/null |
      head -1 | tr -d '\r' || true)"
    [ -n "$when" ] || when="$(git -C "$BUILD/vault" log -1 --format=%cs -- "$rel" 2>/dev/null || true)"
    [ -n "$when" ] || when="$(date -r "$f" +%F 2>/dev/null || date +%F)"

    # Long human form ("Friday, August 7, 2026"), English regardless of locale.
    long="$(LC_ALL=C date -d "$when" '+%A, %B %-d, %Y' 2>/dev/null || printf '%s' "$when")"
    sed -i "/this\.file\.mtime/{s|.*|Last Modified: $long|}" "$f"
  done < <(find "$BUILD/vault/$VAULT_SUBDIR" -name '*.md' -print0)
}

mkdir -p "$BUILD" "$DOCROOT"
stage_quartz
sync_vault

rev="$(git -C "$BUILD/vault" rev-parse HEAD)"

# The injected landing page is part of what gets published, so its content has
# to be part of the change key — otherwise editing it would never republish.
# The publisher's OWN hash is in the key for the same reason: a change to the
# rendering logic below (date substitution, etc.) must reach the site even when
# neither the vault nor the landing page moved.
# The CONFIG's hash is in the key too: enabling/disabling a plugin or changing
# ignorePatterns changes the output without touching a single note.
index_sum=""
if [ -n "$INDEX_MD" ] && [ -f "$INDEX_MD" ]; then
  index_sum="$(sha256sum "$INDEX_MD" | cut -d' ' -f1)"
fi
script_sum="$(sha256sum "${BASH_SOURCE[0]:-$0}" | cut -d' ' -f1)"
cfg_sum="$(sha256sum "$QUARTZ_CFG" | cut -d' ' -f1)"
key="$rev:$index_sum:$script_sum:$cfg_sum"

if [ -f "$BUILD/published.rev" ] && [ "$(cat "$BUILD/published.rev")" = "$key" ]; then
  exit 0 # nothing to publish since the last run
fi

# Site root. Only fill in for the vault: if Concepts/ ships its own index.md,
# that wins. Injected into the clone, never into the vault.
#
# The guard must ask GIT, not the filesystem. sync_vault only resets tracked
# files, so an injected (untracked) index.md survives `reset --hard` and a plain
# `-f` test keeps that first injection forever — which is how the landing page
# got frozen at its pre-`publish: true` September bytes and, once explicit-
# publish landed, `/` started 404ing with the file quietly filtered out.
if [ -n "$index_sum" ] &&
  ! git -C "$BUILD/vault" ls-files --error-unmatch "$VAULT_SUBDIR/index.md" >/dev/null 2>&1; then
  cp "$INDEX_MD" "$BUILD/vault/$VAULT_SUBDIR/index.md"
fi

# Rewrite the Obsidian inline-snippet lines (clone only; sync_vault resets them
# to the vault's bytes on the next run, so this stays idempotent).
render_dates

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

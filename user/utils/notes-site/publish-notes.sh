#!/usr/bin/env bash
# Republish notes.tsiru.pet only when the vault's Concepts/ folder changed.
#
# Runs as notes-publish.service (see ./default.nix), fired every few minutes by
# notes-publish.timer. Compares a content hash of the vault folder against the
# hash recorded at the last successful publish, so edits, renames, and deletions
# all trigger exactly one rebuild — and an idle vault costs one `sha256sum`.
set -euo pipefail
# Dependencies (node, rsync, ssh, coreutils) come from the wrapper's
# runtimeInputs in default.nix.

VAULT="${VAULT:-$HOME/Documents/Obsidian-Vault/Concepts}"
SITE="${SITE:-$HOME/Documents/Projects/notes-site}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/notes-site"
HASHFILE="$STATE/published.sha"

mkdir -p "$STATE"

# Content hash: relative names + bytes, so edits, additions, renames and
# deletions all change it. `.obsidian/` churn (workspace layout, caches) is
# deliberately excluded; `publish.sh` and the Quartz config are included so a
# config change also republishes.
hash_vault() {
  {
    cd "$VAULT" && find . -type f -not -path './.obsidian/*' -print0 | sort -z | xargs -0 sha256sum
    sha256sum "$SITE/publish.sh" "$SITE/quartz-src/quartz.config.yaml"
  } | sha256sum | cut -d' ' -f1
}

current="$(hash_vault)"
if [ -f "$HASHFILE" ] && [ "$(cat "$HASHFILE")" = "$current" ]; then
  exit 0   # nothing changed since the last successful publish
fi

"$SITE/publish.sh"
printf '%s\n' "$current" >"$HASHFILE"

#!/usr/bin/env bash
# Long-running driver for the notes publisher (systemd Type=simple).
#
# The unit is meant to stay ACTIVE from power-on, so this loops forever instead
# of running once: publish, sleep, repeat. A oneshot + RemainAfterExit would
# *look* active but silently stop republishing, because a timer's start request
# against an already-active unit is a no-op.
#
#   usage: notes-publish-run <quartz-src> <quartz-config>
#
# Each iteration is cheap when nothing changed: the publisher exits early on an
# unchanged vault HEAD. On failure we exit and let Restart=always bring us back
# after RestartSec, so a broken state is visible in `systemctl status` rather
# than silently swallowed.
set -euo pipefail

PUBLISH="${PUBLISH:-notes-publish}"
INTERVAL="${INTERVAL:-300}"

: "${1:?usage: notes-publish-run <quartz-src> <quartz-config>}"

while :; do
  if "$PUBLISH" "$@"; then
    sleep "$INTERVAL"
  else
    echo "notes-publish: run failed (exit $?); exiting so systemd restarts us" >&2
    exit 1
  fi
done

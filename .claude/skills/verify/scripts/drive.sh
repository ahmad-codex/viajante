#!/usr/bin/env bash
# Run one command from this checkout against a disposable state dir and keep the proof.
#
#   drive.sh <run-dir> <label> <command...>
#
# <command> runs through `uv run --locked` from the repo root, so `viajante ...`,
# `viajante-mcp ...` and `python .claude/skills/verify/scripts/mcp_call.py ...` all use
# the checkout's code. Writes <run-dir>/evidence/<label>.{cmd,stdout,stderr,exit} and
# exits with the command's own exit code.
#
# The run gets VIAJANTE_STATE_DIR=<run-dir>/state. Provider cooldowns are machine-wide
# on purpose, so the real state dir's cooldown files are copied in first, and a cooldown
# this run records is copied back out so other viajante processes back off too.
set -uo pipefail

if [ $# -lt 3 ]; then
  echo "usage: drive.sh <run-dir> <label> <command...>" >&2
  exit 64
fi
run_dir=$(mkdir -p "$1" && cd "$1" && pwd)
label=$2
shift 2

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
state="$run_dir/state"
evidence="$run_dir/evidence"
mkdir -p "$state" "$evidence"

real_state="${VIAJANTE_STATE_DIR:-${XDG_STATE_HOME:+$XDG_STATE_HOME/viajante}}"
real_state="${real_state:-$HOME/.local/state/viajante}"
cooldowns="google-rate-limit.json skiplagged-rate-limit.json"

for f in $cooldowns; do
  if [ -f "$real_state/$f" ] && [ ! -f "$state/$f" ]; then
    cp "$real_state/$f" "$state/$f"
  fi
done

printf '%q ' "$@" >"$evidence/$label.cmd"
echo >>"$evidence/$label.cmd"
echo "[verify] $label: $(cat "$evidence/$label.cmd")" >&2

(cd "$repo" && VIAJANTE_STATE_DIR="$state" uv run --locked "$@") \
  > >(tee "$evidence/$label.stdout") \
  2> >(tee "$evidence/$label.stderr" >&2)
code=$?
wait
echo "$code" >"$evidence/$label.exit"

for f in $cooldowns; do
  [ -f "$state/$f" ] || continue
  newer=$(python3 - "$state/$f" "$real_state/$f" <<'PY'
import json, sys
def until(path):
    try:
        return float(json.load(open(path))["until"])
    except Exception:
        return 0.0
print(1 if until(sys.argv[1]) > until(sys.argv[2]) else 0)
PY
)
  if [ "$newer" = 1 ]; then
    mkdir -p "$real_state"
    cp "$state/$f" "$real_state/$f"
    cp "$state/$f" "$evidence/$label.$f"
    echo "[verify] PROVIDER COOLDOWN recorded ($f); copied to $real_state. Stop live searches." >&2
  fi
done

for dump in "$state"/booking-last-failure.*; do
  [ -e "$dump" ] && cp "$dump" "$evidence/$label.$(basename "$dump")"
done

echo "[verify] $label exit=$code evidence=$evidence" >&2
exit "$code"

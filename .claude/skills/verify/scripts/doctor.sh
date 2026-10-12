#!/usr/bin/env bash
# Read-only: is this checkout worth driving, and may a run send live provider requests?
#
#   doctor.sh
#
# Prints one line per check. Exit 0 when the checkout runs; the LIVE line says whether
# live Google / Skiplagged searches are allowed right now. Writes nothing.
set -uo pipefail

repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$repo" || exit 1
bad=0

echo "repo      $repo @ $(git rev-parse --abbrev-ref HEAD) $(git rev-parse --short HEAD)$(git diff --quiet HEAD -- src || echo ' (src dirty)')"

want=$(sed -n 's/^version = "\(.*\)"/\1/p' pyproject.toml)
got=$(uv run --locked viajante --version 2>&1 | awk '{print $2}')
if [ "$got" = "$want" ]; then echo "version   ok $got"; else echo "version   MISMATCH pyproject=$want cli=$got"; bad=1; fi

where=$(uv run --locked python -c 'import viajante; print(viajante.__file__)' 2>&1)
case "$where" in
  "$repo/src/"*) echo "import    ok $where" ;;
  *) echo "import    NOT THIS CHECKOUT: $where"; bad=1 ;;
esac

if [ -x .venv/bin/viajante-mcp ]; then echo "mcp       ok .venv/bin/viajante-mcp"; else echo "mcp       MISSING .venv/bin/viajante-mcp (run uv sync --locked)"; bad=1; fi

chromium=$(uv run --locked python -c '
from pathlib import Path
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    path = p.chromium.executable_path
print(("ok " if Path(path).exists() else "MISSING ") + path)' 2>&1 | tail -1)
echo "chromium  $chromium  (only --fetch detail and Booking hotels need it)"

real_state="${VIAJANTE_STATE_DIR:-${XDG_STATE_HOME:+$XDG_STATE_HOME/viajante}}"
real_state="${real_state:-$HOME/.local/state/viajante}"
echo "state     real=$real_state (verify runs never use it directly)"
live=$(python3 - "$real_state" <<'PY'
import json, sys, time
from datetime import datetime, timezone
out = []
for name in ("google-rate-limit.json", "skiplagged-rate-limit.json"):
    try:
        until = float(json.load(open(f"{sys.argv[1]}/{name}"))["until"])
    except Exception:
        continue
    if until > time.time():
        clock = datetime.fromtimestamp(until, timezone.utc).strftime("%H:%M:%S UTC")
        out.append(f"{name.split('-')[0]} cooling down until {clock}")
print("BLOCKED " + "; ".join(out) if out else "ok no active provider cooldown")
PY
)
echo "live      $live"

others=$(pgrep -f 'bin/viajante-mcp' | wc -l | tr -d ' ')
[ "$others" != 0 ] && echo "note      $others other viajante-mcp process(es) running (installed copies, not this checkout; leave them)"

exit "$bad"

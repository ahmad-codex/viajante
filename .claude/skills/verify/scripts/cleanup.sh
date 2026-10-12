#!/usr/bin/env bash
# Tear down what one verify run started; keep its evidence.
#
#   cleanup.sh <run-dir>
#
# Kills only PIDs listed in <run-dir>/pids (one per line, written by whoever started a
# background server), then deletes <run-dir>/state. <run-dir>/evidence is never touched.
set -uo pipefail

if [ $# -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: cleanup.sh <run-dir>" >&2
  exit 64
fi
run_dir=$(cd "$1" && pwd)

if [ -f "$run_dir/pids" ]; then
  while read -r pid; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null && echo "[verify] stopped pid $pid"
  done <"$run_dir/pids"
  rm -f "$run_dir/pids"
fi

rm -rf "$run_dir/state"
echo "[verify] removed $run_dir/state; evidence kept at $run_dir/evidence"
ls "$run_dir/evidence" 2>/dev/null | sed 's/^/  /'

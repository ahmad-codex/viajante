# MCP server

An AI client connects to `viajante-mcp` over stdio, or over opt-in loopback Streamable HTTP,
and sees 22 tools. Every tool except `lookup_airports` returns one envelope (`status`,
`completeness`, `empty_reason`, `empty_note`, `error_code`, `retry_after`,
`retry_after_seconds`, `observed_at`, `observed_at_basis`) beside its payload. Invalid input
is an `isError` result whose text is the SDK prefix followed by a JSON error body.

## Sub-features

- `mcp-list` covers `tools/list`: 22 tools, each with an output schema except
  `lookup_airports`.
- `mcp-envelope` is the shared envelope on every structured result.
- `mcp-invalid` is the result for undeclared or mistyped arguments:
  `Error executing tool <name>: {"error": {"code": "invalid_parameter", "field": ..., "message": ...}}`.
- `mcp-guide` is `get_guide`, plus the `viajante://guide` resource.
- `mcp-runtime` is `get_runtime_info`. It reports the executing `viajante_version`.
- `mcp-ledger` covers `verify_answer`, which flags amounts, currencies, airport codes, dates,
  and links that no search in this process returned (not flight numbers).
- `mcp-lock` means one search runs per process. A concurrent one gets `search_in_progress`.
- `mcp-cache` replays an identical successful search for 5 minutes with `cached: true`.
- `mcp-http` is `viajante-mcp --transport streamable-http` on `127.0.0.1:8000/mcp`.

## How to get to it (user POV)

- A client config runs `viajante-mcp` (stdio). The published installs are
  `npx -y @viajante/mcp` and `uvx --from viajante[mcp] viajante-mcp`. For this checkout, the
  equivalent is `.venv/bin/viajante-mcp`, which `mcp_call.py` starts.
- For HTTP, run `viajante-mcp --transport streamable-http [--host 127.0.0.1] [--port 8000]`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `mcp ok`. The recipes below are offline except `mcp-ledger`'s search and
  `mcp-cache`.

- **List, runtime, and invalid input (`mcp-list`, `mcp-runtime`, `mcp-invalid`).** Run `drive.sh "$RUN" mcp-basics python .claude/skills/verify/scripts/mcp_call.py get_runtime_info '{}' get_guide '{}' get_runtime_info '{"verbos": true}'`.
  The `list_tools` line names 22 tools. The first call's `structured` has all nine envelope
  keys, `status` `ok`, and `viajante_version` equal to `pyproject.toml`'s. `get_guide` has a
  `guide` string. The last call has `is_error: true` and text that starts with
  `Error executing tool get_runtime_info: {` and carries `"code": "invalid_parameter"` and
  `"field": "verbos"`. Exit `1` is expected, because one call errored on purpose.
- **Repo smoke.** Run `drive.sh "$RUN" mcp-smoke python scripts/mcp-smoke.py`. It prints
  `mcp smoke ok`. This is the same check CI runs.
- **Ledger (`mcp-ledger`, live).** Run `drive.sh "$RUN" mcp-ledger python .claude/skills/verify/scripts/mcp_call.py search_flights '{"routes": ["JFK-LHR:2026-11-18"], "fetch": "sweep", "top": 3}' verify_answer '{"answer": "The cheapest fare is 1 USD from JFK to CDG."}'`.
  `verify_answer` comes back with `status` `failed` and `unowned` listing
  `{"kind": "amount", "text": "1 USD"}` and `{"kind": "airport", "text": "CDG"}`. It checks
  amounts, currencies, IATA codes, ISO dates, and links, but not flight numbers, so an
  invented `XX123` passes by design. Use a tiny amount like `1 USD` to catch the
  zero-buffer and score-breakdown false matches (fixed after 1.5.0).
- **Cache (`mcp-cache`, live).** Pass the same `search_flights` call twice in one
  invocation. The second `structured` carries `cached: true`, and no extra request is sent.
- **HTTP (`mcp-http`).** Start it in the background and record its PID:
  `(VIAJANTE_STATE_DIR="$RUN/state" .venv/bin/viajante-mcp --transport streamable-http --port 8765 > "$RUN/evidence/mcp-http.log" 2>&1 & echo $! >> "$RUN/pids")`.
  Ready means `curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"verify","version":"0"}}}' http://127.0.0.1:8765/mcp`
  returns `200`. A foreign `Host` header (`-H 'Host: evil.example'`) must get `421`.
  `cleanup.sh "$RUN"` stops it.

## Gotchas

- `initialize` reports an empty `server.version`. Read the version from `get_runtime_info`.
- `lookup_airports` has no structured content. `mcp_call.py` puts its rows in `text`, one
  JSON block per airport.
- The search lock is per process. Two `mcp_call.py` runs are two processes and won't contend.
  To prove `search_in_progress`, use one session with concurrent calls, which `mcp_call.py`
  doesn't do. Use the unit tests in `tests/test_mcp_control.py` for that.
- Use a port other than 8000 for HTTP. The user may run their own server there.
- The session's `mcp__viajante__*` tools are an installed copy. Never cite them as proof.

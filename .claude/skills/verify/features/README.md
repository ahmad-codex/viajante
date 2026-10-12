# viajante verification map

This directory is the maintained source for verifying viajante's user-facing behavior. Read
this index, then use the matching feature file as the recipe. Most features have two entry
points: a `viajante` CLI command and an MCP tool. A proof that drives only one of them covers
only that one. Say which you drove.

## Baseline preconditions

- Run everything from the repo root. `uv sync --locked` has run.
- `.claude/skills/verify/scripts/doctor.sh` prints `version ok`, `import ok` pointing into
  this checkout's `src/`, and `mcp ok`.
- Before any live search, the doctor's `live` line reads `ok`. On `BLOCKED`, run offline
  recipes only and report the time.
- `RUN=~/.cache/viajante-verify/$(date +%Y%m%d-%H%M%S)-<feature>`. This is a fresh run dir,
  outside the checkout.
- Every command goes through `drive.sh "$RUN" <label> ...`, which gives it
  `VIAJANTE_STATE_DIR=$RUN/state`. Never drive the user's own `mcp__viajante__*` tools or
  their installed `viajante-mcp` processes. Those are other versions.

## Driving conventions

- Use dates in the future. Keep live searches to one route, one or two dates, and `--top 3`.
- Name the currency or an origin airport whose country proves it (JFK→USD, LHR→GBP). Hotels
  always need `--currency`.
- CLI JSON comes only from `--save "$RUN/evidence/<label>.json"`. MCP JSON is the
  `structured` field of `mcp_call.py`'s `call_tool` lines.
- `--fetch auto` and `sweep` read the public Google results page over HTTP. `detail` is
  Playwright (Chromium), slow by design (about 4.5 s plus jitter per query). Use it only when
  the feature needs it.
- On `PROVIDER COOLDOWN recorded`, stop all live recipes.

## Proof and skip reporting

- CLI proof: the `.cmd`, `.stdout`, `.stderr`, and `.exit` files, plus the `--save` JSON when
  the change touches fields.
- MCP proof: the `call_tool` line, with `status`, `completeness`, `empty_reason`, and
  `error_code` read before the rows.
- State proof: the file in `$RUN/state`, plus a second read through a user command
  (`history`, `watch --list`, `price_history`).
- Name the run dir, the feature ID, and the entry point for every artifact.
- If a path is unreachable (a cooldown, no Chromium, a provider `blocked`), report the
  attempted command and the outcome. Don't report it as verified through a different path.
- Only `empty_reason: provider_empty` (CLI: a `no_results` query whose evidence says the page
  had no cards) may be described as "none found".

## Feature entry contract

Each feature file starts with an H1 and one paragraph of user-visible behavior, then exactly
four H2s in this order: `Sub-features`, `How to get to it (user POV)`,
`Driving it with drive.sh`, and `Gotchas`.

## Features

- [Flight search](./flights.md): one-way, round trip, multi-city, filters, metro/nearby,
  recommendation, split tickets (`flights`, `search_flights`, `search_split_tickets`).
- [Date and destination search](./dates-flex-explore.md): cheapest day in a window,
  ±N flex, explore destinations (`dates`/`flex`/`explore`, `search_dates`/`search_flex`/
  `search_explore`).
- [Hotels and trips](./hotels-trip.md): Booking, Google, and Skiplagged hotel search, room
  rates, finalist details, flights plus hotel (`hotels`, `hotel-rooms`, `trip`, and their
  MCP tools).
- [MCP server](./mcp-server.md): stdio and loopback HTTP transports, tool list, envelope,
  input errors, guide, evidence ledger.
- [Local tools](./local-tools.md): airports, awards, points, itinerary validation, stay
  blocks, feedback. No network.
- [Recheck, watch, and history](./recheck-watch-history.md): re-check a finalist, saved
  watches, the opt-in price log.

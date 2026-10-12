# Date and destination search

A user asks which day in a window is cheapest for one route (`dates`), which day within ±N of
a named date is cheapest followed by one full search on it (`flex`), or where they can fly
cheaply from one origin (`explore`). Days and destinations without a price are unknown, not
empty.

## Sub-features

- `dt-window` returns the cheapest fare per day across `--from`/`--to`. That's one public
  page per day.
- `dt-nights` covers round-trip windows with `--nights N`.
- `dt-typical` computes `typical` only from 3 or more priced days of the requested window
  on the same route. Otherwise it's null.
- `fx-flex` finds the cheapest day in `--around ± --flex`, then runs one shopping search on
  that day.
- `ex-explore` returns destinations from one origin for `--from`/`--days` or `--month`, via
  the Explore catalog. A Chromium run captures the page's own catalog request.
- `dfe-mcp` covers MCP `search_dates`, `search_flex`, and `search_explore`.

## How to get to it (user POV)

- `viajante dates ROUTE --from DATE --to DATE [--nights N]`
- `viajante flex ROUTE --around DATE --flex N [--nights N]`
- `viajante explore ORIGIN (--from DATE [--days N] | --month YYYY-MM)`
- MCP `search_dates(route, start, end, ...)`, `search_flex(route, around, flex, ...)`, and
  `search_explore(origin, start, days|month, ...)`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `live ok`. Windows lie wholly in the future. Explore needs Chromium (see
  the doctor's `chromium` line).

- **Short window (`dt-window`).** Run `drive.sh "$RUN" dt-window viajante dates JFK-LHR --from 2026-11-17 --to 2026-11-19 --save "$RUN/evidence/dt-window.json"`.
  The result is exit `0` or `3`, with one row per day in `days[]` (`date`, `status`,
  `price`), each priced or carrying its own reason, plus `summary.n_priced`. With 3 priced
  days, each `days[].typical` is the window median and `vs_typical` is set. Fewer must
  leave them null.
- **Flex (`fx-flex`).** Run `drive.sh "$RUN" fx-flex viajante flex JFK-LHR --around 2026-11-18 --flex 1 --save "$RUN/evidence/fx-flex.json"`.
  The output shows the per-day calendar, then one full offer search on the cheapest day.
- **Explore (`ex-explore`).** Run `drive.sh "$RUN" ex-explore viajante explore JFK --from 2026-11-18 --days 7 --top 5 --save "$RUN/evidence/ex-explore.json"`.
  The result lists destinations with prices. Any unpriced destination is `not_loaded`.
- **MCP (`dfe-mcp`).** Run `drive.sh "$RUN" dt-mcp python .claude/skills/verify/scripts/mcp_call.py search_dates '{"route": "JFK-LHR", "start": "2026-11-17", "end": "2026-11-19"}'`.
  Read `structured.status`, `completeness`, and `empty_reason`, then the day rows.

## Gotchas

- Each day is one live page. A 30-day window is 30 requests, so keep proofs to 2–3 days.
- A day row with no reason of its own is `not_loaded`. A day whose page returned no cards
  is `provider_empty`. Don't merge them.
- `typical` is never a market average. Don't widen the window just to make it appear.
- Metro codes are rejected by `dates`, `flex`, and `explore`. Exit `1` is correct there.
- An Explore catalog status 13 records a cooldown like any other. Stop if it happens.
  The catalog is the most sensitive endpoint seen so far. On 2026-10-12 it returned status
  13 after about 8 other live searches in 3 minutes. Run explore first in a session, or
  alone, before other live recipes.

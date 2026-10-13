# Flight search

A user names one or more `ORIGIN-DEST:DATE` routes and gets Google Flights offers with fare,
duration, stops, clocks, carriers, and a Google Flights link. Then come per-query stop
comparisons and a `recommendation` shortlist with role labels. One-way public searches send
the clock, duration, max-layover, price-cap, emissions, and separate-ticket options to Google
and check each one locally; the rest are applied locally after the parse. Filters viajante
cannot honor are refused before any network call.

## Sub-features

- `fl-oneway` is a one-way search on the public results page (`--fetch auto|sweep`).
- `fl-twoways` covers `ORIGIN-DEST:OUT:BACK` without `--trip`, which runs two one-way queries.
- `fl-rt` is a packaged round trip (`--trip rt`). It checks at most 8 outbound candidates
  with one return page each, and the price is the provider's package total.
- `fl-multi` is multi-city (`--trip multi`). It requires `--fetch detail` (Chromium).
- `fl-filters` covers the clock (`--depart-window`, `--depart-after`, `--depart-before`,
  `--arrive-before`, `--arrive-after`), duration, max-layover, price-cap, emissions
  (`--less-emissions`), and separate-ticket (`--hide-separate-tickets`) options. On a one-way
  search Google receives them, must echo each one, and viajante checks every row locally
  before `--top`. Min layover, via, overnight, and airport filters are local only.
- `fl-carriers` covers `--airlines`, `--exclude-airlines`, and `--alliance`. Excluded and
  carrier-unknown cards are dropped.
- `fl-refusals` covers capabilities refused before any request (`--bags 1`,
  `--exclude-alliance` on the public path, and multi-city on sweep), each a failed query
  with `Not sent.`, plus argparse refusals such as `--max-stops 3` (exit 1). Also refused
  before any request: `--exclude-basic-economy` (every path), and `--less-emissions` or
  `--hide-separate-tickets` on `--fetch detail`, round-trip, and multi-city (exit 1).
- `fl-metro` covers metro codes (`LON`, `NYC`, `TYO`) and `--nearby` expansion into labeled
  alternatives.
- `fl-reco` is the `recommendation` block: `top_score`, `lowest_price`, `shortest`, and
  `alternative`, each with highlights and trade-offs that restate fields.
- `fl-split` is opt-in split tickets (`--split-tickets`, MCP `search_split_tickets`).
- `fl-mcp` is the same search through MCP `search_flights`.

## How to get to it (user POV)

- `viajante flights <ROUTE...> [flags]` prints a table, plus JSON with `--save FILE`.
- MCP `search_flights(routes=[...], trip=..., ...)`. Arguments are in
  `src/viajante/mcp_handlers.py` (`search_flights_tool`).
- MCP `search_split_tickets(...)`, or the CLI `flights ... --split-tickets [--split-via CODES]`.
- Library: `from viajante import get_flights`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `live ok`. `$RUN` is fresh. Dates are in the future. The examples use
  2026-11-18; move them forward if that date has passed.

- **One-way (`fl-oneway`).** Run `drive.sh "$RUN" fl-oneway viajante flights JFK-LHR:2026-11-18 --fetch sweep --top 3 --save "$RUN/evidence/fl-oneway.json"`.
  The result is exit `0`. Stdout shows `=== JFK -> LHR  2026-11-18`, then offer rows with
  `USD` and `https://www.google.com/travel/flights?...` links, then the
  `Cheapest nonstop:`/`Cheapest 1-stop:` lines and `Recommendation`. In the JSON,
  `queries[0].status == "ok"`, `offers` has at most 3 items, and `currency == "USD"`.
- **Local filter (`fl-filters`).** Run `drive.sh "$RUN" fl-filter viajante flights JFK-LHR:2026-11-18 --fetch sweep --max-stops 0 --depart-window 06:00-12:00 --top 3 --save "$RUN/evidence/fl-filter.json"`.
  Every offer is nonstop and departs between 06:00 and 12:00. `raw_count` is at least
  `eligible_count`. If nothing survives, the query reads as filtered, not `no_results`.
- **Refusal (`fl-refusals`).** Run `drive.sh "$RUN" fl-refuse viajante flights JFK-LHR:2026-11-18 --bags 1 --fetch sweep`.
  The result is exit `2` with `ERROR: Not sent. Google Flights public-page transport cannot verify these requested capabilities: bags.`
  plus the query URL. `$RUN/state` gains no new file, and the mtimes of seeded files don't
  change. This needs no live gate.
- **Round trip (`fl-rt`).** Run `drive.sh "$RUN" fl-rt viajante flights --trip rt JFK-LHR:2026-11-18:2026-11-25 --fetch sweep --top 3 --save "$RUN/evidence/fl-rt.json"`.
  Offers carry return legs, and the fare is one package total. This sends up to 9 page GETs.
- **Metro (`fl-metro`).** Run `drive.sh "$RUN" fl-metro viajante flights NYC-LON:2026-11-18 --fetch sweep --top 2 --currency USD --save "$RUN/evidence/fl-metro.json"`.
  The result has one labeled query per airport pair. This is many GETs; skip it unless the
  change touches metro expansion.
- **MCP (`fl-mcp`).** Run `drive.sh "$RUN" fl-mcp python .claude/skills/verify/scripts/mcp_call.py search_flights '{"routes": ["JFK-LHR:2026-11-18"], "fetch": "sweep", "top": 3}'`.
  The `call_tool` line has `is_error: false`, `structured.status` `ok`, `completeness`
  `complete`, and the same report keys as the CLI JSON (`structured.queries[0].offers`).
  Read the envelope keys first.
- **Split tickets (`fl-split`).** Run `drive.sh "$RUN" fl-split viajante flights JFK-NRT:2026-11-18 --split-tickets --split-via LAX --save "$RUN/evidence/fl-split.json"`.
  Every itinerary has `split_ticket: true` and `connection_protected: false`, and `total`
  appears only when both tickets share one currency.

## Gotchas

- `JFK-LHR:OUT:BACK` without `--trip rt` is two one-ways, not a round trip. Check the
  query count.
- A missing filter echo on the page is `markup_drift`, never an unfiltered success. Report it.
- The CLI prints the `Recommendation` labels. Don't mistake them for a verdict viajante
  added. They are roles.
- `--fetch detail` refuses every bag and carrier filter. Pair detail only with plain routes.
- A fare comparison across currencies is refused by design (`currency_mismatch`, or an
  unranked recommendation). It is not a bug.
- Fares move between runs. Assert shape and filters, not a specific price.

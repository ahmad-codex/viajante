# Recheck, watch, and history

A user re-checks a finalist offer from an earlier search with one fresh search, saves a
flight or hotel query as a named watch, and re-runs it on demand to see the change. If they
opt in, they can also read the local price log this machine observed. There's no scheduler
and no notification. Series are never merged across currencies or forecast.

## Sub-features

- `rc-recheck` covers `recheck-offer` / `recheck_offer`. The outcome is one of `same_price`,
  `price_changed`, `not_found`, `multiple_matches`, `incomplete_identity`, or
  `check_failed`.
- `rc-identity` means an offer without a full segment identity is `incomplete_identity`, and
  no search is sent.
- `wt-save` saves a watch with `--kind` and `--params` and runs it at once, so it's live.
- `wt-list` lists watches (local).
- `wt-run` re-runs a saved watch, records the observation, and reports the change.
- `hs-record` covers `VIAJANTE_PRICE_HISTORY=1`: a successful search with an offer appends to
  `price-history.jsonl`.
- `hs-read` covers `history` / `price_history`: one series per query key per currency.

## How to get to it (user POV)

- `viajante recheck-offer --offer FILE [--query FILE] [--currency CODE]`
- `viajante watch NAME --kind flight --params JSON`, `viajante watch NAME`,
  `viajante watch --list`, and `viajante watch NAME --remove`
- `viajante history [--route ORIG-DEST] [--date D] [--kind ...]`
- MCP `recheck_offer`, `watch_price`, and `price_history`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `live ok` for the live steps. The run uses one `$RUN`, so state carries
  across steps.

- **Get an offer.** Run the `fl-oneway` recipe from [flights.md](./flights.md) with
  `--save "$RUN/evidence/fl-oneway.json"`. Then run
  `python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); q=d["queries"][0]; json.dump({"query": q["query"], "offer": q["offers"][0]}, open(sys.argv[2], "w"))' "$RUN/evidence/fl-oneway.json" "$RUN/evidence/offer.json"`.
- **Recheck (`rc-recheck`, live).** Run `drive.sh "$RUN" rc-recheck viajante recheck-offer --offer "$RUN/evidence/offer.json" --save "$RUN/evidence/rc-recheck.json"`.
  The result is exit `0` with an outcome line, typically `same_price` or `price_changed`.
  A rate limit is `check_failed` (exit `2`), never `not_found`.
- **Incomplete identity (`rc-identity`).** Strip the flight numbers from the saved offer:
  `python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); r["offer"]["flight_numbers"]=[]; [s.pop("flight_number",None) for l in r["offer"]["legs"] for s in l["segments"]]; json.dump(r, open(sys.argv[2],"w"))' "$RUN/evidence/offer.json" "$RUN/evidence/offer-noid.json"`.
  Then run `drive.sh "$RUN" rc-ident viajante recheck-offer --offer "$RUN/evidence/offer-noid.json"`.
  The result is exit `2` with `missing  journey 0 segment 1: flight number`, and the note
  says no search was sent. The `$RUN/state` file mtimes are unchanged. This needs no live
  gate once `offer.json` exists.
- **Save, list, and run a watch (`wt-save`, `wt-list`, `wt-run`, live).** Run `drive.sh "$RUN" wt-save viajante watch verify-jfk-lhr --kind flight --params '{"routes": ["JFK-LHR:2026-11-18"], "fetch": "sweep", "top": 3}'`.
  `--params` takes MCP `search_flights` argument names. Saving also runs the search once.
  Then run `drive.sh "$RUN" wt-list viajante watch --list`, which names `verify-jfk-lhr`;
  `$RUN/state/price-watches.json` exists. A second `drive.sh "$RUN" wt-run viajante watch verify-jfk-lhr`
  compares against the first observation. Run `drive.sh "$RUN" hs-read viajante history --route JFK-LHR --date 2026-11-18`
  to read both observations back from `$RUN/state/price-history.jsonl`.
- **Opt-in recording (`hs-record`, live).** Run `drive.sh "$RUN" hs-rec env VIAJANTE_PRICE_HISTORY=1 viajante flights JFK-LHR:2026-11-18 --fetch sweep --top 3`.
  One line is appended to `$RUN/state/price-history.jsonl`. Without the env var, nothing is
  appended.

## Gotchas

- `check_failed` isn't evidence that an offer is gone. Never report it as "sold out".
- `recheck-offer` with a `--currency` different from the offer's own currency is refused,
  never converted.
- One observation is not a trend. `history` with a single row reports no change.
- The watch and history files live in `$RUN/state` and are deleted by cleanup. Copy them into
  `$RUN/evidence` first if they're part of the proof.
- `watch_price` is the one MCP tool that writes. Its annotations say `readOnlyHint: false`.

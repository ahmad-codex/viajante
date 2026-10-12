# Local tools

These commands make no provider call. They work offline, run instantly, and may run during a
live search: airport lookup, award-vs-cash math, card transfer tables, evidence-bound itinerary
validation, stay-block planning and cost splits, and a prefilled feedback link.

## Sub-features

- `lc-airports` is offline IATA lookup by code or city fragment. City queries list codes and
  never pick one.
- `lc-awards` compares a named award offer to a cash fare (`awards`, `compare_awards`).
- `lc-points` is the card-to-program transfer table (`points`, `lookup_transfers`).
- `lc-validate` is `validate_itinerary`. Its verdict is pass, fail, or unknown, and unknown
  never counts as a pass.
- `lc-stays` covers `plan_stay_blocks` and `split_stay_costs` (MCP only), with exact cents.
- `lc-feedback` is `viajante feedback --no-browser`, which prints a GitHub issue link and
  sends nothing.

## How to get to it (user POV)

- `viajante airports QUERY`, `viajante awards --offer FILE ...`,
  `viajante points --program P --points N`, and `viajante feedback [--no-browser] [MSG]`.
- MCP `lookup_airports`, `compare_awards`, `lookup_transfers`, `validate_itinerary`,
  `plan_stay_blocks`, and `split_stay_costs`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `import ok`. No live gate is needed.

- **Airports, CLI (`lc-airports`).** Run `drive.sh "$RUN" lc-airports viajante airports tokyo`.
  The result is exit `0` with both `HND` and `NRT` listed (metro `TYO`).
- **Airports, MCP.** Run `drive.sh "$RUN" lc-airports-mcp python .claude/skills/verify/scripts/mcp_call.py lookup_airports '{"query": "tokyo"}'`.
  The `text` list holds one JSON block per airport, each with `"iata"` `HND` or `NRT`.
- **Points (`lc-points`).** Run `drive.sh "$RUN" lc-points viajante points --program aeroplan --points 70000`.
  The output is the local transfer table for Aeroplan. It contains no live seats.
- **Feedback (`lc-feedback`).** Run `drive.sh "$RUN" lc-feedback viajante feedback --no-browser "verify run"`.
  Stdout is a `https://github.com/felipebasurto/viajante/issues/new?...` link carrying the
  version. No browser opens.
- **No network.** After any of these runs, `ls "$RUN/state"` shows no `google-*.json` or
  `skiplagged-*.json` that wasn't already seeded from the real state dir. Compare it to the
  `[verify]` seeding. `drive.sh` copies existing cooldown files in.

## Gotchas

- `airports london` lists codes. It doesn't choose `LHR`, and that's correct behavior.
- `awards` without `--cash` omits CPP rather than inventing one.
- `feedback` without `--no-browser` opens the user's browser. Always pass `--no-browser`
  in verification.
- A seeded cooldown file in `$RUN/state` came from the real state dir, not from the local
  tool. Check its mtime against the run start before calling it a side effect.

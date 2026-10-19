# Hotels and trips

A user searches hotels for a location and stay dates in a named currency and gets total-stay
prices, ratings, and cancellation evidence. They can also price rooms at one Skiplagged
hotel, pull a finalist's details, or run flights plus hotel together (`trip`), which shows a
combined total only when both sides are priced in one currency over overlapping dates.

## Sub-features

- `ht-booking` is the default Booking search, driven by Playwright Chromium. Free
  cancellation is required unless `--allow-non-refundable` is passed.
- `ht-google` is `--source google`, an HTTP shortlist.
- `ht-skiplagged` is `--source skiplagged`. It's USD only, with at most 10 adults and 9 rooms.
- `ht-rooms` covers `hotel-rooms` / `search_hotel_rooms`: room rates for one Skiplagged hotel.
- `ht-details` is MCP `get_hotel_details(selection_id, room_rates)`, a finalist snapshot.
- `ht-compare` is `--compare-cancellation`: two sequential Booking searches, joined.
- `tr-trip` covers `trip` / `search_trip`: flights then hotel under one lock, plus
  `trip_total`.

## How to get to it (user POV)

- `viajante hotels LOCATION CHECK_IN CHECK_OUT --currency CODE [--source ...]`
- `viajante hotel-rooms (--hotel-id ID | --name NAME --city CITY) ...`
- `viajante trip ROUTE --hotel LOCATION [--trip rt] ...`
- MCP `search_hotels`, `search_hotel_rooms`, `get_hotel_details`, and `search_trip`.

## Driving it with drive.sh

Preconditions:

- The doctor shows `live ok`. The Booking path needs the `chromium ok` line. Dates are in
  the future.

- **Google hotels (`ht-google`).** Run `drive.sh "$RUN" ht-google viajante hotels Singapore 2026-11-18 2026-11-21 --currency SGD --source google --top 3 --save "$RUN/evidence/ht-google.json"`.
  The result has at most 3 rows with total-stay `SGD` prices, Google ratings on a 0–5 scale,
  and `viajante_version` in the JSON.
- **Booking (`ht-booking`).** Run `drive.sh "$RUN" ht-booking viajante hotels Singapore 2026-11-18 2026-11-21 --currency SGD --top 3 --save "$RUN/evidence/ht-booking.json"`.
  Ratings are on a 0–10 scale, with cancellation evidence per row. On failure, check
  `$RUN/evidence/ht-booking.booking-last-failure.*`.
- **Missing currency.** Run `drive.sh "$RUN" ht-nocur viajante hotels Singapore 2026-11-18 2026-11-21`.
  The result is exit `1` and no request. It needs no live gate.
- **Trip (`tr-trip`).** Run `drive.sh "$RUN" tr-trip viajante trip JFK-SIN:2026-11-18:2026-11-21 --hotel Singapore --trip rt --source google --currency USD --save "$RUN/evidence/tr-trip.json"`.
  The output shows the flight fare, the hotel total stay, and a sum only when both are
  priced in the same currency.
- **MCP (`ht-details`).** In one session, run `search_hotels` and then `get_hotel_details`
  on a returned `selection_id`. Run `drive.sh "$RUN" ht-mcp python .claude/skills/verify/scripts/mcp_call.py search_hotels '{"location": "Singapore", "check_in": "2026-11-18", "check_out": "2026-11-21", "currency": "SGD", "source": "google", "top": 3}'`.
  Then copy a `selection_id` from that output into a second session. Ids are valid only
  within the server process, so a second session gets `no_results`. That's correct, not a
  bug, and it means `ht-details` needs both calls passed to one `mcp_call.py` invocation.

## Gotchas

- Booking shows challenges. Viajante doesn't retry them hard, and neither should you. A
  challenge is a `blocked` result, not empty.
- "filter applied; card silent" isn't confirmed free cancellation. Assert the observed
  evidence fields, not the requested filter.
- Hotel occupancy is adults only. A `trip` with children is refused.
- `trip_total` is absent when either side failed, the currencies differ, or the dates don't
  overlap. Absence is the correct proof in those cases.
- Skiplagged `resolved_place` may differ from the typed location. Report what it searched.

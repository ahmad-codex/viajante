"""Map a one-way search's named filters onto the options Google's public page accepts.

Every pushed bound is a superset of the exact local post-filter it mirrors, so the
page never removes a row the local filter would keep. A clock bound rounds outward
to Google's whole-hour bucket; a duration or layover rounds up. The local filter
then runs on every row, so the caller's named bounds still decide what is returned.

Options the page does not echo (minimum layover, connecting airports, basic-economy
exclusion) are not pushed; their local filters stay exact.
"""

from __future__ import annotations

import math
from typing import Optional

from viajante.flight_filters import OfferFilters
from viajante.models import FlightQuery, ProviderShop


def _hour_bucket(minutes: Optional[int]) -> Optional[int]:
    """Google keeps a whole hour, so a minute bound rounds down to its hour."""
    return None if minutes is None else minutes // 60


def _ceil_minutes(hours: Optional[float]) -> Optional[int]:
    """A duration or max layover rounds up to whole minutes, never down."""
    if hours is None:
        return None
    return math.ceil(round(hours * 60, 6))


def _departure_bounds(filters: OfferFilters) -> tuple[Optional[int], Optional[int]]:
    """The tightest lower and upper departure bounds, in minutes from midnight.

    The local filter keeps a row only when it meets every bound, so the tightest
    bound is the one the page must not loosen.
    """
    lows = [filters.depart_after]
    highs = [filters.depart_before]
    if filters.depart_window is not None:
        start, end = filters.depart_window
        lows.append(start)
        highs.append(end)
    known_lows = [v for v in lows if v is not None]
    known_highs = [v for v in highs if v is not None]
    return (max(known_lows) if known_lows else None, min(known_highs) if known_highs else None)


def provider_options(
    query: FlightQuery,
    filters: OfferFilters,
    *,
    less_emissions: bool = False,
    hide_separate_tickets: bool = False,
) -> Optional[ProviderShop]:
    """The page options for one one-way query, or ``None`` when nothing is pushed."""
    earliest_departure, latest_departure = _departure_bounds(filters)
    shop = ProviderShop(
        max_price=query.price_cap,
        earliest_departure_hour=_hour_bucket(earliest_departure),
        latest_departure_hour=_hour_bucket(latest_departure),
        earliest_arrival_hour=_hour_bucket(filters.arrive_after),
        latest_arrival_hour=_hour_bucket(filters.arrive_before),
        max_duration_minutes=_ceil_minutes(filters.max_duration_hours),
        max_layover_minutes=_ceil_minutes(filters.max_layover_hours),
        less_emissions=less_emissions,
        hide_separate_tickets=hide_separate_tickets,
    )
    return None if shop.is_empty() else shop

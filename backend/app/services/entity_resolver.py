"""Backend entity resolution — maps a free-text mention (or the raw description)
to candidate asset/room ids from the live database.

The LLM is only ever asked for a *mention* ("Projektor", "Kombuis"); resolving
that mention to concrete DB ids happens here, against the real tables, with the
same keyword/fuzzy technique benchmarked in phase 0 (94.7% candidate-hit).

Two entry points:
  - ``resolve_mention``  — resolve an LLM-produced mention string.
  - ``resolve_from_text`` — phase-0-style keyword extraction straight from the
    raw description (used as the degradation path when Ollama is unavailable).
"""

import difflib
import re
import unicodedata

from sqlmodel import Session, select

from ..models.asset import Asset
from ..models.location import Building, Room

FUZZY_THRESHOLD = 0.85

# Alias -> canonical generic keyword. Built because users (and the LLM) use
# synonyms that never appear in the asset table.
ASSET_ALIASES = {
    "werkstation": "rekenaar",
    "werkstasie": "rekenaar",
    "pc": "rekenaar",
    "noodlig": "nooduitgang",
    "noodligte": "nooduitgang",
    "emergency light": "nooduitgang",
}

# Tokens that add no signal when deriving a generic keyword from an asset name
# (brands, models, sizes). Everything else in the name is a keyword.
NOISE_TOKENS = {
    "hp", "dell", "epson", "samsung", "lg", "daikin", "dyson", "canon",
    "mikrotik", "ubiquiti", "fanco", "ace", "eaton", "defy", "nespresso",
    "russell", "hobbs", "akademie", "cecil", "nurse", "dauphin", "barker",
    "street", "elitedesk", "elite", "desk", "optiplex", "laserjet", "4k",
    "pro", "ap", "mini", "max", "x", "s",
}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.lower()
    text = re.sub(r"[^a-z0-9 ]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def fuzzy_token_match(token: str, choices: list[str], threshold: float = FUZZY_THRESHOLD):
    best, best_ratio = None, 0.0
    for choice in choices:
        ratio = difflib.SequenceMatcher(None, token, choice).ratio()
        if ratio > best_ratio:
            best, best_ratio = choice, ratio
    return best if best_ratio >= threshold else None


# --- index building (per call; the tables are small) ------------------------

def _asset_keywords(asset: Asset) -> list[str]:
    """Generic keywords derived from an asset name, e.g. 'Projektor 4k' ->
    ['projektor'], 'Wifi-roeterg AP' -> ['wifi', 'roeterg']."""
    tokens = normalize(asset.asset_name).split()
    kws = [t for t in tokens if t not in NOISE_TOKENS and len(t) >= 3]
    if not kws:
        kws = tokens
    return kws


def build_indexes(session: Session) -> tuple[dict[str, list[int]], dict[str, list[int]], dict[str, list[int]]]:
    """Return (asset_kw_map, room_kw_map, building_room_map).

    asset_kw_map:     generic keyword -> asset ids
    room_kw_map:      room token or full name -> room ids
    building_room_map: building token -> room ids in that building
    """
    asset_kw_map: dict[str, list[int]] = {}
    for asset in session.exec(select(Asset)).all():
        for kw in _asset_keywords(asset):
            asset_kw_map.setdefault(kw, [])
            if asset.asset_id not in asset_kw_map[kw]:
                asset_kw_map[kw].append(asset.asset_id)

    rooms = session.exec(select(Room)).all()
    room_kw_map: dict[str, list[int]] = {}
    for room in rooms:
        norm = normalize(room.room_name)
        for kw in dict.fromkeys([norm] + [t for t in norm.split() if len(t) >= 3]):
            room_kw_map.setdefault(kw, [])
            if room.room_id not in room_kw_map[kw]:
                room_kw_map[kw].append(room.room_id)

    buildings = session.exec(select(Building)).all()
    building_room_map: dict[str, list[int]] = {}
    for building in buildings:
        bnorm = normalize(building.building_name)
        room_ids = [r.room_id for r in rooms if r.building_id == building.building_id]
        if not room_ids:
            continue
        for kw in dict.fromkeys([bnorm] + [t for t in bnorm.split() if len(t) >= 3]):
            building_room_map.setdefault(kw, [])
            for rid in room_ids:
                if rid not in building_room_map[kw]:
                    building_room_map[kw].append(rid)

    return asset_kw_map, room_kw_map, building_room_map


# --- resolution -------------------------------------------------------------

def _resolve_with_map(mention: str, kw_map: dict[str, list[int]], aliases: dict[str, str] | None = None) -> list[int]:
    if not mention:
        return []
    norm = normalize(mention)
    found: list[int] = []
    matched = set()
    for kw, ids in kw_map.items():
        if kw in norm:
            matched.add(kw)
            found.extend(ids)
    # fuzzy token match for remaining tokens
    for token in norm.split():
        if len(token) < 3:
            continue
        kw = fuzzy_token_match(token, list(kw_map.keys()))
        if kw and kw not in matched:
            matched.add(kw)
            found.extend(kw_map[kw])
    if aliases:
        for token in norm.split():
            canonical = aliases.get(token)
            if canonical and canonical in kw_map:
                found.extend(kw_map[canonical])
    return list(dict.fromkeys(found))


def resolve_asset_mention(session: Session, mention: str) -> list[int]:
    asset_kw_map, _, _ = build_indexes(session)
    return _resolve_with_map(mention, asset_kw_map, aliases=ASSET_ALIASES)


def resolve_room_mention(session: Session, mention: str) -> list[int]:
    _, room_kw_map, building_room_map = build_indexes(session)
    ids = _resolve_with_map(mention, room_kw_map)
    # building mention -> all rooms in that building
    for bkw, room_ids in building_room_map.items():
        if bkw in normalize(mention):
            ids.extend(room_ids)
    return list(dict.fromkeys(ids))


def resolve_from_text(session: Session, text: str) -> tuple[list[int], list[int]]:
    """Phase-0-style keyword extraction straight from the raw description.
    Used as the degradation path when the LLM is unavailable."""
    return resolve_asset_mention(session, text), resolve_room_mention(session, text)

"""DB-similarity suggestion engine — veldvoorstelle vir skep/wysig-vorms.

Filosofie (selfde as AI_PLAN.md se hibriede benadering): die **databasis**
voorspel feite — bv. die tipe van 'n nuwe bate uit soortgelyke bestaande bates
se name (meerderheid-stem). Die reëls-klassifiseerder bly eienaar van
tipe/prioriteit. Geen veld word ooit geraden as minder as MIN_FILLED velde
reeds ingevul is nie, en 'n leë antwoord ({}) is altyd geldig.

Contract: ``suggest(context, session, fields)`` ontvang die vorm se HUIDIGE
waardes en voorsel slegs vir LEË velde. Elke voorstel is
``{"value": <vertoon-teks>, "id": <opsionele db-id>}``.
"""

from __future__ import annotations

import re
from typing import Any, Optional

from sqlmodel import Session, select

from ..models.asset import Asset, Assettype
from ..models.stock import Stock
from ..models.location import Building, BuildingTypeLink, Location, Room
from . import rules_classifier

MIN_FILLED = 1

_FILLABLE = {
    "asset": {"asset_type", "room", "asset_brand", "asset_status"},
    "stock": {"stock_type", "stock_brand"},
    "fault": {"fault_type", "fault_priority"},
    "job": {"job_type", "job_priority", "nature"},
    "draft": {"title", "suggested_type", "suggested_priority"},
    "building": {"building_types"},
    "room": {"room_type", "room_capacity", "room_status"},
    "location": {"location_type", "location_suburb", "location_city", "location_province", "location_country"},
}


def _tokens(text: str) -> set[str]:
    """Normaliseer na kleinletter-woord-tokens; syfers en <3-karakter woorde val weg."""
    text = re.sub(r"[^a-z0-9 ]+", " ", (text or "").lower())
    return {t for t in text.split() if len(t) >= 3 and not t.isdigit()}


def _filled(fields: dict[str, Any]) -> int:
    """Aan nie-leë velde in die vorm-state."""
    n = 0
    for v in fields.values():
        if v is None:
            continue
        if isinstance(v, str) and not v.strip():
            continue
        n += 1
    return n


def _empty(fields: dict[str, Any], key: str) -> bool:
    """Is die vorm-veld nog leeg (mag ons dit dus voorstel)?"""
    v = fields.get(key)
    if v is None:
        return True
    if isinstance(v, str) and not v.strip():
        return True
    # 0 / False tel as gevul (keuse gemaak); None/"" as leeg.
    return False


def _majority_vote(items: list, attr: str) -> Optional[Any]:
    votes: dict[Any, int] = {}
    for it in items:
        val = getattr(it, attr, None)
        if val is not None:
            votes[val] = votes.get(val, 0) + 1
    return max(votes, key=votes.get) if votes else None


def _similar_by_name(rows: list, query_tokens: set[str], attr: str, top_n: int = 10) -> list:
    """Rangskik rye op token-oorvleueling met die navraag-naam; gee top N.
    Saamgestelde woorde ('kantoorstoel' vs 'Kantoor Stoel') kry ook punte via
    'n sub-string-tjek oor die spasie-loze naam."""
    def _nospace(text: str) -> str:
        return re.sub(r"\s+", "", (text or "").lower())

    scored = []
    for row in rows:
        name = getattr(row, attr, "") or ""
        overlap = len(query_tokens & _tokens(name))
        if not overlap and query_tokens:
            joined = _nospace(name)
            if any(t in joined for t in query_tokens):
                overlap = 1
        if overlap:
            scored.append((overlap, row))
    scored.sort(key=lambda t: (-t[0], getattr(t[1], attr, "")))
    return [row for _, row in scored[:top_n]]


def _suggest_location_fields(session: Session, fields: dict[str, Any], model, name_key: str, fillable: set[str]) -> dict[str, Any]:
    name = fields.get(name_key) or fields.get("location_name") or fields.get("building_name") or fields.get("room_name")
    tokens = _tokens(name)
    if not tokens:
        return {}
    rows = session.exec(select(model).limit(1000)).all()
    similar = _similar_by_name(rows, tokens, name_key)
    if not similar:
        return {}
    out = {}
    for key in fillable:
        if not _empty(fields, key):
            continue
        value = _majority_vote(similar, key)
        if value is None:
            continue
        out[key] = {"value": getattr(value, "value", value)}
    return out


def suggest_building(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    rows = session.exec(select(Building).limit(1000)).all()
    tokens = _tokens(fields.get("building_name") or "")
    if not tokens:
        return {}
    similar = _similar_by_name(rows, tokens, "building_name")
    types = []
    for row in similar:
        links = session.exec(select(BuildingTypeLink).where(BuildingTypeLink.building_id == row.building_id)).all()
        types.extend(link.building_type for link in links)
    if types and _empty(fields, "building_types"):
        return {"building_types": {"value": [getattr(t, "value", t) for t in types[:3]]}}
    return {}


def suggest_room(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    return _suggest_location_fields(session, fields, Room, "room_name", _FILLABLE["room"])


def suggest_location(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    return _suggest_location_fields(session, fields, Location, "location_name", _FILLABLE["location"])


# ── Konteks-handlers ─────────────────────────────────────────────────────────


def suggest_asset(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Bate-naam → assettype (+ kamer) via meerderheid-stem onder naam-similariteit.
    Voorbeeld: 'Kantoor stoel 12' stem saam met bestaande 'Stoel'-bates."""
    """Bate-naam → assettype (+ kamer + handelsmerk + status) via meerderheid-stem
    onder naam-similariteit. Voorbeeld: 'Kantoor stoel 12' stem saam met bestaande
    'Stoel'-bates."""
    out: dict[str, Any] = {}
    toks = _tokens(fields.get("asset_name") or "")
    if not toks:
        return out
    assets = session.exec(select(Asset).limit(1000)).all()
    similar = _similar_by_name(assets, toks, "asset_name")
    if not similar:
        return out
    if _empty(fields, "asset_type"):
        type_id = _majority_vote(similar, "assettype_id")
        if type_id is not None:
            atype = session.get(Assettype, type_id)
            if atype:
                out["asset_type"] = {"value": atype.assettype_name, "id": type_id}
    if _empty(fields, "room"):
        room_id = _majority_vote([a for a in similar if a.room_id is not None], "room_id")
        if room_id is not None:
            from ..models.location import Room

            room = session.get(Room, room_id)
            if room:
                out["room"] = {"value": room.room_name, "id": room_id}
    if _empty(fields, "asset_brand"):
        brand = _majority_vote([a for a in similar if getattr(a, "asset_brand", None)], "asset_brand")
        if brand:
            out["asset_brand"] = {"value": brand}
    if _empty(fields, "asset_status"):
        status = _majority_vote([a for a in similar if getattr(a, "asset_status", None) is not None], "asset_status")
        if status is not None:
            val = getattr(status, "value", status)
            # Normaliseer na vertoonwaarde (hanteer sowel naam as waarde)
            try:
                from ..models.enums import AssetStatus

                lookup = {m.value: m.value for m in AssetStatus}
                lookup.update({m.name: m.value for m in AssetStatus})
                display = lookup.get(str(val), str(val))
                if display in lookup.values():
                    out["asset_status"] = {"value": display}
            except Exception:
                out["asset_status"] = {"value": str(val)}
    return out


def suggest_stock(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Voorraad-naam → stock_type via meerderheid-stem onder naam-similariteit."""
    """Voorraad-naam → stock_type (+ handelsmerk) via meerderheid-stem onder naam-similariteit."""
    out: dict[str, Any] = {}
    toks = _tokens(fields.get("stock_name") or "")
    if not toks:
        return out
    rows = session.exec(select(Stock).limit(1000)).all()
    similar = _similar_by_name(rows, toks, "stock_name")
    types = [getattr(s, "stock_type", None) for s in similar]
    types = [t for t in types if t]
    if not types:
        return out
    votes: dict[str, int] = {}
    for t in types:
        votes[t] = votes.get(t, 0) + 1
    best = max(votes, key=votes.get)
    if _empty(fields, "stock_type"):
        out["stock_type"] = {"value": best}
    if not similar:
        return out
    if _empty(fields, "stock_type"):
        types = [getattr(s, "stock_type", None) for s in similar]
        types = [t for t in types if t]
        if types:
            votes: dict[str, int] = {}
            for t in types:
                votes[t] = votes.get(t, 0) + 1
            best = max(votes, key=votes.get)
            out["stock_type"] = {"value": best}
    if _empty(fields, "stock_brand"):
        brand = _majority_vote([r for r in similar if getattr(r, "stock_brand", None)], "stock_brand")
        if brand:
            out["stock_brand"] = {"value": brand}
    return out


def _text_from(fields: dict[str, Any], keys: list[str]) -> str:
    return " ".join(str(fields.get(k)) for k in keys if fields.get(k)).strip()


def suggest_fault(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Foutbeskrywing/titel → tipe + prioriteit (reëls-klassifiseerder)."""
    out: dict[str, Any] = {}
    text = _text_from(fields, ["description", "title", "fault_description"])
    if not text:
        return out
    if _empty(fields, "fault_type"):
        t = rules_classifier.classify_type(text)
        if t:
            out["fault_type"] = {"value": t}
    if _empty(fields, "fault_priority"):
        p = rules_classifier.classify_priority(text)
        if p:
            out["fault_priority"] = {"value": p}
    return out


def suggest_job(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Werkbeskrywing → jobtipe + prioriteit (dieselfde reël-ens as foute)."""
    """Werkbeskrywing → jobtipe + prioriteit (reëls) + aard (meerderheid-stem oor
    soortgelyke bestaande werksopdragte se job_desc)."""
    out: dict[str, Any] = {}
    text = _text_from(fields, ["job_desc", "description", "title"])
    if not text:
        return out
    if _empty(fields, "job_type"):
        t = rules_classifier.classify_type(text)
        if t:
            out["job_type"] = {"value": t}
    if _empty(fields, "job_priority"):
        p = rules_classifier.classify_priority(text)
        if p:
            out["job_priority"] = {"value": p}
    if _empty(fields, "nature"):
        toks = _tokens(text)
        if toks:
            try:
                from ..models.job import Jobcard

                jobs = session.exec(select(Jobcard).limit(1000)).all()
                similar = _similar_by_name(jobs, toks, "job_desc")
                nature = _majority_vote([j for j in similar if getattr(j, "nature", None)], "nature")
                if nature:
                    out["nature"] = {"value": nature}
            except Exception:
                pass
    return out


def suggest_draft(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Gedeeltelike konsep-beskywing → titel/tipe/prioriteit (lig-paaie, geen LLM)."""
    out: dict[str, Any] = {}
    desc = _text_from(fields, ["description"])
    if not desc:
        return out
    if _empty(fields, "title"):
        first_clause = re.split(r"[.!?\n]", desc)[0].strip()
        if len(first_clause) > 80:
            first_clause = first_clause[:77].rstrip() + "..."
        if len(first_clause) >= 3:
            out["title"] = {"value": first_clause}
    if _empty(fields, "suggested_type"):
        t = rules_classifier.classify_type(desc)
        if t:
            out["suggested_type"] = {"value": t}
    if _empty(fields, "suggested_priority"):
        p = rules_classifier.classify_priority(desc)
        if p:
            out["suggested_priority"] = {"value": p}
    return out


_HANDLERS = {
    "asset": suggest_asset,
    "stock": suggest_stock,
    "fault": suggest_fault,
    "job": suggest_job,
    "draft": suggest_draft,
    "building": suggest_building,
    "room": suggest_room,
    "location": suggest_location,
}

CONTEXTS = sorted(_HANDLERS.keys())


def suggest(context: str, session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Hoofingang: gee {} onder MIN_FILLED ingevulde velde of onbekende konteks;
    anders net voorstelle vir LEË velde binne die konteks se vulbare stel."""
    if context not in _HANDLERS:
        return {}
    if _filled(fields) < MIN_FILLED:
        return {}
    suggestions = _HANDLERS[context](session, fields)
    allowed = _FILLABLE[context]
    return {k: v for k, v in suggestions.items() if k in allowed}

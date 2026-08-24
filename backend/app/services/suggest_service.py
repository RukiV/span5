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
from . import rules_classifier

MIN_FILLED = 3

# Velde wat elke konteks mag voorstel (net hierdie sleutels kom in die antwoord).
_FILLABLE = {
    "asset": {"asset_type", "room"},
    "stock": {"stock_type"},
    "fault": {"fault_type", "fault_priority"},
    "job": {"job_type", "job_priority"},
    "draft": {"title", "suggested_type", "suggested_priority"},
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


# ── Konteks-handlers ─────────────────────────────────────────────────────────


def suggest_asset(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Bate-naam → assettype (+ kamer) via meerderheid-stem onder naam-similariteit.
    Voorbeeld: 'Kantoor stoel 12' stem saam met bestaande 'Stoel'-bates."""
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
    return out


def suggest_stock(session: Session, fields: dict[str, Any]) -> dict[str, Any]:
    """Voorraad-naam → stock_type via meerderheid-stem onder naam-similariteit."""
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

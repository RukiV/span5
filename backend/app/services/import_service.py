"""CSV/XLSX data-import engine.

Parses uploaded spreadsheets, auto-maps columns to model fields, resolves
cross-table references by natural key, detects duplicates and (on commit)
writes rows through the existing services so validation, sanitization and
audit logging behave exactly like the normal CRUD endpoints.
"""

import csv
import enum
import io
import secrets
from dataclasses import dataclass
from datetime import date, datetime
from difflib import SequenceMatcher
from typing import Any, Optional

from sqlmodel import Session, func, not_, select

from ..models.asset import Asset, Assettype, AssetCreate, AssettypeCreate, AssetUpdate, AssettypeUpdate
from ..models.enums import (
    AssetStatus,
    BuildingType,
    FaultStatus,
    JobStatus,
    Priority,
    RoomStatus,
    RoomType,
    Type,
)
from ..models.fault import Faultcard, FaultcardCreate, FaultcardUpdate
from ..models.job import Jobcard, JobcardCreate, JobcardUpdate
from ..models.location import (
    Building,
    BuildingCreate,
    BuildingUpdate,
    Location,
    LocationCreate,
    LocationUpdate,
    Room,
    RoomCreate,
    RoomUpdate,
)
from ..models.quote import Quote, QuoteCreate, QuoteUpdate
from ..models.role import Role
from ..models.stock import Stock, StockCreate, StockUpdate
from ..models.user import User, UserCreate, UserUpdate
from ..models.validators import sanitize_text
from ..services.assets_service import assets_service
from ..services.assettype_service import assettype_service
from ..services.building_service import building_service
from ..services.fault_service import fault_service
from ..services.job_service import job_service
from ..services.location_service import location_service
from ..services.quote_service import quote_service
from ..services.room_service import room_service
from ..services.stock_service import stock_service
from ..services.user_service import user_service

MAX_ROWS_PER_SHEET = 5000
MAX_SHEETS = 30

DUP_MODES = ("skip", "update", "create")

_DATE_FORMATS = ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y", "%Y/%m/%d", "%d.%m.%Y")
_DATETIME_FORMATS = _DATE_FORMATS + (
    "%Y-%m-%d %H:%M",
    "%Y-%m-%dT%H:%M",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%dT%H:%M:%S",
    "%d/%m/%Y %H:%M",
)


def norm(value: Any) -> str:
    if value is None:
        return ""
    return sanitize_text(str(value)).strip().lower()


def cell_to_str(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "Ja" if value else "Nee"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return value.strftime("%Y-%m-%d")
    if isinstance(value, float) and value.is_integer():
        return str(int(value))
    return str(value).strip()


def coerce_value(kind: Any, raw: Any):
    text = str(raw).strip() if raw is not None and str(raw).strip() != "" else ""
    if text == "":
        return None
    if kind == "int":
        try:
            num = float(text.replace(",", "."))
        except ValueError:
            raise ValueError(f"Ongeldige getal: '{text}'")
        if not num.is_integer():
            raise ValueError(f"Moet 'n heelgetal wees: '{text}'")
        return int(num)
    if kind == "bool":
        low = text.lower()
        if low in ("ja", "yes", "y", "true", "1", "waar"):
            return True
        if low in ("nee", "no", "n", "false", "0", "vals"):
            return False
        raise ValueError(f"Ongeldige ja/nee waarde: '{text}'")
    if kind == "date":
        for fmt in _DATE_FORMATS:
            try:
                return datetime.strptime(text, fmt).date()
            except ValueError:
                pass
        raise ValueError(f"Ongeldige datum: '{text}'")
    if kind == "datetime":
        for fmt in _DATETIME_FORMATS:
            try:
                return datetime.strptime(text, fmt)
            except ValueError:
                pass
        raise ValueError(f"Ongeldige datum/tyd: '{text}'")
    if isinstance(kind, type) and issubclass(kind, enum.Enum):
        for member in kind:
            if text.lower() in (member.value.lower(), member.name.lower(), member.name.replace("_", " ").lower()):
                return member
        allowed = ", ".join(m.value for m in kind)
        raise ValueError(f"'{text}' is nie geldig nie. Kies een van: {allowed}")
    return sanitize_text(text)


@dataclass
class FieldSpec:
    target: str
    label: str
    kind: Any = "text"
    required: bool = False
    aliases: tuple = ()


@dataclass
class RefSpec:
    target: str
    source: str
    entity: str
    label: str
    required: bool = False
    aliases: tuple = ()


@dataclass
class TableSpec:
    key: str
    label: str
    order: int
    right: str
    model: type
    create_schema: type
    update_schema: type
    service: Any
    pk_field: str
    fields: tuple = ()
    refs: tuple = ()
    sheet_aliases: tuple = ()

    def all_targets(self) -> dict[str, dict]:
        out = {}
        for f in self.fields:
            out[f"f:{f.target}"] = {"label": f.label, "kind": "field"}
        for r in self.refs:
            out[f"r:{r.source}"] = {"label": r.label, "kind": "ref"}
        return out


TABLES: dict[str, TableSpec] = {
    "location": TableSpec(
        key="location", label="Terreine", order=1, right="locations.manage",
        model=Location, create_schema=LocationCreate, update_schema=LocationUpdate,
        service=location_service, pk_field="location_id",
        sheet_aliases=("kampus", "kampe", "terrein", "terreine", "location", "campus"),
        fields=(
            FieldSpec("location_name", "Naam", required=True,
                      aliases=("naam", "name", "kampus naam", "terrein", "kampus", "campus")),
            FieldSpec("location_type", "Tipe", required=True,
                      aliases=("tipe", "type", "soort", "kampus tipe")),
            FieldSpec("location_streetnum", "Straatnommer",
                      aliases=("straatnommer", "straat nr", "street number", "huisnommer", "nommer")),
            FieldSpec("location_streetname", "Straatnaam",
                      aliases=("straatnaam", "street name", "straat")),
            FieldSpec("location_suburb", "Suburb", aliases=("voorstad", "suburb", "buurt")),
            FieldSpec("location_city", "Stad", aliases=("stad", "city", "town")),
            FieldSpec("location_province", "Provinsie", aliases=("provinsie", "province")),
            FieldSpec("location_country", "Land", aliases=("land", "country")),
        ),
    ),
    "building": TableSpec(
        key="building", label="Geboue", order=2, right="buildings.manage",
        model=Building, create_schema=BuildingCreate, update_schema=BuildingUpdate,
        service=building_service, pk_field="building_id",
        sheet_aliases=("gebou", "geboue", "building", "buildings"),
        fields=(
            FieldSpec("building_name", "Naam", required=True,
                      aliases=("naam", "gebou naam", "gebou", "name", "building name")),
            FieldSpec("building_type", "Tipe", kind=BuildingType,
                      aliases=("tipe", "type", "gebou tipe", "soort")),
        ),
        refs=(RefSpec("location_id", "location_ref", "location", "Terrein", required=True,
                      aliases=("kampus", "terrein", "location", "campus", "kampus naam")),),
    ),
    "room": TableSpec(
        key="room", label="Lokale", order=3, right="rooms.manage",
        model=Room, create_schema=RoomCreate, update_schema=RoomUpdate,
        service=room_service, pk_field="room_id",
        sheet_aliases=("kamer", "kamers", "lokaal", "lokale", "room", "rooms"),
        fields=(
            FieldSpec("room_name", "Naam", required=True,
                      aliases=("naam", "kamer naam", "name", "room name")),
            FieldSpec("room_code", "Kode",
                      aliases=("kode", "room code", "kamer kode", "code", "serienommer",
                               "serial", "kode (serienommer)")),
            FieldSpec("room_type", "Tipe", kind=RoomType,
                      aliases=("tipe", "type", "kamer tipe")),
            FieldSpec("room_status", "Status", kind=RoomStatus,
                      aliases=("status", "toestand")),
            FieldSpec("room_capacity", "Kapasiteit", kind="int",
                      aliases=("kapasiteit", "capacity", "plekke")),
        ),
        refs=(RefSpec("building_id", "building_ref", "building", "Gebou", required=True,
                      aliases=("gebou", "building", "gebou naam")),),
    ),
    "assettype": TableSpec(
        key="assettype", label="Aktiwiteitstipes", order=4, right="assets.manage",
        model=Assettype, create_schema=AssettypeCreate, update_schema=AssettypeUpdate,
        service=assettype_service, pk_field="assettype_id",
        sheet_aliases=("aktiwiteitstipe", "assettipe", "assettypes", "asset type", "tipes"),
        fields=(
            FieldSpec("assettype_name", "Naam", required=True,
                      aliases=("naam", "tipe", "asset type", "assettipe", "name")),
            FieldSpec("assettype_avg_lifespan", "Gemiddelde lewensduur (maande)", kind="int",
                      aliases=("gemiddelde lewensduur", "avg lifespan", "lewensduur")),
            FieldSpec("assettype_min_lifespan", "Min lewensduur (maande)", kind="int",
                      aliases=("min lewensduur", "minimum lifespan")),
            FieldSpec("assettype_max_lifespan", "Maks lewensduur (maande)", kind="int",
                      aliases=("maks lewensduur", "maximum lifespan")),
            FieldSpec("assettype_service_interval", "Diensinterval (maande)", kind="int",
                      aliases=("diensinterval", "service interval")),
            FieldSpec("assettype_replacement_threshold", "Vervangingsdrempel", kind="int",
                      aliases=("vervangingsdrempel", "replacement threshold")),
        ),
    ),
    "asset": TableSpec(
        key="asset", label="Bates", order=5, right="assets.manage",
        model=Asset, create_schema=AssetCreate, update_schema=AssetUpdate,
        service=assets_service, pk_field="asset_id",
        sheet_aliases=("aktiwiteit", "aktiwiteite", "asset", "assets", "toerusting", "bate", "bates"),
        fields=(
            FieldSpec("asset_name", "Naam", required=True,
                      aliases=("naam", "asset naam", "name")),
            FieldSpec("asset_brand", "Merk", required=True,
                      aliases=("merk", "handelsmerk", "brand", "make", "vervaardiger")),
            FieldSpec("asset_serial", "Serienommer",
                      aliases=("serienommer", "serial", "serial number", "sn")),
            FieldSpec("asset_status", "Status", kind=AssetStatus,
                      aliases=("status", "toestand")),
            FieldSpec("asset_isoutdoor", "Buite", kind="bool",
                      aliases=("buite", "buitelug", "outdoor")),
            FieldSpec("asset_created_datetime", "Geskep", kind="datetime",
                      aliases=("geskep", "aanskafdatum", "aangeskaf", "created", "datum aangeskaf")),
        ),
        refs=(
            RefSpec("assettype_id", "assettype_ref", "assettype", "Tipe", required=True,
                    aliases=("tipe", "assettipe", "aktiwiteitstipe", "asset type")),
            RefSpec("room_id", "room_ref", "room", "Lokaal",
                    aliases=("lokaal", "kamer", "room", "kamer kode")),
        ),
    ),
    "stock": TableSpec(
        key="stock", label="Voorraad", order=6, right="stock.manage",
        model=Stock, create_schema=StockCreate, update_schema=StockUpdate,
        service=stock_service, pk_field="stock_id",
        sheet_aliases=("voorraad", "stock", "items"),
        fields=(
            FieldSpec("stock_name", "Naam", aliases=("naam", "item", "name")),
            FieldSpec("stock_brand", "Merk", required=True,
                      aliases=("merk", "handelsmerk", "brand")),
            FieldSpec("stock_amount", "Hoeveelheid", kind="int",
                      aliases=("hoeveelheid", "aantal", "amount", "qty", "quantity")),
            FieldSpec("stock_minimum", "Minimum", kind="int",
                      aliases=("minimum", "min", "minimum vlak")),
            FieldSpec("stock_boxTotal", "Boks Totaal", kind="int",
                      aliases=("boks totaal", "bokstotaal", "boks", "box total", "verpakking")),
            FieldSpec("stock_type", "Tipe", required=True,
                      aliases=("tipe", "type", "soort", "kategorie", "category")),
            FieldSpec("stock_desc", "Beskrywing", aliases=("beskrywing", "description", "detail")),
        ),
        refs=(RefSpec("room_id", "room_ref", "room", "Lokaal",
                      aliases=("lokaal", "kamer", "room", "kamer kode")),),
    ),
    "user": TableSpec(
        key="user", label="Gebruikers", order=7, right="users.manage",
        model=User, create_schema=UserCreate, update_schema=UserUpdate,
        service=user_service, pk_field="user_id",
        sheet_aliases=("gebruiker", "gebruikers", "user", "users"),
        fields=(
            FieldSpec("user_name", "Voornaam", required=True,
                      aliases=("voornaam", "naam", "first name", "firstname")),
            FieldSpec("user_surname", "Van", required=True,
                      aliases=("van", "surname", "last name", "achternaam")),
            FieldSpec("user_email", "E-pos", required=True,
                      aliases=("e-pos", "epos", "email", "e-mail", "epos adres")),
            FieldSpec("user_number", "Selnommer",
                      aliases=("selnommer", "foon", "phone", "mobile", "selfoon", "nummer")),
            FieldSpec("user_status", "Status", required=True,
                      aliases=("status", "toestand")),
            FieldSpec("user_role_name", "Rol",
                      aliases=("rol", "role", "funksie", "gebruiker rol", "user role")),
        ),
    ),
    # Kontrakteurs is gewone gebruikers (rol "Kontrakteur") en word deur die
    # "user"-tabel ingevoer — daar is geen aparte kontrakteurstabel meer nie.
    "fault": TableSpec(
        key="fault", label="Foutkaartjies", order=9, right="faults.manage",
        model=Faultcard, create_schema=FaultcardCreate, update_schema=FaultcardUpdate,
        service=fault_service, pk_field="fault_id",
        sheet_aliases=("fout", "foute", "foutkaart", "foutkaartjies", "fault", "faults", "fault ticket"),
        fields=(
            FieldSpec("fault_description", "Titel", required=True,
                      aliases=("titel", "beskrywing", "description", "probleem", "fault")),
            FieldSpec("fault_type", "Kategorie", kind=Type,
                      aliases=("kategorie", "werksoort", "tipe", "type")),
            FieldSpec("fault_status", "Status", kind=FaultStatus,
                      aliases=("status", "toestand")),
            FieldSpec("fault_priority", "Prioriteit", kind=Priority,
                      aliases=("prioriteit", "priority", "dringend")),
            FieldSpec("fault_reportdatetime", "Datum", kind="datetime",
                      aliases=("datum", "aanmelddatum", "report date", "aangemeld datum", "datum aangemeld")),
        ),
        refs=(
            RefSpec("room_id", "room_ref", "room", "Lokaal",
                    aliases=("lokaal", "kamer", "room", "kamer kode")),
            RefSpec("asset_id", "asset_ref", "asset", "Bate",
                    aliases=("bate", "aktiwiteit", "asset", "toerusting", "serienommer")),
            RefSpec("building_id", "building_ref", "building", "Gebou",
                    aliases=("gebou", "building")),
            RefSpec("location_id", "location_ref", "location", "Terrein",
                    aliases=("terrein", "kampus", "location", "campus")),
            RefSpec("user_id", "user_email", "user", "Aangeer (e-pos)",
                    aliases=("aangeer", "gemeld deur", "reported by", "gebruiker", "user", "e-pos")),
        ),
    ),
    "quote": TableSpec(
        key="quote", label="Kotasies", order=10, right="quotes.manage",
        model=Quote, create_schema=QuoteCreate, update_schema=QuoteUpdate,
        service=quote_service, pk_field="quote_id",
        sheet_aliases=("kotasie", "kotasies", "kwotasie", "quote", "quotes"),
        fields=(
            FieldSpec("quote_date", "Datum", kind="date", required=True,
                      aliases=("datum", "date", "kotasie datum")),
            FieldSpec("quote_status", "Status", required=True,
                      aliases=("status", "toestand")),
            FieldSpec("quote_selection_reason", "Keuse rede",
                      aliases=("keuse rede", "selection reason", "rede")),
        ),
        refs=(RefSpec("contractor_id", "contractor_email", "user", "Kontrakteur (e-pos)",
                      aliases=("kontrakteur", "contractor", "kontrakteur e-pos", "e-pos")),),
    ),
    "job": TableSpec(
        key="job", label="Werksopdragte", order=11, right="jobs.manage",
        model=Jobcard, create_schema=JobcardCreate, update_schema=JobcardUpdate,
        service=job_service, pk_field="jobcard_id",
        sheet_aliases=("werk", "werkskaart", "werksopdrag", "werksopdragte", "job", "jobs", "work order", "jobcard"),
        fields=(
            FieldSpec("job_desc", "Beskrywing", required=True,
                      aliases=("beskrywing", "description", "werk beskrywing", "job")),
            FieldSpec("job_status", "Status", kind=JobStatus,
                      aliases=("status", "toestand")),
            FieldSpec("job_type", "Werksoort", aliases=("werksoort", "tipe", "type")),
            FieldSpec("job_priority", "Prioriteit", aliases=("prioriteit", "priority")),
            FieldSpec("nature", "Aard", aliases=("aard", "nature")),
            FieldSpec("job_notes", "Notas", aliases=("notas", "notes", "opmerking")),
            FieldSpec("job_createddatetime", "Geskep", kind="datetime",
                      aliases=("geskep", "skepdatum", "created", "datum geskep")),
            FieldSpec("job_scheduled_datetime", "Geskeduleerde datum", kind="datetime",
                      aliases=("geskeduleer", "scheduled", "datum geskeduleer")),
            FieldSpec("job_scheduled_end_datetime", "Einddatum", kind="datetime",
                      aliases=("einddatum", "end date", "tot")),
            FieldSpec("job_finisheddatetime", "Voltooidatum", kind="datetime",
                      aliases=("voltooidatum", "finished", "afgehandel", "klaar")),
            FieldSpec("quote_ids", "Kwotasies", kind="quote_list",
                      aliases=("kwotasies", "kwotasie", "quotes")),
        ),
        refs=(
            RefSpec("room_id", "room_ref", "room", "Lokaal",
                    aliases=("lokaal", "kamer", "room", "kamer kode")),
            RefSpec("asset_id", "asset_ref", "asset", "Bate",
                    aliases=("bate", "aktiwiteit", "asset", "toerusting")),
            RefSpec("building_id", "building_ref", "building", "Gebou",
                    aliases=("gebou", "building")),
            RefSpec("location_id", "location_ref", "location", "Terrein",
                    aliases=("terrein", "kampus", "location", "campus")),
            RefSpec("assigned_to", "assigned_email", "user", "Toegewys",
                    aliases=("toegewys", "toegeken aan", "assigned to", "tegnikus", "werker")),
            RefSpec("contractor_id", "contractor_email", "user", "Kontrakteur (e-pos)",
                    aliases=("kontrakteur", "contractor", "kontrakteur e-pos")),
            RefSpec("fault_id", "fault_ref", "fault", "Foutkaartjie",
                    aliases=("foutkaartjie", "fout", "foutkaart", "fault", "fault card")),
        ),
    ),
}


def get_table(key: str) -> Optional[TableSpec]:
    return TABLES.get(key)


# Kanonieke bladname vir uitvoer — elkeen word deur detect_entity herken.
EXPORT_SHEET_NAMES: dict[str, str] = {
    "location": "Terreine",
    "building": "Geboue",
    "room": "Lokale",
    "assettype": "Aktiwiteitstipes",
    "asset": "Bates",
    "stock": "Voorraad",
    "user": "Gebruikers",
    "fault": "Foutkaartjies",
    "quote": "Kotasies",
    "job": "Werksopdragte",
}


def _render_export_value(kind: Any, value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "Ja" if value else "Nee"
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(value, date):
        return value.strftime("%Y-%m-%d")
    if isinstance(kind, type) and issubclass(kind, enum.Enum):
        return str(getattr(value, "value", value))
    return cell_to_str(value)


def _load_ref_display(session: Session) -> dict[str, dict[int, str]]:
    def by_pk(pairs):
        return {pk: (disp or "") for pk, disp in pairs}

    return {
        "location": by_pk((r.location_id, r.location_name) for r in session.exec(select(Location)).all()),
        "building": by_pk((r.building_id, r.building_name) for r in session.exec(select(Building)).all()),
        "room": by_pk(
            (r.room_id, r.room_code or r.room_name)
            for r in session.exec(select(Room)).all()
        ),
        "assettype": by_pk((r.assettype_id, r.assettype_name) for r in session.exec(select(Assettype)).all()),
        "asset": by_pk(
            (r.asset_id, r.asset_serial or r.asset_name)
            for r in session.exec(select(Asset)).all()
        ),
        "user": by_pk((r.user_id, r.user_email) for r in session.exec(select(User)).all()),
    }


def _render_quote_ids(rec, quote_display: dict, user_map: dict[int, str]) -> str:
    """Render 'n werkskaart se kwotasies as "datum;kontrakteur-e-pos|...".

    Die eerste ID in ``quote_ids`` is die primêre keuse (``quote_id``) en word
    dus eerste gelys sodat herinvoer dieselfde volgorde behou.
    """
    raw = getattr(rec, "quote_ids", None)
    if not raw:
        return ""
    parts: list[str] = []
    for token in str(raw).split(","):
        token = token.strip()
        if not token:
            continue
        try:
            qid = int(token)
        except ValueError:
            continue
        info = quote_display.get(qid)
        if info is None:
            continue
        d, cid = info
        email = user_map.get(cid, "") if cid is not None else ""
        d_txt = d.isoformat() if hasattr(d, "isoformat") else (d or "")
        parts.append(f"{d_txt};{email}")
    return "|".join(parts)


def build_export(session: Session, requested: list[dict], template: bool = False) -> list[dict]:
    """Bou uitvoertabelle in presies die formaat wat die invoer verwag.

    ``requested`` is 'n lys van ``{"entity": key, "columns": [targets] | None}``.
    Kolomme is die kanonieke etikette; verwysings word as natuurlike sleutels
    (naam / kode / e-pos) uitgeskryf sodat herinvoer sonder bewerking werk.
    """
    out: list[dict] = []
    ref_maps: Optional[dict[str, dict[int, str]]] = None
    quote_display: Optional[dict[int, tuple[Any, Optional[int]]]] = None
    for req in sorted(requested, key=lambda r: TABLES[r["entity"]].order):
        spec = TABLES[req["entity"]]
        selected = req.get("columns")
        field_specs = [f for f in spec.fields if selected is None or f"f:{f.target}" in selected]
        ref_specs = [r for r in spec.refs if selected is None or f"r:{r.source}" in selected]
        columns = [f.label for f in field_specs] + [r.label for r in ref_specs]
        rows_out: list[list[str]] = []
        if not template:
            if ref_maps is None:
                ref_maps = _load_ref_display(session)
            for rec in session.exec(select(spec.model)).all():
                vals = []
                for f in field_specs:
                    if f.kind == "quote_list":
                        if quote_display is None:
                            quote_display = {
                                q.quote_id: (q.quote_date, getattr(q, "contractor_id", None))
                                for q in session.exec(select(Quote)).all()
                            }
                        vals.append(_render_quote_ids(rec, quote_display, ref_maps.get("user", {})))
                    else:
                        vals.append(_render_export_value(f.kind, getattr(rec, f.target, None)))
                for rs in ref_specs:
                    rid = getattr(rec, rs.target, None)
                    vals.append(ref_maps.get(rs.entity, {}).get(rid, "") if rid is not None else "")
                rows_out.append(vals)
        out.append({
            "entity": spec.key,
            "label": spec.label,
            "sheet_name": EXPORT_SHEET_NAMES[spec.key],
            "columns": columns,
            "rows": rows_out,
        })
    return out


def detect_entity(sheet_name: str, hint: Optional[str] = None) -> Optional[str]:
    n = norm(sheet_name)
    for spec in TABLES.values():
        if spec.key in n:
            return spec.key
        for alias in spec.sheet_aliases:
            if alias in n:
                return spec.key
    if hint and hint in TABLES:
        return hint
    return None


def _score_header(header_norm: str, candidates: list[tuple[str, str]]) -> tuple[Optional[str], int]:
    best_target, best_score = None, 0
    for cand, target in candidates:
        c = norm(cand)
        if not c:
            continue
        if header_norm == c:
            score = 100
        elif header_norm.startswith(c) or c.startswith(header_norm):
            score = 80 if min(len(header_norm), len(c)) >= 4 else 60
        elif len(header_norm) >= 4 and (c in header_norm or header_norm in c):
            score = 70
        else:
            ratio = SequenceMatcher(None, header_norm, c).ratio()
            score = int(ratio * 100) if ratio >= 0.82 else 0
        if score > best_score:
            best_target, best_score = target, score
    return best_target, best_score


def auto_map(columns: list[str], spec: TableSpec) -> tuple[dict[str, str], list[str]]:
    candidates: list[tuple[str, str]] = []
    for target, info in spec.all_targets().items():
        candidates.append((info["label"], target))
        base = target.split(":", 1)[1]
        candidates.append((base.replace("_", " "), target))
    for f in spec.fields:
        for alias in f.aliases:
            candidates.append((alias, f"f:{f.target}"))
    for r in spec.refs:
        for alias in r.aliases:
            candidates.append((alias, f"r:{r.source}"))

    mapping: dict[str, str] = {}
    taken: set[str] = set()
    unmapped: list[str] = []
    for header in columns:
        hn = norm(header)
        if not hn:
            unmapped.append(header)
            continue
        scored: list[tuple[int, str]] = []
        for target in dict.fromkeys(t for _, t in candidates):
            if target in taken:
                continue
            _, sc = _score_header(hn, [(c, tgt) for c, tgt in candidates if tgt == target])
            if sc > 0:
                scored.append((sc, target))
        scored.sort(reverse=True)
        if scored and scored[0][0] >= 70:
            chosen = scored[0][1]
            mapping[header] = chosen
            taken.add(chosen)
        else:
            unmapped.append(header)
    return mapping, unmapped


def parse_upload(filename: str, data: bytes) -> list[dict]:
    low = (filename or "").lower()
    if low.endswith(".xlsx") or low.endswith(".xlsm"):
        return _parse_xlsx(data)
    if low.endswith(".csv") or low.endswith(".txt"):
        return [_parse_csv(filename, data)]
    raise ValueError("Sondersteunde lêertipe. Gebruik .csv of .xlsx")


def _parse_csv(filename: str, data: bytes) -> dict:
    text = None
    for enc in ("utf-8-sig", "cp1252", "latin-1"):
        try:
            text = data.decode(enc)
            break
        except (UnicodeDecodeError, LookupError):
            continue
    if text is None:
        raise ValueError("Kon lêer nie dekodeer nie")
    sample = text[:4096]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",;\t|")
        delim = dialect.delimiter
    except csv.Error:
        delim = ";" if sample.count(";") > sample.count(",") else ","
    reader = csv.reader(io.StringIO(text), delimiter=delim)
    rows_raw = [r for r in reader]
    return _rows_from_matrix(rows_raw, (filename or "CSV").rsplit(".", 1)[0])


def _parse_xlsx(data: bytes) -> list[dict]:
    from openpyxl import load_workbook

    wb = load_workbook(io.BytesIO(data), read_only=True, data_only=True)
    sheets = []
    for idx, ws in enumerate(wb.worksheets):
        if idx >= MAX_SHEETS:
            break
        matrix = []
        for row in ws.iter_rows(values_only=True):
            matrix.append([cell_to_str(c) for c in row])
            if len(matrix) > MAX_ROWS_PER_SHEET + 1:
                break
        sheets.append(_rows_from_matrix(matrix, ws.title))
    wb.close()
    return sheets


def _rows_from_matrix(matrix: list[list], name: str) -> dict:
    header_idx = next((i for i, r in enumerate(matrix) if any(str(c).strip() for c in r)), None)
    if header_idx is None:
        return {"name": name, "columns": [], "rows": [], "total_rows": 0}
    headers = []
    for c in matrix[header_idx]:
        h = str(c).strip()
        if not h:
            h = "_leeg"
        base, i = h, 2
        while h in headers:
            h = f"{base}_{i}"
            i += 1
        headers.append(h)
    rows = []
    for line_no, raw in enumerate(matrix[header_idx + 1:], start=header_idx + 2):
        if not any(str(c).strip() for c in raw):
            continue
        if len(rows) >= MAX_ROWS_PER_SHEET:
            break
        values = {}
        for j, h in enumerate(headers):
            values[h] = cell_to_str(raw[j]) if j < len(raw) else ""
        rows.append({"row_number": line_no, "values": values})
    return {"name": name, "columns": headers, "rows": rows, "total_rows": len(rows)}


def natural_key(key: str, p: dict) -> Optional[tuple]:
    def g(name):
        v = p.get(name)
        return norm(v) if isinstance(v, str) else v

    if key == "location":
        n = g("location_name")
        return ("location", n) if n else None
    if key == "building":
        n = g("building_name")
        return ("building", n, p.get("location_id")) if n else None
    if key == "room":
        code = g("room_code")
        if code:
            return ("room-code", code)
        n = g("room_name")
        return ("room-name", n, p.get("building_id")) if n else None
    if key == "assettype":
        n = g("assettype_name")
        return ("assettype", n) if n else None
    if key == "asset":
        s = g("asset_serial")
        if s:
            return ("asset-serial", s)
        b, n = g("asset_brand"), g("asset_name")
        return ("asset-bn", b, n) if n else None
    if key == "stock":
        b = g("stock_brand")
        return ("stock", g("stock_name"), b, p.get("room_id")) if b else None
    if key == "user":
        e = g("user_email")
        return ("user", e) if e else None
    if key in ("fault", "job"):
        desc = g("fault_description" if key == "fault" else "job_desc")
        if not desc:
            return None
        spec_at = p.get("room_id") or p.get("asset_id") or p.get("building_id") or p.get("location_id") or 0
        return (key, desc, spec_at)
    if key == "quote":
        d = p.get("quote_date")
        return ("quote", d.isoformat() if d else "", p.get("contractor_id"))
    return None


def _register_created(ctx: dict, key: str, nk: Optional[tuple], payload: dict, new_id: int) -> None:
    store = ctx["created"].setdefault(key, {})
    if nk:
        store[nk] = new_id
    aliases = ctx["aliases"].setdefault(key, {})
    p = payload

    def put(k, v):
        if v:
            aliases[k] = new_id

    if key == "location":
        put(("by-name", norm(p.get("location_name"))), True)
    elif key == "building":
        put(("by-name-loc", norm(p.get("building_name")), p.get("location_id")), True)
        put(("by-name", norm(p.get("building_name"))), True)
    elif key == "room":
        code = norm(p.get("room_code"))
        if code:
            put(("by-code", code), True)
        put(("by-name", norm(p.get("room_name"))), True)
        put(("by-name-loc", norm(p.get("room_name")), p.get("building_id")), True)
    elif key == "assettype":
        put(("by-name", norm(p.get("assettype_name"))), True)
    elif key == "asset":
        ser = norm(p.get("asset_serial"))
        if ser:
            put(("by-serial", ser), True)
        put(("by-name", norm(p.get("asset_name"))), True)
    elif key == "user":
        put(("by-email", norm(p.get("user_email"))), True)
    elif key == "fault":
        put(("by-desc", norm(p.get("fault_description"))), True)
    elif key == "quote":
        d = p.get("quote_date")
        put(("by-date-c", d.isoformat() if d else "", p.get("contractor_id")), True)


def _lookup_alias(ctx: dict, entity: str, value: str, parent_id: Optional[int] = None) -> Optional[int]:
    n = norm(value)
    if not n:
        return None
    aliases = ctx["aliases"].get(entity, {})
    if entity == "room":
        hit = aliases.get(("by-code", n))
        if hit:
            return hit
    if entity in ("room", "building"):
        hit = aliases.get(("by-name-loc", n, parent_id)) or aliases.get(("by-name-loc", n, None))
        if hit:
            return hit
        hit = aliases.get(("by-name", n))
        if hit:
            return hit
    generic = {
        "location": ("by-name", n),
        "assettype": ("by-name", n),
        "asset": ("by-name", n),
        "user": ("by-email", n),
        "fault": ("by-desc", n),
    }
    if entity in generic:
        hit = aliases.get(generic[entity])
        if hit:
            return hit
        if entity == "asset":
            hit = aliases.get(("by-serial", n))
            if hit:
                return hit
    return None


class _ImportError(Exception):
    pass


def _find_db_by_ref(session: Session, entity: str, value: str, parent_id: Optional[int]):
    n = norm(value)
    if entity == "location":
        return session.exec(
            select(Location).where(func.lower(Location.location_name) == n)
            .order_by(Location.location_id)
        ).first()
    if entity == "building":
        q = select(Building).where(func.lower(Building.building_name) == n)
        if parent_id:
            q = q.where(Building.location_id == parent_id)
        return session.exec(q.order_by(Building.building_id)).first()
    if entity == "room":
        hit = session.exec(
            select(Room).where(func.lower(Room.room_code) == n).order_by(Room.room_id)
        ).first()
        if hit:
            return hit
        q = select(Room).where(func.lower(Room.room_name) == n)
        if parent_id:
            q = q.where(Room.building_id == parent_id)
        return session.exec(q.order_by(Room.room_id)).first()
    if entity == "assettype":
        return session.exec(
            select(Assettype).where(func.lower(Assettype.assettype_name) == n)
            .order_by(Assettype.assettype_id)
        ).first()
    if entity == "asset":
        hit = session.exec(
            select(Asset).where(func.lower(Asset.asset_serial) == n).order_by(Asset.asset_id)
        ).first()
        if hit:
            return hit
        return session.exec(
            select(Asset).where(func.lower(Asset.asset_name) == n).order_by(Asset.asset_id)
        ).first()
    if entity == "user":
        return session.exec(select(User).where(func.lower(User.user_email) == n)).first()
    if entity == "fault":
        return session.exec(
            select(Faultcard)
            .where(func.lower(Faultcard.fault_description) == n)
            .where(Faultcard.fault_status != FaultStatus.CLOSED)
            .order_by(Faultcard.fault_id.desc())
        ).first()
    return None


def _resolve_ref(session: Session, ctx: dict, ref: RefSpec, value: str, parent_hint: Optional[int]):
    if value is None or str(value).strip() == "":
        if ref.required:
            return None, f"'{ref.label}' is verplig"
        return None, None
    hit = _lookup_alias(ctx, ref.entity, str(value), parent_hint)
    if hit:
        return hit, None
    row = _find_db_by_ref(session, ref.entity, str(value), parent_hint)
    if row is not None:
        return getattr(row, TABLES[ref.entity].pk_field), None
    return None, f"Verwysing nie gevind nie: {ref.label} '{value}'"


def _find_db_by_nk(session: Session, spec: TableSpec, p: dict):
    key = spec.key
    if key == "location":
        return session.exec(
            select(Location).where(func.lower(Location.location_name) == norm(p.get("location_name")))
        ).first()
    if key == "building":
        return session.exec(
            select(Building)
            .where(func.lower(Building.building_name) == norm(p.get("building_name")))
            .where(Building.location_id == p.get("location_id"))
        ).first()
    if key == "room":
        code = norm(p.get("room_code"))
        if code:
            return session.exec(select(Room).where(func.lower(Room.room_code) == code)).first()
        return session.exec(
            select(Room)
            .where(func.lower(Room.room_name) == norm(p.get("room_name")))
            .where(Room.building_id == p.get("building_id"))
        ).first()
    if key == "assettype":
        return session.exec(
            select(Assettype).where(func.lower(Assettype.assettype_name) == norm(p.get("assettype_name")))
        ).first()
    if key == "asset":
        ser = norm(p.get("asset_serial"))
        if ser:
            return session.exec(select(Asset).where(func.lower(Asset.asset_serial) == ser)).first()
        return session.exec(
            select(Asset)
            .where(func.lower(Asset.asset_brand) == norm(p.get("asset_brand")))
            .where(func.lower(Asset.asset_name) == norm(p.get("asset_name")))
        ).first()
    if key == "stock":
        room_q = select(Stock).where(func.lower(Stock.stock_brand) == norm(p.get("stock_brand")))
        nm = norm(p.get("stock_name"))
        if nm:
            room_q = room_q.where(func.lower(Stock.stock_name) == nm)
        else:
            room_q = room_q.where(Stock.stock_name.is_(None))
        if p.get("room_id") is not None:
            room_q = room_q.where(Stock.room_id == p.get("room_id"))
        else:
            room_q = room_q.where(Stock.room_id.is_(None))
        return session.exec(room_q).first()
    if key == "user":
        return session.exec(
            select(User).where(func.lower(User.user_email) == norm(p.get("user_email")))
        ).first()
    if key == "fault":
        return session.exec(
            select(Faultcard)
            .where(func.lower(Faultcard.fault_description) == norm(p.get("fault_description")))
            .where(_specificity_clause(Faultcard, p))
            .where(Faultcard.fault_status != FaultStatus.CLOSED)
        ).first()
    if key == "job":
        return session.exec(
            select(Jobcard)
            .where(func.lower(Jobcard.job_desc) == norm(p.get("job_desc")))
            .where(_specificity_clause(Jobcard, p))
            .where(not_(Jobcard.job_status.in_([JobStatus.COMPLETED, JobStatus.CANCELLED])))
        ).first()
    if key == "quote":
        q = select(Quote).where(Quote.quote_date == p.get("quote_date"))
        if p.get("contractor_id") is not None:
            q = q.where(Quote.contractor_id == p.get("contractor_id"))
        else:
            q = q.where(Quote.contractor_id.is_(None))
        return session.exec(q).first()
    return None


def _specificity_clause(model, p: dict):
    clauses = []
    for f in ("room_id", "asset_id", "building_id", "location_id"):
        col = getattr(model, f, None)
        if col is None:
            continue
        val = p.get(f)
        clauses.append(col == val if val is not None else col.is_(None))
    combined = clauses[0]
    for c in clauses[1:]:
        combined = combined & c
    return combined


def _generate_password() -> str:
    return "Imp0rt!" + secrets.token_hex(5)


def _get_student_role_id(session: Session) -> int:
    role = session.exec(select(Role).where(Role.role_name == "User")).first()
    if role:
        return role.role_id
    return 1


_UPDATE_EXCLUDE: dict[str, set] = {"user": {"role_id", "user_password"}}


def _apply_fixed_create_fields(session: Session, key: str, payload: dict) -> None:
    if key == "user":
        # Veilig: net User/Dosent/Kontrakteur via import; ander → default User. Terrein word geïgnoreer (net FK het terrein via seed).
        raw_role = str(payload.pop("user_role_name", "") or "").strip()
        # Remove any Terrein field that might have been mapped (net FK het terrein, nie via import)
        payload.pop("location_id", None)
        payload.pop("user_terrein", None)
        payload.pop("terrein", None)
        allowed = {"user": 1, "dosent": 5, "kontrakteur": 4}
        # Also accept English and Afrikaans variations
        norm_role = raw_role.lower().strip()
        # Map common variations
        role_map = {
            "user": 1, "gebruiker": 1, "student": 1,
            "dosent": 5, "lecturer": 5,
            "kontrakteur": 4, "contractor": 4, " kontrakteur": 4,
        }
        role_id = role_map.get(norm_role, 1)  # default User
        # Validate role exists, else fallback to User
        from ..models.role import Role
        role_exists = session.exec(select(Role).where(Role.role_id == role_id)).first()
        if not role_exists:
            role_id = _get_student_role_id(session)
        payload["role_id"] = role_id
        payload["user_password"] = _generate_password()
    if key == "assettype":
        # Valideer drempel 1-10 (keer 80) en min≤avg≤max
        thr = payload.get("assettype_replacement_threshold")
        if thr is not None and not (1 <= thr <= 10):
            raise ValueError(f"Vervangingsdrempel moet 1-10 wees (gekry {thr}), nie 80 nie")
        avg = payload.get("assettype_avg_lifespan")
        mn = payload.get("assettype_min_lifespan")
        mx = payload.get("assettype_max_lifespan")
        if avg is not None and mn is not None and mn > avg:
            raise ValueError(f"Min lewensduur ({mn}) kan nie groter as gemiddeld ({avg}) wees nie")
        if avg is not None and mx is not None and avg > mx:
            raise ValueError(f"Gemiddelde lewensduur ({avg}) kan nie groter as maks ({mx}) wees nie")


def _resolve_quote_list(session: Session, ctx: dict, raw: Any):
    """Ontleed 'Kwotasies'-teks: "datum;kontrakteur-e-pos|datum;kontrakteur-e-pos".

    Elke inskrywing word opgesoek as 'n kwotasie met daardie natuurlike sleutel
    (datum + kontrakteur) — óf reeds in die databasis, óf vroeër in dieselfde
    invoerloop (alias-register). Keer (ids, foute) terug.
    """
    ids: list[int] = []
    errors: list[str] = []
    quote_aliases = ctx.get("aliases", {}).get("quote", {})
    for part in str(raw or "").split("|"):
        part = part.strip()
        if not part:
            continue
        if ";" not in part:
            errors.append(
                f"Ongeldige kwotasie-verwysing '{part}' "
                "(gebruik datum;kontrakteur-e-pos)"
            )
            continue
        d_txt, email = part.split(";", 1)
        try:
            d = coerce_value("date", d_txt.strip())
        except ValueError:
            errors.append(f"Ongeldige kwotasie-datum '{d_txt.strip()}'")
            continue
        n_email = norm(email)
        cid = None
        if n_email:
            # Eers in-dié-loop geskep, dan die databasis.
            uid = _lookup_alias(ctx, "user", email)
            if uid:
                cid = uid
            else:
                urow = session.exec(
                    select(User).where(func.lower(User.user_email) == n_email)
                ).first()
                cid = getattr(urow, "user_id") if urow is not None else None

        # 1) Pas in dié invoerloop geskep (alias-register).
        hit = quote_aliases.get(("by-date-c", d.isoformat(), cid))
        if hit:
            ids.append(hit)
            continue

        # 2) Reeds in die databasis.
        q = select(Quote).where(Quote.quote_date == d)
        if cid is not None:
            q = q.where(Quote.contractor_id == cid)
        else:
            q = q.where(Quote.contractor_id.is_(None))
        qrow = session.exec(q.order_by(Quote.quote_id)).first()
        if qrow is None:
            errors.append(f"Kwotasie nie gevind nie: {part}")
            continue
        ids.append(getattr(qrow, "quote_id"))
    return ids, errors


def run_import(
    session: Session,
    prepared: list[dict],
    duplicate_mode: str,
    actor_id: Optional[int],
    commit: bool,
) -> dict:
    if duplicate_mode not in DUP_MODES:
        raise ValueError(f"Ongeldige duplicate_mode: {duplicate_mode}")
    ctx: dict = {"created": {}, "aliases": {}, "next_id": -1}
    total_rows = sum(len(t["rows"]) for t in prepared)
    if total_rows > MAX_ROWS_PER_SHEET * MAX_SHEETS:
        raise ValueError("Te veel rye om te voer")

    table_results = []
    grand = {"create": 0, "update": 0, "skip": 0, "error": 0}
    for pt in sorted(prepared, key=lambda t: TABLES[t["entity"]].order):
        spec = TABLES[pt["entity"]]
        rows_out = []
        counts = {"create": 0, "update": 0, "skip": 0, "error": 0}
        for row_in in pt["rows"]:
            row_number = row_in.get("row_number")
            values = row_in.get("values", {}) or {}
            mapping = pt.get("mapping", {}) or {}
            res = {"row_number": row_number, "values": values, "status": None, "reason": None, "existing_id": None}

            if not any(norm(v) for v in values.values()):
                res.update(status="skip", reason="Leë ry")
                counts["skip"] += 1
                rows_out.append(res)
                continue

            payload: dict = {}
            errors: list[str] = []
            parent_hints: dict[str, Optional[int]] = {}
            for header, target in mapping.items():
                if header not in values:
                    continue
                raw = values[header]
                try:
                    if target.startswith("f:"):
                        fspec = next((f for f in spec.fields if f"f:{f.target}" == target), None)
                        if fspec is None:
                            continue
                        if fspec.kind == "quote_list":
                            ids, q_errs = _resolve_quote_list(session, ctx, raw)
                            errors.extend(q_errs)
                            if ids:
                                payload["quote_ids"] = ",".join(str(i) for i in ids)
                            continue
                        val = coerce_value(fspec.kind, raw)
                        if val is None and fspec.required:
                            errors.append(f"'{fspec.label}' is verplig")
                        elif val is not None:
                            payload[fspec.target] = val
                    elif target.startswith("r:"):
                        ref = next((r for r in spec.refs if f"r:{r.source}" == target), None)
                        if ref is None:
                            continue
                        parent_hint = None
                        if ref.entity == "building":
                            loc_hit = _lookup_alias(ctx, "location", "") or None
                            parent_hint = None
                        rid, err = _resolve_ref(session, ctx, ref, raw, parent_hint)
                        if err:
                            errors.append(err)
                        else:
                            payload[ref.target] = rid
                            parent_hints[ref.target] = rid
                except ValueError as ve:
                    errors.append(f"{header}: {ve}")

            if errors:
                res.update(status="error", reason="; ".join(errors))
                counts["error"] += 1
                rows_out.append(res)
                continue

            _apply_fixed_create_fields(session, spec.key, payload)

            try:
                create_obj = spec.create_schema(**payload)
            except Exception as exc:
                msg = str(getattr(exc, "errors", lambda: [])()[0].get("msg", exc) if hasattr(exc, "errors") and exc.errors() else exc)
                res.update(status="error", reason=msg[:300])
                counts["error"] += 1
                rows_out.append(res)
                continue

            nk = natural_key(spec.key, payload)
            existing_row = _find_db_by_nk(session, spec, payload) if nk else None
            created_id = ctx["created"].get(spec.key, {}).get(nk) if nk else None

            if existing_row is None and created_id is None:
                action = "create"
            elif duplicate_mode == "skip":
                res["existing_id"] = created_id or getattr(existing_row, spec.pk_field, None)
                res.update(status="skip", reason="Duplikaat gekry (oorgeslaan)")
                counts["skip"] += 1
                rows_out.append(res)
                continue
            elif duplicate_mode == "update":
                action = "update"
            else:
                if spec.key == "user":
                    res.update(status="error", reason="E-pos bestaan reeds (uniek) — kan nie nuut skep nie")
                    counts["error"] += 1
                    rows_out.append(res)
                    continue
                action = "create"

            if action == "create":
                if commit:
                    obj = spec.service.create(session, create_obj, user_id=actor_id)
                    new_id = getattr(obj, spec.pk_field)
                    if spec.key == "job" and payload.get("quote_ids"):
                        first_qid = str(payload["quote_ids"]).split(",")[0].strip()
                        if first_qid:
                            obj.quote_id = int(first_qid)
                            session.add(obj)
                            session.commit()
                            session.refresh(obj)
                else:
                    new_id = ctx["next_id"]
                    ctx["next_id"] -= 1
                _register_created(ctx, spec.key, nk, payload, new_id)
                res.update(status="create", existing_id=new_id)
                counts["create"] += 1
            else:
                existing_id = created_id or getattr(existing_row, spec.pk_field)
                upd_payload = {k: v for k, v in payload.items() if k not in _UPDATE_EXCLUDE.get(spec.key, set())}
                try:
                    upd_obj = spec.update_schema(**upd_payload)
                except Exception as exc:
                    res.update(status="error", reason=str(exc)[:300])
                    counts["error"] += 1
                    rows_out.append(res)
                    continue
                if commit:
                    spec.service.update(session, existing_id, upd_obj, user_id=actor_id)
                    if spec.key == "job" and upd_payload.get("quote_ids"):
                        row_obj = session.get(spec.model, existing_id)
                        first_qid = str(upd_payload["quote_ids"]).split(",")[0].strip()
                        if row_obj is not None and first_qid:
                            row_obj.quote_id = int(first_qid)
                            session.add(row_obj)
                            session.commit()
                            session.refresh(row_obj)
                if nk:
                    _register_created(ctx, spec.key, nk, payload, existing_id)
                res.update(status="update", existing_id=existing_id)
                counts["update"] += 1
            rows_out.append(res)

        for k in grand:
            grand[k] += counts[k]
        table_results.append({
            "entity": spec.key,
            "label": spec.label,
            "sheet_name": pt.get("sheet_name"),
            "counts": counts,
            "rows": rows_out if not commit else [
                r for r in rows_out if r["status"] == "error"
            ],
        })

    return {"tables": table_results, "totals": grand}


def build_preview(session: Session, sheets: list[dict], hints: Optional[dict] = None) -> dict:
    hints = hints or {}
    prepared = []
    sheet_meta = []
    for sh in sheets:
        hint = hints.get(sh["name"])
        override_mapping = None
        if isinstance(hint, dict):
            entity = hint.get("entity") or detect_entity(sh["name"])
            raw_map = hint.get("mapping")
            if isinstance(raw_map, dict):
                override_mapping = raw_map
        else:
            entity = detect_entity(sh["name"], hint if isinstance(hint, str) else None)
        if entity is not None and entity not in TABLES:
            entity = None
        meta = {
            "sheet_name": sh["name"],
            "columns": sh["columns"],
            "total_rows": sh["total_rows"],
            "entity": entity,
        }
        if entity:
            spec = TABLES[entity]
            valid_targets = set(spec.all_targets())
            if override_mapping is not None:
                mapping = {
                    h: t for h, t in override_mapping.items()
                    if h in sh["columns"] and t in valid_targets
                }
                unmapped = [c for c in sh["columns"] if c not in mapping]
            else:
                mapping, unmapped = auto_map(sh["columns"], spec)
            mapped_targets = set(mapping.values())
            missing_required = [
                f.label for f in spec.fields if f.required and f"f:{f.target}" not in mapped_targets
            ] + [r.label for r in spec.refs if r.required and f"r:{r.source}" not in mapped_targets]
            meta["mapping"] = mapping
            meta["unmapped_columns"] = unmapped
            meta["missing_required"] = missing_required
            prepared.append({
                "entity": entity,
                "sheet_name": sh["name"],
                "mapping": mapping,
                "rows": sh["rows"],
            })
        else:
            meta["mapping"] = {}
            meta["unmapped_columns"] = list(sh["columns"])
            meta["missing_required"] = []
        sheet_meta.append(meta)

    result = run_import(session, prepared, "skip", None, commit=False)
    by_sheet = {t["sheet_name"]: t for t in result["tables"]}
    for m in sheet_meta:
        t = by_sheet.get(m["sheet_name"])
        if t:
            m["counts"] = t["counts"]
            m["rows"] = t["rows"]
    return {
        "sheets": sheet_meta,
        "duplicate_modes": list(DUP_MODES),
        "table_order": [{"entity": k, "label": TABLES[k].label, "order": TABLES[k].order}
                        for k in sorted(TABLES, key=lambda x: TABLES[x].order)],
    }


def get_schema() -> list[dict]:
    out = []
    for key in sorted(TABLES, key=lambda x: TABLES[x].order):
        spec = TABLES[key]
        out.append({
            "key": spec.key,
            "label": spec.label,
            "right": spec.right,
            "targets": [
                {"target": t, **info}
                for t, info in spec.all_targets().items()
            ],
        })
    return out


def run_commit(session: Session, body: dict, actor_id: Optional[int]) -> dict:
    mode = body.get("duplicate_mode", "skip")
    prepared = []
    for t in body.get("tables", []):
        entity = t.get("entity")
        if entity not in TABLES:
            raise ValueError(f"Onbekende tabel: {entity}")
        prepared.append({
            "entity": entity,
            "sheet_name": t.get("sheet_name"),
            "mapping": t.get("mapping", {}),
            "rows": t.get("rows", []),
        })
    return run_import(session, prepared, mode, actor_id, commit=True)

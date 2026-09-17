"""Seed-funksie — inisialiseer die databasis met realistiese, historiese data.

Argitektuur:
  * Alle `_get_or_create_*` helpers is idempotent (soek eers vir 'n bestaande
    ry, skep slegs indien afwesig). Die funksie loop op elke startup in
    `main.py`, so geen duplikate word geskep op herhaalde lopies nie.
  * Rol-skending is NIET-eidbaar: Student=1, FK=2, Admin=3, Kontrakteur=4,
    Dosent=5 (kyk `auth/rights_catalog.py`).
  * Twee kampusse (Leriba en Gerhard), elk met 2 geboue en 2 lokale elk.
  * Alle "geskiedenisdraende" entiteite (gebruikers, bates, voorraad, foute,
    werksopdragte, lokaal-kontroles, kalender) kry tydlyne oor die afgelope
    ±2 jaar (730 dae), relatief tot `datetime.utcnow()`.
"""

import json
from datetime import datetime, timedelta
from typing import Optional
from sqlmodel import Session, select, func

from .database import engine
from ..models.location import (
    Building,
    BuildingType,
    BuildingTypeLink,
    Location,
    Room,
    RoomType,
    RoomStatus,
)
from ..models.asset import Asset, AssetStatus, Assettype
from ..models.stock import Stock
from ..models.job import Jobcard, JobStatus
from ..models.fault import Faultcard, FaultStatus, Priority, Type
from ..models.quote import Quote
from ..models.role import Role, Rights, RoleRight
from ..models.user import User
from ..models.audit import Auditlog
from ..models.notification import NotificationPreference
from ..models.room_check import RoomCheck
from ..models.room_check_session import RoomCheckSession
from ..models.calendar_event import CalendarEvent

from ..auth.security import hash_password, is_hashed

# Die rol-/reggte-katalogus leef in 'n liggewig gedeelde module sodat beide die
# seed en die bestuurs-endpoints een bron van waarheid gebruik.
from ..auth.rights_catalog import (  # noqa: F401  (re-exported vir bestaande importers)
    ROLE_STUDENT,
    ROLE_FK,
    ROLE_ADMIN,
    ROLE_CONTRACTOR,
    ROLE_DOSENT,
    RIGHTS_CATALOG,
    ROLE_RIGHTS,
    LEGACY_RIGHT_MIGRATION,
)

# ---------------------------------------------------------------------------
# Kerntydlyn: data word relatief tot `now` geskep sodat die geskiedenis altyd
# "die afgelope 24 maande" bly, maak nie saak wanneer die databasis geseed word nie.
# ---------------------------------------------------------------------------
NOW = datetime.utcnow()
TWO_YEARS = timedelta(days=730)

# Een jaar terug vir "jaarlikse diens" historiese rye.
ONE_YEAR = timedelta(days=365)


def generate_mock_image_bytes(color_hex: str) -> bytes:
    """Genereer 'n klein, geldige 1x1-pixel PNG byte-string van 'n gegewe kleur
    sodat BYTEA-velde outentieke beelddata-strukture bevat."""
    return b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'


# ---------------------------------------------------------------------------
# Idempotente helpers
# ---------------------------------------------------------------------------
def _get_or_create_test_user(
    session: Session,
    user_name: str,
    user_surname: str,
    user_email: str,
    user_password: str,
    role_id: int,
    location_id: Optional[int] = None,
    user_number: Optional[str] = None,
    last_login: Optional[datetime] = None,
    last_logout: Optional[datetime] = None,
) -> User:
    """Soek bestaande gebruiker of skep nuwe met gegewe rol.

    Wagwoorde word altyd gehash gestoor (nooit platteks nie).
    """
    user = session.exec(select(User).where(User.user_email == user_email)).first()
    if user:
        changed = False
        if user.role_id != role_id:
            user.role_id = role_id
            changed = True
        if location_id is not None and user.location_id != location_id:
            user.location_id = location_id
            changed = True
        if changed:
            session.add(user)
            session.commit()
            session.refresh(user)
        return user

    user = User(
        user_name=user_name,
        user_surname=user_surname,
        user_email=user_email,
        user_password=hash_password(user_password),
        user_number=user_number or "",
        user_lastlogintime=last_login,
        user_lastlogouttime=last_logout,
        user_status="active",
        role_id=role_id,
        location_id=location_id,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def _get_or_create_test_quote(session: Session) -> Quote:
    """Verseker 'n toets-kwotasie vir dokument-oplaai tydens ontwikkeling."""
    quote = session.exec(select(Quote)).first()
    if quote:
        return quote

    quote = Quote(
        quote_date=NOW.date(),
        quote_status="draft",
    )
    session.add(quote)
    session.commit()
    session.refresh(quote)
    return quote


def _get_or_create_location(
    session: Session,
    name: str,
    location_type: str,
    streetnum: str,
    streetname: str,
    suburb: str = "",
    city: str = "",
    province: str = "",
    country: str = "",
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius: Optional[float] = None,
) -> Location:
    location = session.exec(
        select(Location).where(Location.location_name == name)
    ).first()
    if location:
        return location

    location = Location(
        location_name=name,
        location_type=location_type,
        location_streetnum=streetnum,
        location_streetname=streetname,
        location_suburb=suburb,
        location_city=city,
        location_province=province,
        location_country=country,
        location_latitude=latitude,
        location_longitude=longitude,
        location_radius=radius,
    )
    session.add(location)
    session.commit()
    session.refresh(location)
    return location


def _get_or_create_building(
    session: Session,
    name: str,
    building_type: BuildingType,
    location_id: int,
    *,
    building_types: Optional[list[BuildingType]] = None,
) -> Building:
    building = session.exec(
        select(Building).where(
            Building.building_name == name,
            Building.location_id == location_id,
        )
    ).first()

    types = list(building_types) if building_types else [building_type]

    if building is not None:
        existing = {
            row.building_type
            for row in session.exec(
                select(BuildingTypeLink).where(BuildingTypeLink.building_id == building.building_id)
            ).all()
        }
        missing = [t for t in types if t not in existing]
        if missing:
            for t in missing:
                session.add(BuildingTypeLink(building_id=building.building_id, building_type=t))
            session.commit()
        return building

    building = Building(
        building_name=name,
        location_id=location_id,
    )
    session.add(building)
    session.flush()
    for t in types:
        session.add(BuildingTypeLink(building_id=building.building_id, building_type=t))
    session.commit()
    session.refresh(building)
    return building


def _get_or_create_room(
    session: Session,
    name: str,
    code: str,
    capacity: int,
    room_type: RoomType,
    room_status: RoomStatus,
    building_id: int,
) -> Room:
    room = session.exec(select(Room).where(Room.room_code == code)).first()
    if room:
        return room

    room = Room(
        room_name=name,
        room_code=code,
        room_capacity=capacity,
        room_type=room_type,
        room_status=room_status,
        building_id=building_id,
    )
    session.add(room)
    session.commit()
    session.refresh(room)
    return room


def _get_or_create_assettype(
    session: Session,
    name: str,
    avg: int | None = None,
    min_: int | None = None,
    max_: int | None = None,
    interval: int | None = None,
    threshold: int | None = None,
) -> Assettype:
    assettype = session.exec(
        select(Assettype).where(Assettype.assettype_name == name)
    ).first()
    if assettype:
        return assettype

    assettype = Assettype(
        assettype_name=name,
        assettype_avg_lifespan=avg,
        assettype_min_lifespan=min_,
        assettype_max_lifespan=max_,
        assettype_service_interval=interval,
        assettype_replacement_threshold=threshold,
    )
    session.add(assettype)
    session.commit()
    session.refresh(assettype)
    return assettype


def _get_or_create_asset(
    session: Session,
    name: str,
    brand: str,
    serial: str,
    status: AssetStatus,
    is_outdoor: bool,
    room_id: int | None,
    assettype_id: int,
    created_dt: datetime | None = None,
) -> Asset:
    asset = session.exec(select(Asset).where(Asset.asset_serial == serial)).first()
    if asset:
        return asset

    asset = Asset(
        asset_name=name,
        asset_brand=brand,
        asset_serial=serial,
        asset_status=status,
        asset_isoutdoor=is_outdoor,
        room_id=room_id,
        assettype_id=assettype_id,
        asset_created_datetime=created_dt or NOW,
    )
    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset


def _get_or_create_stock(
    session: Session,
    name: str,
    brand: str,
    amount: int,
    minimum: int,
    boxTotal: int,
    stock_type: str,
    desc: str,
    room_id: int | None,
) -> Stock:
    stock = session.exec(
        select(Stock).where(Stock.stock_brand == brand, Stock.stock_type == stock_type)
    ).first()
    if stock:
        return stock

    stock = Stock(
        stock_name=name,
        stock_brand=brand,
        stock_amount=amount,
        stock_minimum=minimum,
        stock_boxTotal=boxTotal,
        stock_type=stock_type,
        stock_desc=desc,
        room_id=room_id,
    )
    session.add(stock)
    session.commit()
    session.refresh(stock)
    return stock


def _get_or_create_job(
    session: Session,
    desc: str,
    status: JobStatus,
    job_type: Optional[str],
    created_dt: Optional[datetime],
    finished_dt: Optional[datetime] = None,
    asset_id: Optional[int] = None,
    room_id: Optional[int] = None,
    building_id: Optional[int] = None,
    location_id: Optional[int] = None,
    fault_id: Optional[int] = None,
    quote_id: Optional[int] = None,
    contractor_id: Optional[int] = None,
) -> Jobcard:
    job = session.exec(
        select(Jobcard).where(
            Jobcard.job_desc == desc, Jobcard.asset_id == asset_id
        )
    ).first()
    if job:
        return job

    job = Jobcard(
        job_desc=desc,
        job_status=status,
        job_type=job_type,
        job_createddatetime=created_dt,
        job_finisheddatetime=finished_dt,
        asset_id=asset_id,
        room_id=room_id,
        building_id=building_id,
        location_id=location_id,
        fault_id=fault_id,
        quote_id=quote_id,
        contractor_id=contractor_id,
    )
    session.add(job)
    session.commit()
    session.refresh(job)
    return job


def _get_or_create_fault(
    session: Session,
    description: str,
    status: FaultStatus,
    priority: Priority,
    fault_type: Optional[Type],
    report_dt: Optional[datetime],
    asset_id: Optional[int] = None,
    room_id: Optional[int] = None,
    building_id: Optional[int] = None,
    location_id: Optional[int] = None,
    mappoint_id: Optional[int] = None,
    is_outdoor: bool = False,
) -> Faultcard:
    fault = session.exec(
        select(Faultcard).where(
            Faultcard.fault_description == description,
            Faultcard.asset_id == asset_id,
        )
    ).first()
    if fault:
        return fault

    fault = Faultcard(
        fault_description=description,
        fault_status=status,
        fault_priority=priority,
        fault_type=fault_type,
        fault_reportdatetime=report_dt,
        asset_id=asset_id,
        room_id=room_id,
        building_id=building_id,
        location_id=location_id,
        mappoint_id=mappoint_id,
        is_outdoor=is_outdoor,
    )
    session.add(fault)
    session.commit()
    session.refresh(fault)
    return fault


# ---------------------------------------------------------------------------
# Rol-helpers (volgorde is KRITIEK, sien rights_catalog)
# ---------------------------------------------------------------------------
def _get_or_create_role(session: Session, role_name: str) -> Role:
    role = session.exec(select(Role).where(Role.role_name == role_name)).first()
    if role:
        return role

    role = Role(role_name=role_name)
    session.add(role)
    session.commit()
    session.refresh(role)
    return role


def _get_or_create_default_role(session: Session) -> Role:
    """Skep Standard-gebruiker-rol (role_id=1). Kan NIE aanmeld nie."""
    return _get_or_create_role(session, "User")


def _get_or_create_fk_role(session: Session) -> Role:
    """Skep FK-Koördineerder-rol (role_id=2). Kan aanmeld, beperkte toegang."""
    return _get_or_create_role(session, "Fasiliteit Koördineerder")


def _get_or_create_admin_role(session: Session) -> Role:
    """Skep Administrator-rol (role_id=3). Volle stelsel-toegang."""
    return _get_or_create_role(session, "Administrateur")


def _get_or_create_contractor_role(session: Session) -> Role:
    """Skep Kontrakteur-rol (role_id=4). Kan aanmeld op mobiele app."""
    return _get_or_create_role(session, "Kontrakteur")


def _get_or_create_dosent_role(session: Session) -> Role:
    """Skep Dosent-rol (role_id=5). Voer lokale kontroles uit op mobiele app."""
    return _get_or_create_role(session, "Dosent")


def _get_or_create_right(session: Session, right_name: str, description: str) -> Rights:
    right = session.exec(select(Rights).where(Rights.right_name == right_name)).first()
    if right:
        return right

    right = Rights(right_name=right_name, right_description=description)
    session.add(right)
    session.commit()
    session.refresh(right)
    return right


def _get_or_create_role_right(session: Session, role_id: int, right_id: int) -> RoleRight:
    existing = session.exec(
        select(RoleRight).where(
            RoleRight.role_id == role_id,
            RoleRight.right_id == right_id,
        )
    ).first()
    if existing:
        return existing

    role_right = RoleRight(role_id=role_id, right_id=right_id)
    session.add(role_right)
    session.commit()
    session.refresh(role_right)
    return role_right


def _migrate_legacy_rights(session: Session) -> None:
    """Eenmalige, idempotente hertoewysing van die ou (voor-opsplitsing)
    regname na die nuwe katalogus. Wanneer die ou name weg is, is dit 'n no-op."""
    name_to_id = {r.right_name: r.right_id for r in session.exec(select(Rights)).all()}

    legacy_present = [name for name in LEGACY_RIGHT_MIGRATION if name in name_to_id]
    if not legacy_present:
        return

    for name, description in RIGHTS_CATALOG.items():
        if name not in name_to_id:
            _get_or_create_right(session, name, description)
    name_to_id = {r.right_name: r.right_id for r in session.exec(select(Rights)).all()}

    rows = session.exec(
        select(RoleRight, Rights.right_name)
        .join(Rights, Rights.right_id == RoleRight.right_id)
    ).all()

    for role_right, right_name in rows:
        replacements = LEGACY_RIGHT_MIGRATION.get(right_name)
        if replacements is None:
            continue
        if right_name in replacements:
            continue
        for replacement in replacements:
            replacement_id = name_to_id.get(replacement)
            if replacement_id is not None:
                _get_or_create_role_right(session, role_right.role_id, replacement_id)
        session.delete(role_right)

    retired_names = [
        name for name in LEGACY_RIGHT_MIGRATION
        if name not in RIGHTS_CATALOG and name in name_to_id
    ]
    if retired_names:
        retired = session.exec(
            select(Rights).where(Rights.right_name.in_(retired_names))
        ).all()
        for right in retired:
            session.delete(right)

    session.commit()


def seed_rights(session: Session) -> None:
    """Seed die Rights-katalogus en RoleRight-toewysings (idempotent)."""
    _migrate_legacy_rights(session)

    name_to_id: dict[str, int] = {}
    for right_name, description in RIGHTS_CATALOG.items():
        right = _get_or_create_right(session, right_name, description)
        name_to_id[right_name] = right.right_id

    for role_id, right_names in ROLE_RIGHTS.items():
        for right_name in right_names:
            _get_or_create_role_right(session, role_id, name_to_id[right_name])


def _create_asset_audit_log(
    session: Session,
    asset: Asset,
    action: str = "create",
    previous_value: Optional[dict] = None,
    new_value: Optional[dict] = None,
    affected_columns: Optional[list] = None,
    timestamp: Optional[datetime] = None,
) -> None:
    """Skep 'n oudit-log vir 'n bate (idempotent per log-tydstempel)."""
    base_filters = [
        Auditlog.affectedtable == "asset",
        Auditlog.affectedid == asset.asset_id,
        Auditlog.action == action,
    ]
    existing = session.exec(
        select(Auditlog).where(
            *base_filters,
            Auditlog.actiondatetime == timestamp,
        )
    ).first()
    if not existing and affected_columns is not None:
        existing = session.exec(
            select(Auditlog).where(
                *base_filters,
                Auditlog.affectedcolumn == affected_columns,
                Auditlog.actiondatetime.isnot(None),
            )
        ).first()
    if existing:
        return

    full_record = asset.model_dump(mode="json")

    if new_value is None:
        new_value = full_record

    audit_log = Auditlog(
        action=action,
        affectedtable="asset",
        affectedcolumn=affected_columns,
        affectedid=asset.asset_id,
        previous_value=previous_value,
        new_value=new_value,
        json_data=full_record,
        actiondatetime=timestamp or NOW,
        user_id=None,
    )
    session.add(audit_log)
    session.commit()


def _migrate_plaintext_passwords(session: Session) -> None:
    """Eenmalige migrasie van platteks-wagwoorde na hashes (idempotent)."""
    users = session.exec(select(User)).all()
    migrated = 0
    for user in users:
        if not is_hashed(user.user_password):
            user.user_password = hash_password(user.user_password)
            session.add(user)
            migrated += 1
    if migrated:
        session.commit()
        print(f"Migrated {migrated} plaintext password(s) to hashed storage.")


# ---------------------------------------------------------------------------
# Lokaal-kontrole / kalender helpers
# ---------------------------------------------------------------------------
def _get_or_create_room_check(
    session: Session,
    room_id: int,
    user_id: Optional[int],
    items: list[dict],
    checked_datetime: Optional[datetime] = None,
) -> RoomCheck:
    """Skep 'n RoomCheck met 'n JSON-summary van {asset_id, status}-items.

    status kan wees: "ok", "fault_reported" (met `fault_id`) of "missing".
    """
    summary = json.dumps(items, ensure_ascii=False)
    check = session.exec(
        select(RoomCheck).where(
            RoomCheck.room_id == room_id,
            RoomCheck.user_id == user_id,
            func.date(RoomCheck.checked_datetime) == func.date(checked_datetime or NOW),
        )
    ).first()
    if check:
        return check

    check = RoomCheck(
        room_id=room_id,
        user_id=user_id,
        summary=summary,
        checked_datetime=checked_datetime or NOW,
    )
    session.add(check)
    session.commit()
    session.refresh(check)
    return check


def _get_or_create_room_check_session(
    session: Session,
    room_id: int,
    assigned_user_id: int,
    scheduled_datetime: Optional[datetime] = None,
    status: str = "scheduled",
    calendar_event_id: Optional[int] = None,
    room_check_id: Optional[int] = None,
    created_by: Optional[int] = None,
    notes: Optional[str] = None,
) -> RoomCheckSession:
    """Skep 'n (geskeduleerde/voltooide) lokaal-kontrole-sessie, idempotent."""
    existing = session.exec(
        select(RoomCheckSession).where(
            RoomCheckSession.room_id == room_id,
            RoomCheckSession.assigned_user_id == assigned_user_id,
            func.date(RoomCheckSession.scheduled_datetime) == func.date(scheduled_datetime or NOW),
            RoomCheckSession.status == status,
        )
    ).first()
    if existing:
        return existing

    check_session = RoomCheckSession(
        room_id=room_id,
        assigned_user_id=assigned_user_id,
        scheduled_datetime=scheduled_datetime,
        status=status,
        calendar_event_id=calendar_event_id,
        room_check_id=room_check_id,
        created_by=created_by,
        notes=notes,
    )
    session.add(check_session)
    session.commit()
    session.refresh(check_session)
    return check_session


def _get_or_create_event(
    session: Session,
    title: str,
    start_dt: datetime,
    end_dt: Optional[datetime] = None,
    desc: str = "",
    event_location: str = "",
    color: Optional[str] = None,
    user_id: Optional[int] = None,
) -> CalendarEvent:
    """Skep 'n kalender-gebeurtenis (idempotent per titel + eienaar)."""
    ev = session.exec(
        select(CalendarEvent).where(
            CalendarEvent.title == title,
            CalendarEvent.user_id == user_id,
        )
    ).first()
    if ev:
        return ev

    ev = CalendarEvent(
        title=title,
        description=desc,
        start_datetime=start_dt,
        end_datetime=end_dt or start_dt + timedelta(hours=1),
        all_day=False,
        location=event_location,
        color=color,
        user_id=user_id,
    )
    session.add(ev)
    session.commit()
    session.refresh(ev)
    return ev


def _ok_items(assets: list[Asset]) -> list[dict]:
    """Bou 'n JSON-summary van 'alles reg' items vir 'n lokaal-kontrole."""
    return [{"asset_id": a.asset_id, "status": "ok"} for a in assets]


def _items_with_fault(assets: list[Asset], fault_filter_serial: str, fault_id: int) -> list[dict]:
    """Bou items waar een bate as 'fault_reported' gemerk word."""
    items = []
    for a in assets:
        if a.asset_serial == fault_filter_serial:
            items.append({"asset_id": a.asset_id, "status": "fault_reported", "fault_id": fault_id})
        else:
            items.append({"asset_id": a.asset_id, "status": "ok"})
    return items


def _items_with_missing(assets: list[Asset], missing_serial: str) -> list[dict]:
    """Bou items waar een bate as 'vermis' gemerk word."""
    items = []
    for a in assets:
        if a.asset_serial == missing_serial:
            items.append({"asset_id": a.asset_id, "status": "missing"})
        else:
            items.append({"asset_id": a.asset_id, "status": "ok"})
    return items


# ---------------------------------------------------------------------------
# Hoof-seed
# ---------------------------------------------------------------------------
def seed_data():
    """Seed-funksie — inisialiseer databasis met realisitiese, historiese data."""
    print("Seed function called")
    with Session(engine) as session:
        # Rol-orde is KRITIEK: Administrateur MOET role_id=3 wees vir die
        # frontend-kontrole (kyk rights_catalog.ROLE_*).
        user_role = _get_or_create_default_role(session)                    # ID 1
        fk_role = _get_or_create_fk_role(session)                           # ID 2
        admin_role = _get_or_create_admin_role(session)                     # ID 3
        contractor_role = _get_or_create_contractor_role(session)           # ID 4
        dosent_role = _get_or_create_dosent_role(session)                   # ID 5

        seed_rights(session)

        # Tersoort: een kwotasie vir ontwikkeling (dokument-oplaai-blok).
        test_quote = _get_or_create_test_quote(session)
        print("Seed ensured test quote_id:", getattr(test_quote, "quote_id", None))

        # ═══════════════════════════════════════════════════════════════════
        # 1. TERREINE
        # ═══════════════════════════════════════════════════════════════════
        leriba = _get_or_create_location(
            session,
            name="Leriba",
            location_type="Kampus",
            streetnum="245",
            streetname="Endstraat",
            suburb="Clubview",
            city="Centurion",
            province="Gauteng",
            country="Suid Afrika",
            latitude=-25.8480,
            longitude=28.2366,
            radius=110,
        )

        gerhard = _get_or_create_location(
            session,
            name="Gerhard",
            location_type="Kampus",
            streetnum="117",
            streetname="Gerhardstraat",
            suburb="Die Hoewes",
            city="Centurion",
            province="Gauteng",
            country="Suid Afrika",
            latitude=-25.8471,
            longitude=28.2334,
            radius=110,
        )

        # ═══════════════════════════════════════════════════════════════════
        # 2. GEBODE
        # ═══════════════════════════════════════════════════════════════════
        leriba_boerneef = _get_or_create_building(
            session,
            name="Boerneef",
            building_type=BuildingType.ADMIN,
            location_id=leriba.location_id,
            building_types=[BuildingType.ADMIN, BuildingType.EDUCATIONAL],
        )
        leriba_lblok = _get_or_create_building(
            session,
            name="L-blok",
            building_type=BuildingType.EDUCATIONAL,
            location_id=leriba.location_id,
        )
        gerhard_gblok = _get_or_create_building(
            session,
            name="G-blok",
            building_type=BuildingType.EDUCATIONAL,
            location_id=gerhard.location_id,
            building_types=[BuildingType.EDUCATIONAL, BuildingType.ADMIN],
        )
        gerhard_lblok = _get_or_create_building(
            session,
            name="L-blok",
            building_type=BuildingType.EDUCATIONAL,
            location_id=gerhard.location_id,
        )

        # ═══════════════════════════════════════════════════════════════════
        # 3. LOKALE
        # Lokaal-kode-konvensie: <blokkode><tipekode><nommer/letter>
        #   C = klaskamer, K = kantoor, B = badkamer (gereserveer), A = admin
        # Aksioon-reeks: "AK " + lokaal kode + 6 sylfers (bv. AK CL4000001).
        # ═══════════════════════════════════════════════════════════════════
        roosmaryn = _get_or_create_room(
            session,
            name="Roosmaryn",
            code="CL9",
            capacity=36,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=leriba_boerneef.building_id,
        )
        huilboom = _get_or_create_room(
            session,
            name="Huilboom",
            code="AL10",
            capacity=8,
            room_type=RoomType.OFFICE,
            room_status=RoomStatus.OPERATIONAL,
            building_id=leriba_boerneef.building_id,
        )
        bitterbessie = _get_or_create_room(
            session,
            name="Bitterbessie",
            code="CL5",
            capacity=30,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=leriba_lblok.building_id,
        )
        spesie = _get_or_create_room(
            session,
            name="Spesie",
            code="CL4",
            capacity=30,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=leriba_lblok.building_id,
        )
        gcla = _get_or_create_room(
            session,
            name="Klaskamer CLA",
            code="CLA",
            capacity=28,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=gerhard_gblok.building_id,
        )
        gclb = _get_or_create_room(
            session,
            name="Klaskamer CLB",
            code="CLB",
            capacity=32,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=gerhard_lblok.building_id,
        )
        gclc = _get_or_create_room(
            session,
            name="Klaskamer CLC",
            code="CLC",
            capacity=26,
            room_type=RoomType.CLASSROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=gerhard_lblok.building_id,
        )
        galb = _get_or_create_room(
            session,
            name="Admin Kantoor ALB",
            code="ALB",
            capacity=5,
            room_type=RoomType.OFFICE,
            room_status=RoomStatus.OPERATIONAL,
            building_id=gerhard_gblok.building_id,
        )

        # ═══════════════════════════════════════════════════════════════════
        # 4. BATE-TIPES
        # ═══════════════════════════════════════════════════════════════════
        type_it = _get_or_create_assettype(session, "IT Toerusting", avg=48, min_=24, max_=72, interval=12, threshold=2)
        type_meubels = _get_or_create_assettype(session, "Meubels", avg=120, min_=60, max_=180, interval=24, threshold=2)
        type_elek = _get_or_create_assettype(session, "Elektriese Toerusting", avg=60, min_=36, max_=84, interval=6, threshold=2)
        type_hvac = _get_or_create_assettype(session, "HVAC Toerusting", avg=84, min_=60, max_=120, interval=6, threshold=2)
        type_veiligheid = _get_or_create_assettype(session, "Veiligheidstoerusting", avg=36, min_=12, max_=60, interval=3, threshold=2)

        # ═══════════════════════════════════════════════════════════════════
        # 5. BATES — 10 per lokaal, reeks "AK <kode>000001..000010"
        #    Skepdatums oor die afgelope ~24 maande vir realistiese ouderdom.
        # ═══════════════════════════════════════════════════════════════════
        # ── Leriba / Boerneef ─────────────────────────────────────────────
        roosmaryn_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-2250U", "Epson", "AK CL9000001", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_it.assettype_id, NOW - timedelta(days=530)),
            _get_or_create_asset(session, "Klasstoel", "Cecil Nurse", "AK CL9000002", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_meubels.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Klasstoel", "Cecil Nurse", "AK CL9000003", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_meubels.assettype_id, NOW - timedelta(days=620)),
            _get_or_create_asset(session, "Klasbank", "Steelcase", "AK CL9000004", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_meubels.assettype_id, NOW - timedelta(days=610)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CL9000005", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_meubels.assettype_id, NOW - timedelta(days=240)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CL9000006", AssetStatus.MAINTENANCE, False, roosmaryn.room_id, type_it.assettype_id, NOW - timedelta(days=200)),
            _get_or_create_asset(session, "Lugversorging", "Samsung", "AK CL9000007", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_hvac.assettype_id, NOW - timedelta(days=480)),
            _get_or_create_asset(session, "Brandblusser", "SafeSys", "AK CL9000008", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CL9000009", AssetStatus.INACTIVE, False, roosmaryn.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=560)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK CL9000010", AssetStatus.ACTIVE, False, roosmaryn.room_id, type_meubels.assettype_id, NOW - timedelta(days=390)),
        ]

        huilboom_assets = [
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK AL1000001", AssetStatus.ACTIVE, False, huilboom.room_id, type_it.assettype_id, NOW - timedelta(days=450)),
            _get_or_create_asset(session, "Kantoorstoel", "Herman Miller", "AK AL1000002", AssetStatus.ACTIVE, False, huilboom.room_id, type_meubels.assettype_id, NOW - timedelta(days=720)),
            _get_or_create_asset(session, "Drukker LaserJet", "HP", "AK AL1000003", AssetStatus.MAINTENANCE, False, huilboom.room_id, type_it.assettype_id, NOW - timedelta(days=500)),
            _get_or_create_asset(session, "Skryftafel", "Steelcase", "AK AL1000004", AssetStatus.ACTIVE, False, huilboom.room_id, type_meubels.assettype_id, NOW - timedelta(days=720)),
            _get_or_create_asset(session, "Lugversorging", "LG", "AK AL1000005", AssetStatus.ACTIVE, False, huilboom.room_id, type_hvac.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Brandblusser", "Ace", "AK AL1000006", AssetStatus.ACTIVE, False, huilboom.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=280)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK AL1000007", AssetStatus.ACTIVE, False, huilboom.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=280)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK AL1000008", AssetStatus.ACTIVE, False, huilboom.room_id, type_meubels.assettype_id, NOW - timedelta(days=330)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK AL1000009", AssetStatus.ACTIVE, False, huilboom.room_id, type_elek.assettype_id, NOW - timedelta(days=420)),
            _get_or_create_asset(session, "Telefoon", "Yealink", "AK AL1000010", AssetStatus.DECOMMISSIONED, False, huilboom.room_id, type_it.assettype_id, NOW - timedelta(days=580)),
        ]

        # ── Leriba / L-blok ────────────────────────────────────────────────
        bitterbessie_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-2155W", "Epson", "AK CL5000001", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_it.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Klasstoel", "Dauphin", "AK CL5000002", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_meubels.assettype_id, NOW - timedelta(days=680)),
            _get_or_create_asset(session, "Klasstoel", "Dauphin", "AK CL5000003", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_meubels.assettype_id, NOW - timedelta(days=680)),
            _get_or_create_asset(session, "Klasbank", "Barker Street", "AK CL5000004", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_meubels.assettype_id, NOW - timedelta(days=660)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CL5000005", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_meubels.assettype_id, NOW - timedelta(days=520)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CL5000006", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_it.assettype_id, NOW - timedelta(days=380)),
            _get_or_create_asset(session, "Lugversorging", "Samsung", "AK CL5000007", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_hvac.assettype_id, NOW - timedelta(days=440)),
            _get_or_create_asset(session, "Brandblusser", "SafeSys", "AK CL5000008", AssetStatus.MAINTENANCE, False, bitterbessie.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=320)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CL5000009", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=320)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK CL5000010", AssetStatus.ACTIVE, False, bitterbessie.room_id, type_meubels.assettype_id, NOW - timedelta(days=410)),
        ]

        spesie_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-S41", "Epson", "AK CL4000001", AssetStatus.ACTIVE, False, spesie.room_id, type_it.assettype_id, NOW - timedelta(days=600)),
            _get_or_create_asset(session, "Klasstoel", "Dauphin", "AK CL4000002", AssetStatus.ACTIVE, False, spesie.room_id, type_meubels.assettype_id, NOW - timedelta(days=640)),
            _get_or_create_asset(session, "Klasstoel", "Dauphin", "AK CL4000003", AssetStatus.ACTIVE, False, spesie.room_id, type_meubels.assettype_id, NOW - timedelta(days=640)),
            _get_or_create_asset(session, "Klasbank", "Barker Street", "AK CL4000004", AssetStatus.ACTIVE, False, spesie.room_id, type_meubels.assettype_id, NOW - timedelta(days=620)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CL4000005", AssetStatus.ACTIVE, False, spesie.room_id, type_meubels.assettype_id, NOW - timedelta(days=280)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CL4000006", AssetStatus.ACTIVE, False, spesie.room_id, type_it.assettype_id, NOW - timedelta(days=360)),
            _get_or_create_asset(session, "Lugversorging", "LG", "AK CL4000007", AssetStatus.ACTIVE, False, spesie.room_id, type_hvac.assettype_id, NOW - timedelta(days=400)),
            _get_or_create_asset(session, "Brandblusser", "SafeSys", "AK CL4000008", AssetStatus.ACTIVE, False, spesie.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CL4000009", AssetStatus.ACTIVE, False, spesie.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK CL4000010", AssetStatus.ACTIVE, False, spesie.room_id, type_elek.assettype_id, NOW - timedelta(days=460)),
        ]

        # ── Gerhard / G-blok + L-blok ──────────────────────────────────────
        gcla_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-2250U", "Epson", "AK CLA000001", AssetStatus.ACTIVE, False, gcla.room_id, type_it.assettype_id, NOW - timedelta(days=500)),
            _get_or_create_asset(session, "Klasstoel", "Cecil Nurse", "AK CLA000002", AssetStatus.ACTIVE, False, gcla.room_id, type_meubels.assettype_id, NOW - timedelta(days=680)),
            _get_or_create_asset(session, "Klasbank", "Steelcase", "AK CLA000003", AssetStatus.ACTIVE, False, gcla.room_id, type_meubels.assettype_id, NOW - timedelta(days=660)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CLA000004", AssetStatus.ACTIVE, False, gcla.room_id, type_meubels.assettype_id, NOW - timedelta(days=380)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CLA000005", AssetStatus.ACTIVE, False, gcla.room_id, type_it.assettype_id, NOW - timedelta(days=420)),
            _get_or_create_asset(session, "Lugversorging", "Samsung", "AK CLA000006", AssetStatus.MAINTENANCE, False, gcla.room_id, type_hvac.assettype_id, NOW - timedelta(days=470)),
            _get_or_create_asset(session, "Brandblusser", "SafeSys", "AK CLA000007", AssetStatus.ACTIVE, False, gcla.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=290)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CLA000008", AssetStatus.ACTIVE, False, gcla.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=290)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK CLA000009", AssetStatus.ACTIVE, False, gcla.room_id, type_meubels.assettype_id, NOW - timedelta(days=310)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK CLA000010", AssetStatus.ACTIVE, False, gcla.room_id, type_elek.assettype_id, NOW - timedelta(days=450)),
        ]

        gclb_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-2155W", "Epson", "AK CLB000001", AssetStatus.ACTIVE, False, gclb.room_id, type_it.assettype_id, NOW - timedelta(days=620)),
            _get_or_create_asset(session, "Klasstoel", "Dauphin", "AK CLB000002", AssetStatus.ACTIVE, False, gclb.room_id, type_meubels.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Klasbank", "Barker Street", "AK CLB000003", AssetStatus.ACTIVE, False, gclb.room_id, type_meubels.assettype_id, NOW - timedelta(days=690)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CLB000004", AssetStatus.ACTIVE, False, gclb.room_id, type_meubels.assettype_id, NOW - timedelta(days=400)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CLB000005", AssetStatus.ACTIVE, False, gclb.room_id, type_it.assettype_id, NOW - timedelta(days=350)),
            _get_or_create_asset(session, "Lugversorging", "LG", "AK CLB000006", AssetStatus.ACTIVE, False, gclb.room_id, type_hvac.assettype_id, NOW - timedelta(days=480)),
            _get_or_create_asset(session, "Brandblusser", "SafeSys", "AK CLB000007", AssetStatus.MAINTENANCE, False, gclb.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CLB000008", AssetStatus.ACTIVE, False, gclb.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK CLB000009", AssetStatus.ACTIVE, False, gclb.room_id, type_meubels.assettype_id, NOW - timedelta(days=320)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK CLB000010", AssetStatus.ACTIVE, False, gclb.room_id, type_elek.assettype_id, NOW - timedelta(days=440)),
        ]

        gclc_assets = [
            _get_or_create_asset(session, "Projektor Epson EB-S41", "Epson", "AK CLC000001", AssetStatus.ACTIVE, False, gclc.room_id, type_it.assettype_id, NOW - timedelta(days=560)),
            _get_or_create_asset(session, "Klasstoel", "Cecil Nurse", "AK CLC000002", AssetStatus.ACTIVE, False, gclc.room_id, type_meubels.assettype_id, NOW - timedelta(days=660)),
            _get_or_create_asset(session, "Klasbank", "Steelcase", "AK CLC000003", AssetStatus.ACTIVE, False, gclc.room_id, type_meubels.assettype_id, NOW - timedelta(days=640)),
            _get_or_create_asset(session, "Witbord", "LimitLinx", "AK CLC000004", AssetStatus.ACTIVE, False, gclc.room_id, type_meubels.assettype_id, NOW - timedelta(days=360)),
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK CLC000005", AssetStatus.ACTIVE, False, gclc.room_id, type_it.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Lugversorging", "Samsung", "AK CLC000006", AssetStatus.ACTIVE, False, gclc.room_id, type_hvac.assettype_id, NOW - timedelta(days=430)),
            _get_or_create_asset(session, "Brandblusser", "Ace", "AK CLC000007", AssetStatus.ACTIVE, False, gclc.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK CLC000008", AssetStatus.ACTIVE, False, gclc.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=300)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK CLC000009", AssetStatus.ACTIVE, False, gclc.room_id, type_meubels.assettype_id, NOW - timedelta(days=310)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK CLC000010", AssetStatus.DECOMMISSIONED, False, gclc.room_id, type_elek.assettype_id, NOW - timedelta(days=590)),
        ]

        galb_assets = [
            _get_or_create_asset(session, "Rekenaar Dell OptiPlex", "Dell", "AK ALB000001", AssetStatus.ACTIVE, False, galb.room_id, type_it.assettype_id, NOW - timedelta(days=430)),
            _get_or_create_asset(session, "Kantoorstoel", "Herman Miller", "AK ALB000002", AssetStatus.ACTIVE, False, galb.room_id, type_meubels.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Drukker LaserJet", "HP", "AK ALB000003", AssetStatus.ACTIVE, False, galb.room_id, type_it.assettype_id, NOW - timedelta(days=480)),
            _get_or_create_asset(session, "Skryftafel", "Steelcase", "AK ALB000004", AssetStatus.ACTIVE, False, galb.room_id, type_meubels.assettype_id, NOW - timedelta(days=700)),
            _get_or_create_asset(session, "Lugversorging", "LG", "AK ALB000005", AssetStatus.MAINTENANCE, False, galb.room_id, type_hvac.assettype_id, NOW - timedelta(days=670)),
            _get_or_create_asset(session, "Brandblusser", "Ace", "AK ALB000006", AssetStatus.ACTIVE, False, galb.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=280)),
            _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "AK ALB000007", AssetStatus.ACTIVE, False, galb.room_id, type_veiligheid.assettype_id, NOW - timedelta(days=280)),
            _get_or_create_asset(session, "Sluitbare kas", "LockFast", "AK ALB000008", AssetStatus.ACTIVE, False, galb.room_id, type_meubels.assettype_id, NOW - timedelta(days=330)),
            _get_or_create_asset(session, "Plafonwaaier", "Fanco", "AK ALB000009", AssetStatus.ACTIVE, False, galb.room_id, type_elek.assettype_id, NOW - timedelta(days=410)),
            _get_or_create_asset(session, "Telefoon", "Yealink", "AK ALB000010", AssetStatus.ACTIVE, False, galb.room_id, type_it.assettype_id, NOW - timedelta(days=380)),
        ]

        # ═══════════════════════════════════════════════════════════════════
        # 6. GEBRUIKERS — 10 per kampus + 4 kontrakteurs
        #    (5 studente, 3 dosente, 1 FK, 1 admin per kampus)
        # ═══════════════════════════════════════════════════════════════════
        _PSW = "Akademia@2024"

        # ── Leriba ────────────────────────────────────────────────────────
        student_names = [
            ("Lerato", "Mokoena"), ("Sipho", "Nkosi"), ("Anke", "van der Walt"),
            ("Ruan", "Kruger"), ("Naledi", "Mabena"),
        ]
        leriba_students = []
        for i, (n, s) in enumerate(student_names):
            u = _get_or_create_test_user(
                session, n, s,
                f"{n.lower()}.{s.lower()}@student.akademia.co.za",
                _PSW, user_role.role_id, location_id=leriba.location_id,
                user_number=f"+27 82 100 1{i:03d}",
                last_login=NOW - timedelta(days=3 + i),
                last_logout=NOW - timedelta(days=3 + i, hours=8),
            )
            leriba_students.append(u)

        dosent_names = [
            ("Elmarie", "Botha"), ("Pieter", "Olivier"), ("Michelle", "Jacobs"),
        ]
        leriba_dosente = []
        for i, (n, s) in enumerate(dosent_names):
            u = _get_or_create_test_user(
                session, n, s,
                f"{n.lower()}.{s.lower()}@akademia.co.za",
                _PSW, dosent_role.role_id, location_id=leriba.location_id,
                user_number=f"+27 83 200 2{i:03d}",
                last_login=NOW - timedelta(days=1),
                last_logout=NOW - timedelta(days=1, hours=4),
            )
            leriba_dosente.append(u)

        leriba_fk = _get_or_create_test_user(
            session, "Johan", "Venter", "johan.venter@akademia.co.za",
            _PSW, fk_role.role_id, location_id=leriba.location_id,
            user_number="+27 84 300 0001",
            last_login=NOW - timedelta(hours=2),
            last_logout=NOW - timedelta(hours=1),
        )
        leriba_admin = _get_or_create_test_user(
            session, "Sandi", "Prinsloo", "sandi.prinsloo@akademia.co.za",
            _PSW, admin_role.role_id, location_id=leriba.location_id,
            user_number="+27 84 300 0002",
            last_login=NOW - timedelta(hours=1),
            last_logout=None,
        )

        # ── Gerhard ───────────────────────────────────────────────────────
        student_names_g = [
            ("Thabo", "Mahlangu"), ("Emma", "du Plessis"), ("Megan", "Petersen"),
            ("Kai", "van Wyk"), ("Zanele", "Dlamini"),
        ]
        gerhard_students = []
        for i, (n, s) in enumerate(student_names_g):
            u = _get_or_create_test_user(
                session, n, s,
                f"{n.lower()}.{s.lower()}@student.akademia.co.za",
                _PSW, user_role.role_id, location_id=gerhard.location_id,
                user_number=f"+27 82 500 1{i:03d}",
                last_login=NOW - timedelta(days=2 + i),
                last_logout=NOW - timedelta(days=2 + i, hours=7),
            )
            gerhard_students.append(u)

        dosent_names_g = [
            ("Francois", "Marais"), ("Hanlie", "Swanepoel"), ("Nomsa", "Cele"),
        ]
        gerhard_dosente = []
        for i, (n, s) in enumerate(dosent_names_g):
            u = _get_or_create_test_user(
                session, n, s,
                f"{n.lower()}.{s.lower()}@akademia.co.za",
                _PSW, dosent_role.role_id, location_id=gerhard.location_id,
                user_number=f"+27 83 600 2{i:03d}",
                last_login=NOW - timedelta(days=1),
                last_logout=NOW - timedelta(days=1, hours=5),
            )
            gerhard_dosente.append(u)

        gerhard_fk = _get_or_create_test_user(
            session, "Bongani", "Zuma", "bongani.zuma@akademia.co.za",
            _PSW, fk_role.role_id, location_id=gerhard.location_id,
            user_number="+27 84 700 0001",
            last_login=NOW - timedelta(hours=3),
            last_logout=NOW - timedelta(hours=2),
        )
        gerhard_admin = _get_or_create_test_user(
            session, "Kobus", "Dewald", "kobus.dewald@akademia.co.za",
            _PSW, admin_role.role_id, location_id=gerhard.location_id,
            user_number="+27 84 700 0002",
            last_login=NOW - timedelta(hours=2),
            last_logout=NOW - timedelta(minutes=30),
        )

        # ── Kontrakteurs (rol 4) ──────────────────────────────────────────
        kontrakteurs = []
        for i, (n, s, e, ph) in enumerate([
            ("Jan", "Botha", "jan.botha@workfix.co.za", "+27 71 800 0001"),
            ("Lindiwe", "Mokoena", "lindiwe.mokoena@plumbright.co.za", "+27 71 800 0002"),
            ("Thabo", "Cilliers", "thabo@coolair.co.za", "+27 71 800 0003"),
            ("Susan", "Venter", "susan@kombuiswerke.co.za", "+27 71 800 0004"),
        ]):
            u = _get_or_create_test_user(
                session, n, s, e, _PSW, contractor_role.role_id,
                user_number=ph,
                last_login=NOW - timedelta(days=1 + i),
                last_logout=NOW - timedelta(days=1 + i, hours=6),
            )
            kontrakteurs.append(u)

        # ── Legacy "User" (kan nie aanmeld nie, rol 1) ────────────────────
        _get_or_create_test_user(
            session, "test", "user", "test@example.com", "password123",
            user_role.role_id,
            last_login=NOW - timedelta(days=400),
            last_logout=NOW - timedelta(days=400, hours=6),
        )

        # ═══════════════════════════════════════════════════════════════════
        # 7. VOORRAAD per lokaal (sommige onder minimum vir lae-voorraad-meldings)
        # ═══════════════════════════════════════════════════════════════════
        _get_or_create_stock(session, "Projektor lamp Epson", "Epson", 4, 2, 8, "Onderdele",
            "Elprojektor-lamp (ELPLP88) vir EB-2250U/EB-2155W-projektors.", roosmaryn.room_id)
        _get_or_create_stock(session, "Witbord-merkers", "Edding", 12, 6, 24, "Verbruiksgoedere",
            "Witbordmerkers blou/swart/rooi.", roosmaryn.room_id)
        _get_or_create_stock(session, "Klasstoel-onderdele", "Dauphin", 6, 10, 20, "Onderdele",
            "Stoelhandvatsels en -wielfijies (onder minimum).", roosmaryn.room_id)

        _get_or_create_stock(session, "Drukker-toner LaserJet", "HP", 3, 2, 6, "Verbruiksgoedere",
            "HP 26A swart toner (CF226A).", huilboom.room_id)
        _get_or_create_stock(session, "A4-koppapier", "Double A", 5, 10, 20, "Verbruiksgoedere",
            "A4 80g koepapier (onder minimum).", huilboom.room_id)

        _get_or_create_stock(session, "Klasbank-onderdele", "Barker Street", 4, 2, 8, "Onderdele",
            "Bankpote en -boute vir klaskamers.", bitterbessie.room_id)
        _get_or_create_stock(session, "Gloeilampe T8", "OSRAM", 20, 10, 40, "Verbruiksgoedere",
            "T8 1200mm 36W koelwit fluoresserende buis.", bitterbessie.room_id)

        _get_or_create_stock(session, "Lugversorger-filter", "LG", 4, 2, 8, "Onderdele",
            "LG-lugversorger-filter (pas LG-eenhede).", spesie.room_id)
        _get_or_create_stock(session, "Klasstoel-onderdele", "Cecil Nurse", 8, 10, 20, "Onderdele",
            "Stoelrug-onderdele (onder minimum).", spesie.room_id)

        _get_or_create_stock(session, "Projektor-lamp Epson", "Epson", 3, 2, 6, "Onderdele",
            "Elprojektor-lamp vir EB-S41.", gcla.room_id)
        _get_or_create_stock(session, "Brandblusser-tags", "SafeSys", 6, 3, 12, "Verbruiksgoedere",
            "Inspeksie-tags vir brandblussers.", gcla.room_id)

        _get_or_create_stock(session, "Klasbank-onderdele", "Steelcase", 5, 2, 10, "Onderdele",
            "Bankplate en -skroewe.", gclb.room_id)
        _get_or_create_stock(session, "Verf wit 20L", "Dulux", 1, 2, 5, "Verbruiksgoedere",
            "Wit muurverf vir raklewe (onder minimum).", gclb.room_id)

        _get_or_create_stock(session, "Plafonwaaier-onderdele", "Fanco", 5, 2, 10, "Onderdele",
            "Waaiermotors en -weerlaaie.", gclc.room_id)
        _get_or_create_stock(session, "Sement 50kg", "PPC", 2, 1, 5, "Onderdele",
            "Sement vir herstelwerk (onder minimum).", gclc.room_id)

        _get_or_create_stock(session, "Drukker-toner LaserJet", "HP", 4, 2, 6, "Verbruiksgoedere",
            "HP 26A swart toner.", galb.room_id)
        _get_or_create_stock(session, "Kantoorbenodigdhede", "OfficeHub", 2, 5, 10, "Verbruiksgoedere",
            "Krammetjies, penne, rekkies (onder minimum).", galb.room_id)

        # ═══════════════════════════════════════════════════════════════════
        # 8. GESKIEDENIS — FOUTKAARTJIES + WERKSOPDRAGTE
        #    5 foutkaartjies per terrein; 3 werksopdragte per terrein.
        #    4 kontrakteurs word aan 4 van die 6 werksopdragte toegewys.
        # ═══════════════════════════════════════════════════════════════════
        _roosmaryn_proj = next(a for a in roosmaryn_assets if a.asset_serial == "AK CL9000001")
        _roosmaryn_ac = next(a for a in roosmaryn_assets if a.asset_serial == "AK CL9000007")
        _huilboom_printer = next(a for a in huilboom_assets if a.asset_serial == "AK AL1000003")
        _bitter_proj = next(a for a in bitterbessie_assets if a.asset_serial == "AK CL5000001")
        _spesie_proj = next(a for a in spesie_assets if a.asset_serial == "AK CL4000001")
        _gcla_ac = next(a for a in gcla_assets if a.asset_serial == "AK CLA000006")
        _gclb_ext = next(a for a in gclb_assets if a.asset_serial == "AK CLB000007")
        _galb_ac = next(a for a in galb_assets if a.asset_serial == "AK ALB000005")
        _galb_printer = next(a for a in galb_assets if a.asset_serial == "AK ALB000003")
        _gclc_proj = next(a for a in gclc_assets if a.asset_serial == "AK CLC000001")

        _j1ctr = kontrakteurs[0].user_id   # Jan Botha (Werkfix)
        _j2ctr = kontrakteurs[1].user_id   # Lindiwe Mokoena (Plumbright)
        _j3ctr = kontrakteurs[2].user_id   # Thabo Cilliers (Coolair)
        _j4ctr = kontrakteurs[3].user_id   # Susan Venter (Kombuiswerke)

        # ── Leriba — 5 foutkaartjies ───────────────────────────────────────
        f1 = _get_or_create_fault(
            session, "Projektor in Roosmaryn projekteer nie die volle beeld nie.",
            FaultStatus.RESOLVED, Priority.MEDIUM, Type.REPAIR,
            NOW - timedelta(days=700),
            asset_id=_roosmaryn_proj.asset_id, room_id=roosmaryn.room_id,
            building_id=leriba_boerneef.building_id, location_id=leriba.location_id,
        )
        f2 = _get_or_create_fault(
            session, "Lugversorging in Roosmaryn blaas warm lug.",
            FaultStatus.IN_PROGRESS, Priority.HIGH, Type.REPAIR,
            NOW - timedelta(days=45),
            asset_id=_roosmaryn_ac.asset_id, room_id=roosmaryn.room_id,
            building_id=leriba_boerneef.building_id, location_id=leriba.location_id,
        )
        f3 = _get_or_create_fault(
            session, "Drukker in Huilboom papierstoor elke 20 blaaie.",
            FaultStatus.OPEN, Priority.LOW, Type.MAINTENANCE,
            NOW - timedelta(days=12),
            asset_id=_huilboom_printer.asset_id, room_id=huilboom.room_id,
            building_id=leriba_boerneef.building_id, location_id=leriba.location_id,
        )
        f4 = _get_or_create_fault(
            session, "Projektor in Bitterbessie flikker.",
            FaultStatus.CONFIRMED, Priority.MEDIUM, Type.REPAIR,
            NOW - timedelta(days=20),
            asset_id=_bitter_proj.asset_id, room_id=bitterbessie.room_id,
            building_id=leriba_lblok.building_id, location_id=leriba.location_id,
        )
        f5 = _get_or_create_fault(
            session, "Projektor in Spesie beeld is donker/vaal.",
            FaultStatus.OPEN, Priority.MEDIUM, Type.REPAIR,
            NOW - timedelta(days=8),
            asset_id=_spesie_proj.asset_id, room_id=spesie.room_id,
            building_id=leriba_lblok.building_id, location_id=leriba.location_id,
        )

        # ── Leriba — 3 werksopdragte (kontrakteur op 2 van 3) ──────────────
        _get_or_create_job(session, "Projektorlens skoongemaak en gekalibreer in Roosmaryn.",
            JobStatus.COMPLETED, "Onderhoud",
            created_dt=NOW - timedelta(days=698), finished_dt=NOW - timedelta(days=697),
            asset_id=_roosmaryn_proj.asset_id, room_id=roosmaryn.room_id,
            building_id=leriba_boerneef.building_id, location_id=leriba.location_id,
            fault_id=f1.fault_id, contractor_id=_j1ctr,
        )
        _get_or_create_job(session, "HVAC-gas hersirkuleer en diens Roosmaryn-eenheid.",
            JobStatus.IN_PROGRESS, "Onderhoud",
            created_dt=NOW - timedelta(days=3),
            asset_id=_roosmaryn_ac.asset_id, room_id=roosmaryn.room_id,
            building_id=leriba_boerneef.building_id, location_id=leriba.location_id,
            fault_id=f2.fault_id, contractor_id=_j3ctr,
        )
        _get_or_create_job(session, "Bitterbessie-projektorlamp vervang.",
            JobStatus.SCHEDULED, "Installasie",
            created_dt=NOW - timedelta(days=1),
            asset_id=_bitter_proj.asset_id, room_id=bitterbessie.room_id,
            building_id=leriba_lblok.building_id, location_id=leriba.location_id,
            fault_id=f4.fault_id,
        )

        # ── Gerhard — 5 foutkaartjies ─────────────────────────────────────
        fg1 = _get_or_create_fault(
            session, "Lugversorging in CLA maak harde geraas.",
            FaultStatus.OPEN, Priority.MEDIUM, Type.REPAIR,
            NOW - timedelta(days=6),
            asset_id=_gcla_ac.asset_id, room_id=gcla.room_id,
            building_id=gerhard_gblok.building_id, location_id=gerhard.location_id,
        )
        fg2 = _get_or_create_fault(
            session, "Brandblusser in CLB is agterstallig vir inspeksie.",
            FaultStatus.OPEN, Priority.LOW, Type.INSPECTION,
            NOW - timedelta(days=15),
            asset_id=_gclb_ext.asset_id, room_id=gclb.room_id,
            building_id=gerhard_lblok.building_id, location_id=gerhard.location_id,
        )
        fg3 = _get_or_create_fault(
            session, "Lugversorging in ALB lek water.",
            FaultStatus.RESOLVED, Priority.HIGH, Type.REPAIR,
            NOW - timedelta(days=90),
            asset_id=_galb_ac.asset_id, room_id=galb.room_id,
            building_id=gerhard_gblok.building_id, location_id=gerhard.location_id,
        )
        fg4 = _get_or_create_fault(
            session, "Projektor in CLC beeld skud.",
            FaultStatus.CLOSED, Priority.MEDIUM, Type.REPAIR,
            NOW - timedelta(days=150),
            asset_id=_gclc_proj.asset_id, room_id=gclc.room_id,
            building_id=gerhard_lblok.building_id, location_id=gerhard.location_id,
        )
        fg5 = _get_or_create_fault(
            session, "Drukker in ALB papierstoor elke 20 blaaie.",
            FaultStatus.OPEN, Priority.LOW, Type.MAINTENANCE,
            NOW - timedelta(days=10),
            asset_id=_galb_printer.asset_id, room_id=galb.room_id,
            building_id=gerhard_gblok.building_id, location_id=gerhard.location_id,
        )

        # ── Gerhard — 3 werksopdragte (kontrakteur op 2 van 3) ─────────────
        _get_or_create_job(session, "CLA-lugversorgerwaaier ondersoek.",
            JobStatus.IN_PROGRESS, "Onderhoud",
            created_dt=NOW - timedelta(days=5),
            asset_id=_gcla_ac.asset_id, room_id=gcla.room_id,
            building_id=gerhard_gblok.building_id, location_id=gerhard.location_id,
            fault_id=fg1.fault_id,
        )
        _get_or_create_job(session, "ALB-kondensaatlyn skoongemaak en herstel.",
            JobStatus.COMPLETED, "Herstelwerk",
            created_dt=NOW - timedelta(days=88), finished_dt=NOW - timedelta(days=86),
            asset_id=_galb_ac.asset_id, room_id=galb.room_id,
            building_id=gerhard_gblok.building_id, location_id=gerhard.location_id,
            fault_id=fg3.fault_id, contractor_id=_j2ctr,
        )
        _get_or_create_job(session, "CLC-projektor hakmontering vasgetrek.",
            JobStatus.COMPLETED, "Herstelwerk",
            created_dt=NOW - timedelta(days=149), finished_dt=NOW - timedelta(days=148),
            asset_id=_gclc_proj.asset_id, room_id=gclc.room_id,
            building_id=gerhard_lblok.building_id, location_id=gerhard.location_id,
            fault_id=fg4.fault_id, contractor_id=_j4ctr,
        )

        # ═══════════════════════════════════════════════════════════════════
        # 9. LOKAAL-KONTROLES (a) Bestaande/kontrole-geskiedenis en (b) skedules
        # ═══════════════════════════════════════════════════════════════════
        _leriba_dos1 = leriba_dosente[0].user_id
        _leriba_dos2 = leriba_dosente[1].user_id
        _leriba_dos3 = leriba_dosente[2].user_id
        _gerhard_dos1 = gerhard_dosente[0].user_id
        _gerhard_dos2 = gerhard_dosente[1].user_id
        _leriba_fk_id = leriba_fk.user_id
        _gerhard_fk_id = gerhard_fk.user_id

        def _checked(room: Room, assets: list, userid, days_back, items):
            dt = NOW - timedelta(days=days_back)
            check = _get_or_create_room_check(session, room.room_id, userid, items, dt)
            _get_or_create_room_check_session(
                session, room.room_id, userid, scheduled_datetime=dt,
                status="completed", room_check_id=check.room_check_id,
                created_by=_leriba_fk_id if room.room_id in (
                    roosmaryn.room_id, huilboom.room_id, bitterbessie.room_id, spesie.room_id,
                ) else _gerhard_fk_id,
                notes="Maandelikse lokaal-kontrole voltooi.",
            )

        # Roosmaryn — 4 kontroles oor 2 jaar (een met vermiste brandblusser-links)
        _checked(roosmaryn, roosmaryn_assets, _leriba_dos2, 660, _ok_items(roosmaryn_assets))
        _checked(roosmaryn, roosmaryn_assets, _leriba_dos2, 400,
                 _items_with_fault(roosmaryn_assets, "AK CL9000006", f2.fault_id))
        _checked(roosmaryn, roosmaryn_assets, _leriba_dos1, 140, _ok_items(roosmaryn_assets))
        _checked(roosmaryn, roosmaryn_assets, _leriba_dos1, 21,
                 _items_with_missing(roosmaryn_assets, "AK CL9000009"))

        # Huilboom — Word nie deur dosente gekontroleer nie (kantoor), FK doen
        _checked(huilboom, huilboom_assets, _leriba_fk_id, 220, _ok_items(huilboom_assets))
        _checked(huilboom, huilboom_assets, _leriba_fk_id, 30,
                 _items_with_fault(huilboom_assets, "AK AL1000003", f3.fault_id))

        # Bitterbessie — kontrole wat projektorfout aangemeld het
        _checked(bitterbessie, bitterbessie_assets, _leriba_dos3, 320, _ok_items(bitterbessie_assets))
        _checked(bitterbessie, bitterbessie_assets, _leriba_dos3, 85,
                 _items_with_fault(bitterbessie_assets, "AK CL5000001", f4.fault_id))
        _checked(bitterbessie, bitterbessie_assets, _leriba_dos2, 18, _ok_items(bitterbessie_assets))

        # Spesie — kontrole met vermiste stoel
        _checked(spesie, spesie_assets, _leriba_dos1, 190, _ok_items(spesie_assets))
        _checked(spesie, spesie_assets, _leriba_dos1, 24,
                 _items_with_missing(spesie_assets, "AK CL4000003"))

        # Gerhard — CLA / CLB / CLC / ALB
        _checked(gcla, gcla_assets, _gerhard_dos1, 250, _ok_items(gcla_assets))
        _checked(gcla, gcla_assets, _gerhard_dos2, 12,
                 _items_with_fault(gcla_assets, "AK CLA000006", fg1.fault_id))
        _checked(gclb, gclb_assets, _gerhard_dos2, 150,
                 _items_with_fault(gclb_assets, "AK CLB000007", fg2.fault_id))
        _checked(gclc, gclc_assets, _gerhard_dos1, 365,
                 _items_with_fault(gclc_assets, "AK CLC000001", fg4.fault_id))
        _checked(galb, galb_assets, _gerhard_fk_id, 60, _ok_items(galb_assets))

        # Geskeduleerde (toekomstige) kontroles
        _get_or_create_room_check_session(
            session, roosmaryn.room_id, _leriba_dos1,
            scheduled_datetime=NOW + timedelta(days=14), status="scheduled",
            created_by=_leriba_fk_id, notes="Maandelikse kontrole Roosmaryn.",
        )
        _get_or_create_room_check_session(
            session, spesie.room_id, _leriba_dos3,
            scheduled_datetime=NOW + timedelta(days=21), status="scheduled",
            created_by=_leriba_fk_id, notes="Maandelikse kontrole Spesie.",
        )
        _get_or_create_room_check_session(
            session, gclb.room_id, _gerhard_dos2,
            scheduled_datetime=NOW + timedelta(days=10), status="scheduled",
            created_by=_gerhard_fk_id, notes="Maandelikse kontrole CLB.",
        )

        # ═══════════════════════════════════════════════════════════════════
        # 10. KALENDER-GEBEURTENISSE (historie + skedule)
        # ═══════════════════════════════════════════════════════════════════
        _leriba_admin_id = leriba_admin.user_id
        _gerhard_admin_id = gerhard_admin.user_id

        week = lambda n: timedelta(days=7 * n)
        _get_or_create_event(session, "Maandelikse fasiliteitsvergadering (Leriba)",
            NOW - timedelta(days=30), NOW - timedelta(days=30, hours=-1),
            "Bestuurspunt-opvolg met fasiliteite-span.", "Boerneef", "#935e28",
            user_id=_leriba_admin_id)
        _get_or_create_event(session, "HVAC-kwartaalinspeksie Leriba",
            NOW - timedelta(days=120), NOW - timedelta(days=120, hours=-2),
            "Al die lugversorger-eenhede geïnspekteer.", "Boerneef + L-blok", "#2563eb",
            user_id=_leriba_admin_id)
        _get_or_create_event(session, "Brandoefening (heel kampus Leriba)",
            NOW - timedelta(days=45), NOW - timedelta(days=45, hours=-1),
            "Verpligte brandoefening vir alle personeel.", "Heel kampus", "#dc2626",
            user_id=_leriba_admin_id)
        _get_or_create_event(session, "Voorraadopname Leriba stoorkamers",
            NOW - timedelta(days=25), NOW - timedelta(days=25, hours=-4),
            "Kwartaallikse voorraadopname.", "L-blok", "#16a34a", user_id=_leriba_admin_id)
        _get_or_create_event(session, "Personeelopleiding: Brandveiligheid",
            NOW + week(2), NOW + week(2) + timedelta(hours=2),
            "Brandveiligheidsopleiding vir nuwe personeel.", "Roosmaryn, Boerneef", "#935e28",
            user_id=_leriba_admin_id)
        _get_or_create_event(session, "Jaarlikse gebou-inspeksie Leriba",
            NOW + week(6), NOW + week(6) + timedelta(hours=4),
            "Jaarlikse strukturele inspeksie Boerneef + L-blok.", "Leriba", "#16a34a",
            user_id=_leriba_admin_id)
        _get_or_create_event(session, "Lokaal-kontrole Roosmaryn (dosent-opdrag)",
            NOW + timedelta(days=14), NOW + timedelta(days=14, hours=1),
            "Geskeduleerde maandelikse kontrole deur dosent.", "CL9", "#f97316",
            user_id=_leriba_admin_id)

        _get_or_create_event(session, "Maandelikse fasiliteitsvergadering (Gerhard)",
            NOW - timedelta(days=15), NOW - timedelta(days=15, hours=-1),
            "Opvolg met die Gerhard-fasiliteite-span.", "G-blok", "#935e28",
            user_id=_gerhard_admin_id)
        _get_or_create_event(session, "HVAC-kwartaalinspeksie Gerhard",
            NOW + week(4), NOW + week(4) + timedelta(hours=2),
            "Al die lugversorger-eenhede in Gerhard geïnspekteer.", "G-blok + L-blok", "#2563eb",
            user_id=_gerhard_admin_id)
        _get_or_create_event(session, "Brandoefening (heel kampus Gerhard)",
            NOW - timedelta(days=70), NOW - timedelta(days=70, hours=-1),
            "Verpligte brandoefening vir alle personeel.", "Heel kampus", "#dc2626",
            user_id=_gerhard_admin_id)
        _get_or_create_event(session, "Jaarlikse gebou-inspeksie Gerhard",
            NOW + week(8), NOW + week(8) + timedelta(hours=3),
            "Jaarlikse strukturele inspeksie.", "Gerhard", "#16a34a",
            user_id=_gerhard_admin_id)
        _get_or_create_event(session, "Kontrakteur-evaluering (HVAC + loodgieter)",
            NOW + week(3), NOW + week(3) + timedelta(hours=2),
            "Evaluering van kontrakteurs se diens.", "ALB, G-blok", "#935e28",
            user_id=_gerhard_admin_id)

        # ═══════════════════════════════════════════════════════════════════
        # 11. OUDIT-LOGS vir bates (create op skepdatum + update-logs)
        # ═══════════════════════════════════════════════════════════════════
        all_assets = session.exec(
            select(Asset).where(Asset.asset_created_datetime >= NOW - TWO_YEARS)
        ).all()

        for asset in all_assets:
            created_dt = asset.asset_created_datetime or NOW
            _create_asset_audit_log(session, asset, action="create", timestamp=created_dt)

        # 'n Paar update-logs waar bates tussen lokale geskuif het.
        for serial, prev_room, new_room, ts in [
            ("AK CL9000009", roosmaryn.room_id, None, NOW - timedelta(days=400)),
        ]:
            asset = session.exec(select(Asset).where(Asset.asset_serial == serial)).first()
            if asset:
                _create_asset_audit_log(
                    session, asset, action="update",
                    affected_columns=["room_id"],
                    previous_value={"room_id": prev_room},
                    new_value={"room_id": new_room},
                    timestamp=ts,
                )

        # ═══════════════════════════════════════════════════════════════════
        # 12. MELDINGSVOORKEURE + WAGWOORD-MIGRASIE
        # ═══════════════════════════════════════════════════════════════════
        NOTIF_TYPES = [
            "fault.created", "fault.assigned", "fault.resolved", "fault.status_changed",
            "job.created", "job.assigned", "job.status_changed",
            "stock.low",
            "system.announcement",
            "calendar.reminder",
        ]
        all_users = session.exec(select(User).where(User.user_status == "active")).all()
        for user in all_users:
            for ntype in NOTIF_TYPES:
                existing = session.exec(
                    select(NotificationPreference).where(
                        NotificationPreference.user_id == user.user_id,
                        NotificationPreference.notification_type == ntype,
                    )
                ).first()
                if not existing:
                    session.add(NotificationPreference(
                        user_id=user.user_id,
                        notification_type=ntype,
                        in_app_enabled=True,
                        email_enabled=False,
                        push_enabled=True,
                    ))

        _migrate_plaintext_passwords(session)

        session.commit()
        print("Seed completed.")
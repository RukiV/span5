from datetime import datetime, timedelta
from typing import Optional
from sqlmodel import Session, select
from .database import engine
from ..models.location import Building, BuildingType, Location, Room, RoomType, RoomStatus
from ..models.asset import Asset, AssetStatus, Assettype
from ..models.stock import Stock
from ..models.job import Jobcard, JobStatus
from ..models.fault import Faultcard, FaultStatus, Priority, Type
from ..models.contractor import Contractor
from ..models.role import Role, Rights, RoleRight
from ..models.user import User
from ..models.audit import Auditlog
from ..models.quote import Quote
from ..models.notification import NotificationPreference

from ..models.image import ImageAsset, ImageAssetLink, ImageBlob
from ..auth.security import hash_password, is_hashed

# Built-in roles & rights catalog live in a lightweight shared module so both the
# seed and the management endpoints/services use one source of truth.
from ..auth.rights_catalog import (  # noqa: F401  (re-exported for existing importers)
    ROLE_STUDENT,
    ROLE_FK,
    ROLE_ADMIN,
    ROLE_CONTRACTOR,
    RIGHTS_CATALOG,
    ROLE_RIGHTS,
)

def generate_mock_image_bytes(color_hex: str) -> bytes:
    """Generates a tiny, valid 1x1 pixel PNG byte string of a specific color 
    so your BYTEA database fields contain authentic image data structures.
    """
    # Base64 decoded transparent pixel sequence used as an authentic fallback bytes array
    return b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'


def _get_or_create_test_user(session: Session, user_name: str, user_surname: str, user_email: str, user_password: str, role_id: int, location_id: Optional[int] = None) -> User:
    """
    Soek bestaande toetsgebruiker of skep nuwe met gegewe rol.
    
    Args:
        session: Databasis-sessie
        user_email: E-posadres vir soeken/skep
        user_password: Wagwoord vir nuwe gebruiker
        role_id: Rol-ID (1=Gebruiker, 2=FK-Koördineerder, 3=Administrateur)
        location_id: Opsionele Terrein-ID vir FK-koördineerders
        
    Returns:
        Bestaande of nuwe Gebruiker-objek
    """
    # Soek of gebruiker bestaan reeds
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

    # Skep nuwe toetsgebruiker met gegewe parameters.
    # Wagwoorde word altyd gehash gestoor (nooit platteks nie).
    user = User(
        user_name=user_name,
        user_surname=user_surname,
        user_email=user_email,
        user_password=hash_password(user_password),
        user_number="0000000000",
        user_lastlogintime=None,
        user_lastlogouttime=None,
        user_status="active",
        role_id=role_id,  # Toekenning van rol vir toesgang-beheer
        location_id=location_id,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def _get_or_create_test_quote(session: Session) -> Quote:
    """Ensure a test Quote exists for document uploads during development."""
    quote = session.exec(select(Quote)).first()
    if quote:
        return quote

    quote = Quote(
        quote_date=datetime.utcnow().date(),
        quote_status="draft",
    )
    session.add(quote)
    session.commit()
    session.refresh(quote)
    return quote

def _get_or_create_location(session: Session, name: str, location_type: str, streetnum: str, streetname: str, suburb: str = "", city: str = "", province: str = "", country: str = "") -> Location:
    location = session.exec(select(Location).where(Location.location_name == name)).first()
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
    )
    session.add(location)
    session.commit()
    session.refresh(location)
    return location


def _get_or_create_building(session: Session, name: str, building_type: BuildingType, location_id: int) -> Building:
    building = session.exec(select(Building).where(Building.building_name == name)).first()
    if building:
        return building

    building = Building(
        building_name=name,
        building_type=building_type,
        location_id=location_id,
    )
    session.add(building)
    session.commit()
    session.refresh(building)
    return building


def _get_or_create_room(session: Session, name: str, code:str, capacity: int, room_type: RoomType, room_status: RoomStatus, building_id: int) -> Room:
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


def _get_or_create_assettype(session: Session, name: str, avg: int | None = None, min_: int | None = None, max_: int | None = None, interval: int | None = None, threshold: int | None = None) -> Assettype:
    assettype = session.exec(select(Assettype).where(Assettype.assettype_name == name)).first()
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

def _get_or_create_image(session: Session, filename: str, mime_type: str, raw_data: bytes, parent_id: int, parent_type: str, display_order: int) -> ImageAsset:
    """Finds an existing image by name, or saves a new one with its isolated data blob and a parent link."""
    image = session.exec(select(ImageAsset).where(ImageAsset.filename == filename)).first()
    if image is None:
        blob_data = ImageBlob(file_bytes=raw_data)
        image = ImageAsset(
            filename=filename,
            mime_type=mime_type,
            size_bytes=len(raw_data),
            file_blob=blob_data,
        )
        session.add(image)
        session.commit()
        session.refresh(image)

    existing_link = session.exec(
        select(ImageAssetLink).where(
            ImageAssetLink.image_id == image.image_id,
            ImageAssetLink.parent_id == parent_id,
            ImageAssetLink.parent_type == parent_type,
        )
    ).first()

    if existing_link is None:
        link = ImageAssetLink(
            image_id=image.image_id,
            parent_id=parent_id,
            parent_type=parent_type,
            display_order=display_order,
        )
        session.add(link)
        session.commit()

    return image

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
    image_id: Optional[int] = None,
) -> Asset:
    asset = session.exec(select(Asset).where(Asset.asset_serial == serial)).first()
    if asset:
        if image_id and asset.image_id != image_id:
            asset.image_id = image_id
            session.add(asset)
            session.commit()
            session.refresh(asset)
        return asset

    asset = Asset(
        asset_name=name,
        asset_brand=brand,
        asset_serial=serial,
        asset_status=status,
        asset_isoutdoor=is_outdoor,
        room_id=room_id,
        assettype_id=assettype_id,
        asset_created_datetime=created_dt or datetime.utcnow(),
        image_id=image_id,
    )
    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset


def _get_or_create_stock(session: Session, name: str, brand: str, amount: int, minimum: int, boxTotal: int, stock_type: str, desc: str, room_id: int | None) -> Stock:
    stock = session.exec(select(Stock).where(Stock.stock_brand == brand, Stock.stock_type == stock_type)).first()
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


def _get_or_create_contractor(session: Session, businessName: str, name: str, surname: str, email: str, number: Optional[str], contractor_type: Optional[str]) -> Contractor:
    contractor = session.exec(select(Contractor).where(Contractor.contractor_email == email)
    ).first()
    if contractor:
        return contractor

    contractor = Contractor(
        contractor_businessName=businessName,
        contractor_name=name,
        contractor_surname=surname,
        contractor_email=email,
        contractor_number=number,
        contractor_type=contractor_type,
    )
    session.add(contractor)
    session.commit()
    session.refresh(contractor)
    return contractor


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
        select(Jobcard)
        .where(Jobcard.job_desc == desc, Jobcard.asset_id == asset_id)
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
) -> Faultcard:
    fault = session.exec(
        select(Faultcard)
        .where(Faultcard.fault_description == description, Faultcard.asset_id == asset_id)
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
    )
    session.add(fault)
    session.commit()
    session.refresh(fault)
    return fault


def _get_or_create_default_role(session: Session) -> Role:
    """Skep Standaard-gebruiker-rol (role_id=1). Kan NIE aanmeld nie."""
    role = session.exec(select(Role).where(Role.role_name == "User")).first()
    if role:
        return role

    role = Role(role_name="User")
    session.add(role)
    session.commit()
    session.refresh(role)
    return role


def _get_or_create_admin_role(session: Session) -> Role:
    """Skep Administrator-rol (role_id=3). Volle stelsel-toegang."""
    role = session.exec(select(Role).where(Role.role_name == "Administrateur")).first()
    if role:
        return role

    role = Role(role_name="Administrateur")
    session.add(role)
    session.commit()
    session.refresh(role)
    return role


def _get_or_create_fk_role(session: Session) -> Role:
    """Skep FK-Koördineerder-rol (role_id=2). Kan aanmeld, beperkte toegang."""
    role = session.exec(select(Role).where(Role.role_name == "Fasiliteit Koördineerder")).first()
    if role:
        return role

    role = Role(role_name="Fasiliteit Koördineerder")
    session.add(role)
    session.commit()
    session.refresh(role)
    return role


def _get_or_create_contractor_role(session: Session) -> Role:
    """Skep Kontrakteur-rol (role_id=4). Kan aanmeld op mobiele app."""
    role = session.exec(select(Role).where(Role.role_name == "Kontrakteur")).first()
    if role:
        return role

    role = Role(role_name="Kontrakteur")
    session.add(role)
    session.commit()
    session.refresh(role)
    return role


def _create_asset_audit_log(session: Session, asset: Asset, action: str = "create", previous_value: Optional[dict] = None, new_value: Optional[dict] = None, affected_columns: Optional[list] = None, timestamp: Optional[datetime] = None) -> None:
    """Helper function to create audit logs for assets."""
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
        actiondatetime=timestamp or datetime.utcnow(),
        user_id=None,  # Seed data has no user context
    )
    session.add(audit_log)
    session.commit()


def _get_or_create_right(session: Session, right_name: str, description: str) -> Rights:
    """Idempotent create of a single Rights row."""
    right = session.exec(select(Rights).where(Rights.right_name == right_name)).first()
    if right:
        return right

    right = Rights(right_name=right_name, right_description=description)
    session.add(right)
    session.commit()
    session.refresh(right)
    return right


def _get_or_create_role_right(session: Session, role_id: int, right_id: int) -> RoleRight:
    """Idempotent create of a single RoleRight association row."""
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


def seed_rights(session: Session) -> None:
    """Seed the Rights catalog and RoleRight assignments (idempotent).

    Both the catalog (RIGHTS_CATALOG) and the assignments (ROLE_RIGHTS) are the
    single source of truth used by the app and the tests.
    """
    name_to_id: dict[str, int] = {}
    for right_name, description in RIGHTS_CATALOG.items():
        right = _get_or_create_right(session, right_name, description)
        name_to_id[right_name] = right.right_id

    for role_id, right_names in ROLE_RIGHTS.items():
        for right_name in right_names:
            _get_or_create_role_right(session, role_id, name_to_id[right_name])


def _migrate_plaintext_passwords(session: Session) -> None:
    """One-time, idempotent migration of any legacy plaintext passwords to hashes.

    Detects already-hashed values by their hash prefix (via ``is_hashed``), so it
    is safe to run on every startup: hashed rows are skipped.
    """
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


def seed_data():
    """
    Seed-funksie - Inisialiseer databasis met toetsdata.
    Geroep wanneer toepassing begin. Skep rolle, gebruikers, lokasies, bates, ens.
    """
    print("Seed function called")
    with Session(engine) as session:
        # Skep alle rolle in KORREKTE volgorde
        # Orde is KRITIEK! Administrateur moet role_id = 3 wees vir frontend-kontrole
        # Databasis gee auto-inkrementerende IDs in skepping-volgorde
        user_role = _get_or_create_default_role(session)           # ID 1
        fk_role = _get_or_create_fk_role(session)                 # ID 2
        admin_role = _get_or_create_admin_role(session)           # ID 3
        contractor_role = _get_or_create_contractor_role(session) # ID 4

        # Seed the Rights catalog + RoleRight assignments now that roles exist.
        # This is the source of truth for authorization (see auth/permissions.py).
        seed_rights(session)

        # Skep toetsgebruikers vir elke rol
        # Gewone Gebruiker - kan NIE aanmeld nie (403-fout)
        _get_or_create_test_user(
            session,
            user_name="test",
            user_surname="user",
            user_email="test@example.com",
            user_password="password123",
            role_id=user_role.role_id,  # role_id = 1 (geweier)
        )

        # Ensure a test quote exists so uploads to /quotes/1/documents succeed in development
        test_quote = _get_or_create_test_quote(session)
        print("Seed ensured test quote_id:", getattr(test_quote, 'quote_id', None))

        # FK-Koördineerder - KAN aanmeld, geen toegang tot Users-blad, outomaties gefiltreer tot Leriba-kampus
        _get_or_create_test_user(
            session,
            user_name="fk",
            user_surname="user",
            user_email="fk@example.com",
            user_password="fk123",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
            location_id=1,  # Leriba-kampus
        )

        # Administrateur - KAN aanmeld EN vol toegang
        _get_or_create_test_user(
            session,
            user_name="admin",
            user_surname="user",
            user_email="admin@example.com",
            user_password="admin123",
            role_id=admin_role.role_id,  # role_id = 3 (toelaat)
        )

        _get_or_create_test_user(
            session,
            user_name="Piet",
            user_surname="Botha",
            user_email="piet@gmail.com",
            user_password="piet123",
            role_id=user_role.role_id,  # role_id = 1 (geweier)
        )

        # FK-Koördineerder - KAN aanmeld, geen toegang tot Users-blad, outomaties gefiltreer tot Gerhardstraat-kampus
        _get_or_create_test_user(
            session,
            user_name="Jaco",
            user_surname="Venster",
            user_email="jaco@gmail.com",
            user_password="jaco123",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
            location_id=2,  # Gerhardstraat-kampus
        )

        # Administrateur - KAN aanmeld EN vol toegang
        _get_or_create_test_user(
            session,
            user_name="Kobus",
            user_surname="Dewald",
            user_email="kobus@gmail.com",
            user_password="kobus123",
            role_id=admin_role.role_id,  # role_id = 3 (toelaat)
        )

        # Kontrakteur - KAN aanmeld op mobiele app, slegs toegang tot toegewysde werksopdragte
        _get_or_create_test_user(
            session,
            user_name="Jan",
            user_surname="Botha",
            user_email="jan.botha@workfix.co.za",
            user_password="contractor123",
            role_id=contractor_role.role_id,  # role_id = 4 (toelaat)
        )

        _get_or_create_test_user(
            session,
            user_name="Lindiwe",
            user_surname="Mokoena",
            user_email="lindiwe.mokoena@plumbright.co.za",
            user_password="contractor123",
            role_id=contractor_role.role_id,  # role_id = 4 (toelaat)
        )

        # Ekstra FK-gebruikers
        _get_or_create_test_user(
            session,
            user_name="Elektra",
            user_surname="King",
            user_email="elektra@gmail.com",
            user_password="Test@1234",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
        )

        _get_or_create_test_user(
            session,
            user_name="Guillaume",
            user_surname="Kruger",
            user_email="guillaumekruger214@gmail.com",
            user_password="Test@1234",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
        )

        # Skep toetsdata vir lokasies, kamers, bates, ens.
        loc1 = _get_or_create_location(
            session,
            name="Leriba-kampus",
            location_type="Kampus",
            streetnum="245",
            streetname="Endstraat",
suburb="Clubview",
            city="Centurion",
            province="Gauteng",
            country="Suid Afrika",
        )

        loc2 = _get_or_create_location(
            session,
            name="Gerhardstraat-kampus",
            location_type="Kampus",
            streetnum="117",
            streetname="Gerhardstraat",
suburb="Die Hoewes",
            city="Centurion",
            province="Gauteng",
            country="Suid Afrika",
        )

        loc3 = _get_or_create_location(
            session,
            name="Paarl-kampus",
            location_type="Kampus",
            streetnum="1",
            streetname="Bredastraat",
suburb="Esterville",
            city="Paarl",
            province="Wes Kaap",
            country="Suid Afrika",
        )

        loc4 = _get_or_create_location(
            session,
            name="Moot-sentrum",
            location_type="Kantoor",
            streetnum="1120",
            streetname="Hertzogstraat",
suburb="Villieria",
            city="Pretoria",
            province="Gauteng",
            country="Suid Afrika",
        )

        bld1 = _get_or_create_building(
            session,
            name="Boerneef",
            building_type=BuildingType.ADMIN,
            location_id=loc1.location_id,
        )

        bld2 = _get_or_create_building(
            session,
            name="Spys",
            building_type=BuildingType.KAFERERIA,
            location_id=loc1.location_id,
        )

        bld3 = _get_or_create_building(
            session,
            name="Blok L",
            building_type=BuildingType.EDUCATIONAL,
            location_id=loc1.location_id,
        )

        bld4 = _get_or_create_building(
            session,
            name="Kantoor 118 Blok A",
            building_type=BuildingType.EDUCATIONAL,
            location_id=loc4.location_id,
        )

        room1 = _get_or_create_room(
            session,
            name="Toilette M",
            code="T1",
            capacity=4,
            room_type=RoomType.BATHROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=bld2.building_id,
        )

        room2 = _get_or_create_room(
            session,
            name="Toilette F",
            code="T2",
            capacity=4,
            room_type=RoomType.BATHROOM,
            room_status=RoomStatus.OPERATIONAL,
            building_id=bld2.building_id,
        )

        room3 = _get_or_create_room(
            session,
            name="Lokaal langs Roosmaryn",
            code="L9",
            capacity=15,
            room_type=RoomType.CONFERENCE,
            room_status=RoomStatus.OPERATIONAL,
            building_id=bld1.building_id,
        )

        room4 = _get_or_create_room(
            session,
            name="Bitterbessie",
            code="L2",
            capacity=40,
            room_type=RoomType.OTHER,
            room_status=RoomStatus.OPERATIONAL,
            building_id=bld3.building_id,
        )

        room5 = _get_or_create_room(
            session,
            name="Stoorkamer",
            code="L10",
            capacity=0,
            room_type=RoomType.WAREHOUSE,
            room_status=RoomStatus.OPERATIONAL,
            building_id=bld1.building_id,
        )

        contractor1 = _get_or_create_contractor(
            session,
            businessName="Jan's Woodworking",
            name="Jan",
            surname="Botha",
            email="jan.botha@workfix.co.za",
            number="+27 21 555 1234",
            contractor_type="Electrical",
        )

        contractor2 = _get_or_create_contractor(
            session,
            businessName="Bethesda Plumbing",
            name="Lindy",
            surname="Bethesda",
            email="lindiwe.mokoena@plumbright.co.za",
            number="+27 11 555 6789",
            contractor_type="Plumbing",
        )

        type_elek = _get_or_create_assettype(session, "Elektriese Toerusting", avg=60, min_=36, max_=84, interval=6, threshold=3)
        type_meubels = _get_or_create_assettype(session, "Meubels", avg=120, min_=60, max_=180, interval=24, threshold=2)
        type_alge = _get_or_create_assettype(session, "Algemene Toerusting", avg=36, min_=12, max_=60, interval=12, threshold=4)

        now = datetime.utcnow()

        # 1. Define your mock image bytes
        mock_bytes = generate_mock_image_bytes("FF0000")

        # 2. Use the helper function to save the image first and extract a valid ID
        img1 = _get_or_create_image(
            session=session,
            filename="hq_projector_ceiling_mount.png",
            mime_type="image/png",
            raw_data=mock_bytes,
            parent_id=1,
            parent_type="asset",
            display_order=1,
        )

        # 3. Pass the valid image_id to your asset creator
        _get_or_create_asset(
            session=session,
            name="Handdroër",
            brand="Dyson",
            serial="AK MT000014",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room1.room_id,
            assettype_id=type_elek.assettype_id,
            created_dt=now - timedelta(days=540),
        )

        _get_or_create_asset(
            session,
            name="Handdroër",
            brand="Dyson",
            serial="AK MT000015",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room2.room_id,
            assettype_id=type_elek.assettype_id,
            created_dt=now - timedelta(days=420),
        )

        _get_or_create_asset(
            session,
            name="Projektor 4k",
            brand="Epson",
            serial="AK MT000001",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room3.room_id,
            assettype_id=type_elek.assettype_id,
            created_dt=now - timedelta(days=200),
        )

        _get_or_create_asset(
            session,
            name="Projektor 4k",
            brand="Epson",
            serial="AK MT000002",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room4.room_id,
            assettype_id=type_elek.assettype_id,
            created_dt=now - timedelta(days=90),
        )

        _get_or_create_asset(
            session,
            name="Stoel",
            brand="Dauphin",
            serial="AK MT000005",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room4.room_id,
            assettype_id=type_meubels.assettype_id,
            created_dt=now - timedelta(days=60),
        )

        _get_or_create_asset(
            session,
            name="Stoel",
            brand="Cecil Nurse",
            serial="AK MT000006",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room4.room_id,
            assettype_id=type_meubels.assettype_id,
            created_dt=now - timedelta(days=120),
        )

        _get_or_create_asset(
            session,
            name="Stoel",
            brand="Cecil Nurse",
            serial="AK MT003767",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room5.room_id,
            assettype_id=type_meubels.assettype_id,
            created_dt=now - timedelta(days=365),
        )

        _get_or_create_asset(
            session,
            name="Tafel",
            brand="Barker Street",
            serial="AK MT003701",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room5.room_id,
            assettype_id=type_meubels.assettype_id,
            created_dt=now - timedelta(days=150),
        )

        _get_or_create_asset(
            session,
            name="Stoel",
            brand="Cecil Nurse",
            serial="AK MT000012",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room5.room_id,
            assettype_id=type_meubels.assettype_id,
            created_dt=now - timedelta(days=30),
        )

        _get_or_create_stock(
            session,
            name="Gloeilampe",
            brand="Spax",
            amount=30,
            minimum=5,
            boxTotal=1,
            stock_type="Verbruiksgoedere",
            desc="T8 36W Koel Wit (Cool White) 1200mm fluoresserende ligbuis vir klaskamers.",
            room_id=room2.room_id,
        )

        _get_or_create_stock(
            session,
            name="Houtskroewe",
            brand="Eureka",
            amount=10,
            minimum=3,
            boxTotal=100,
            stock_type="Onderdele",
            desc="4.0 x 40mm sink-plaat (zinc plated) dry-wall en algemene houtskroewe.",
            room_id=room1.room_id,
        )

        projector_asset = session.exec(select(Asset).where(Asset.asset_serial == "AK MT000001")).first()
        stoel_asset = session.exec(select(Asset).where(Asset.asset_serial == "AK MT000005")).first()

        # Haal kontrakteur-gebruikers op om werksopdragte aan hulle toe te ken
        jan_user = session.exec(select(User).where(User.user_email == "jan.botha@workfix.co.za")).first()
        lindiwe_user = session.exec(select(User).where(User.user_email == "lindiwe.mokoena@plumbright.co.za")).first()
        jan_contractor_id = jan_user.user_id if jan_user else None
        lindiwe_contractor_id = lindiwe_user.user_id if lindiwe_user else None

        _get_or_create_job(
            session,
            desc="Projektor lens skoonmaak en kalibrasie.",
            status=JobStatus.COMPLETED,
            job_type="maintenance",
            created_dt=now - timedelta(days=180),
            finished_dt=now - timedelta(days=178),
            asset_id=projector_asset.asset_id if projector_asset else None,
            room_id=room3.room_id,
            building_id=bld1.building_id,
            location_id=loc1.location_id,
            contractor_id=jan_contractor_id,
        )

        _get_or_create_job(
            session,
            desc="Herstel projektor lens.",
            status=JobStatus.OPEN,
            job_type="Onderhoud",
            created_dt=now - timedelta(days=5),
            asset_id=projector_asset.asset_id if projector_asset else None,
            room_id=room3.room_id,
            building_id=bld1.building_id,
            location_id=loc1.location_id,
            contractor_id=jan_contractor_id,
        )

        _get_or_create_job(
            session,
            desc="Vervang stoel.",
            status=JobStatus.IN_PROGRESS,
            job_type="Inspeksie",
            created_dt=datetime.now(),
            asset_id=stoel_asset.asset_id if stoel_asset else None,
            room_id=room4.room_id,
            building_id=bld3.building_id,
            location_id=loc1.location_id,
            contractor_id=lindiwe_contractor_id,
        )

        _get_or_create_fault(
            session,
            description="Stoel het 'n gebreukte poot.",
            status=FaultStatus.IN_PROGRESS,
            priority=Priority.LOW,
            fault_type=Type.REPAIR,
            report_dt=now - timedelta(days=10),
            asset_id=stoel_asset.asset_id if stoel_asset else None,
            room_id=room4.room_id,
            building_id=bld3.building_id,
            location_id=loc1.location_id,
        )

        _get_or_create_fault(
            session,
            description="Projektor lens is gekraak",
            status=FaultStatus.WAIT,
            priority=Priority.MEDIUM,
            fault_type=Type.REPAIR,
            report_dt=now - timedelta(days=45),
            asset_id=projector_asset.asset_id if projector_asset else None,
        )

        _get_or_create_fault(
            session,
            description="Projektor oorverhit na lang gebruik",
            status=FaultStatus.CLOSED,
            priority=Priority.HIGH,
            fault_type=Type.REPAIR,
            report_dt=now - timedelta(days=120),
            asset_id=projector_asset.asset_id if projector_asset else None,
        )

        _get_or_create_fault(
            session,
            description="Projektor skakel nie aan nie",
            status=FaultStatus.RESOLVED,
            priority=Priority.HIGH,
            fault_type=Type.REPAIR,
            report_dt=now - timedelta(days=200),
            asset_id=projector_asset.asset_id if projector_asset else None,
            room_id=room3.room_id,
            building_id=bld1.building_id,
            location_id=loc1.location_id,
        )

        # ═══════════════════════════════════════════════════════════════
        # Uitgebreide realisitiese toetsdata vir analitiese insigte
        # ═══════════════════════════════════════════════════════════════

        # ── Addisionele asset tipes ──────────────────────────────
        type_it = _get_or_create_assettype(session, "IT Toerusting", avg=48, min_=24, max_=72, interval=12, threshold=3)
        type_hvac = _get_or_create_assettype(session, "HVAC Toerusting", avg=84, min_=60, max_=120, interval=6, threshold=2)
        type_veiligheid = _get_or_create_assettype(session, "Veiligheidstoerusting", avg=36, min_=12, max_=60, interval=3, threshold=4)
        type_kombuis = _get_or_create_assettype(session, "Kombuistoerusting", avg=72, min_=36, max_=120, interval=12, threshold=2)

        # ── Addisionele geboue ──────────────────────────────────
        bld5 = _get_or_create_building(session, "Wetenskapblok", BuildingType.LABORATORY, loc1.location_id)
        bld6 = _get_or_create_building(session, "Biblioteek", BuildingType.OTHER, loc1.location_id)
        bld7 = _get_or_create_building(session, "Sportkompleks", BuildingType.OTHER, loc2.location_id)
        bld8 = _get_or_create_building(session, "Residensie A", BuildingType.OTHER, loc2.location_id)
        bld9 = _get_or_create_building(session, "Adminblok", BuildingType.ADMIN, loc3.location_id)
        bld10 = _get_or_create_building(session, "Laboratorium", BuildingType.LABORATORY, loc3.location_id)

        # ── Addisionele lokale ──────────────────────────────────
        room6 = _get_or_create_room(session, "Lab 1", "L11", 24, RoomType.LABORATORY, RoomStatus.OPERATIONAL, bld5.building_id)
        room7 = _get_or_create_room(session, "Lab 2", "L12", 20, RoomType.LABORATORY, RoomStatus.OPERATIONAL, bld5.building_id)
        room8 = _get_or_create_room(session, "Lesinglokaal A", "L13", 80, RoomType.CLASSROOM, RoomStatus.OPERATIONAL, bld3.building_id)
        room9 = _get_or_create_room(session, "Lesinglokaal B", "L14", 60, RoomType.CLASSROOM, RoomStatus.OPERATIONAL, bld3.building_id)
        room10 = _get_or_create_room(session, "Leesarea", "L15", 30, RoomType.OTHER, RoomStatus.OPERATIONAL, bld6.building_id)
        room11 = _get_or_create_room(session, "IT-sentrum", "L16", 40, RoomType.LABORATORY, RoomStatus.OPERATIONAL, bld6.building_id)
        room12 = _get_or_create_room(session, "Gimnasium", "L17", 50, RoomType.OTHER, RoomStatus.OPERATIONAL, bld7.building_id)
        room13 = _get_or_create_room(session, "Kleedkamer M", "L18", 10, RoomType.BATHROOM, RoomStatus.OPERATIONAL, bld7.building_id)
        room14 = _get_or_create_room(session, "Kleedkamer F", "L19", 10, RoomType.BATHROOM, RoomStatus.OPERATIONAL, bld7.building_id)
        room15 = _get_or_create_room(session, "Kantoor 1", "K1", 2, RoomType.OFFICE, RoomStatus.OPERATIONAL, bld9.building_id)
        room16 = _get_or_create_room(session, "Kantoor 2", "K2", 1, RoomType.OFFICE, RoomStatus.OPERATIONAL, bld9.building_id)
        room17 = _get_or_create_room(session, "Kantoor 3", "K3", 4, RoomType.OFFICE, RoomStatus.OPERATIONAL, bld9.building_id)
        room18 = _get_or_create_room(session, "Residensie Kamer 1", "RK1", 2, RoomType.OTHER, RoomStatus.OPERATIONAL, bld8.building_id)
        room19 = _get_or_create_room(session, "Residensie Kamer 2", "RK2", 2, RoomType.OTHER, RoomStatus.OPERATIONAL, bld8.building_id)
        room20 = _get_or_create_room(session, "Residensie Kamer 3", "RK3", 2, RoomType.OTHER, RoomStatus.OPERATIONAL, bld8.building_id)
        room21 = _get_or_create_room(session, "Kombuis", "K4", 10, RoomType.OTHER, RoomStatus.OPERATIONAL, bld2.building_id)
        room22 = _get_or_create_room(session, "Bedieningsarea", "K5", 5, RoomType.OTHER, RoomStatus.OPERATIONAL, bld2.building_id)

        # ── Addisionele bates (verskillende statusse) ──────────
        _get_or_create_asset(session, "Rekenaar HP EliteDesk", "HP", "IT-001", AssetStatus.ACTIVE, False, room11.room_id, type_it.assettype_id, now - timedelta(days=400))
        _get_or_create_asset(session, "Rekenaar HP EliteDesk", "HP", "IT-002", AssetStatus.ACTIVE, False, room11.room_id, type_it.assettype_id, now - timedelta(days=380))
        _get_or_create_asset(session, "Rekenaar Dell Optiplex", "Dell", "IT-003", AssetStatus.ACTIVE, False, room8.room_id, type_it.assettype_id, now - timedelta(days=180))
        _get_or_create_asset(session, "Rekenaar Dell Optiplex", "Dell", "IT-004", AssetStatus.MAINTENANCE, False, room8.room_id, type_it.assettype_id, now - timedelta(days=200))
        _get_or_create_asset(session, "Rekenaar Dell Optiplex", "Dell", "IT-005", AssetStatus.ACTIVE, False, room9.room_id, type_it.assettype_id, now - timedelta(days=90))
        _get_or_create_asset(session, "Rekenaar Dell Optiplex", "Dell", "IT-006", AssetStatus.INACTIVE, False, room15.room_id, type_it.assettype_id, now - timedelta(days=700))
        _get_or_create_asset(session, "Drukker LaserJet", "HP", "IT-010", AssetStatus.ACTIVE, False, room11.room_id, type_it.assettype_id, now - timedelta(days=300))
        _get_or_create_asset(session, "Drukker LaserJet", "HP", "IT-011", AssetStatus.MAINTENANCE, False, room15.room_id, type_it.assettype_id, now - timedelta(days=500))
        _get_or_create_asset(session, "Naskoot", "Canon", "IT-012", AssetStatus.ACTIVE, False, room15.room_id, type_it.assettype_id, now - timedelta(days=100))

        # ── Survival-geskiedenis: ryk fout-/werk-histories vir die oorlewings-
        #    model (meer bates + meer geleenthede = sterker opleidingssein).
        #    Alles idempotent via die _get_or_create_*-helpers.
        _survival_rows = [
            # (naam, merk, reeks, status, kamer, tipe, ouderdom_dae)
            ("Kantoor stoel", "Boss", "MB-201", AssetStatus.ACTIVE, room15, type_meubels, 900),
            ("Kantoor stoel", "Boss", "MB-202", AssetStatus.ACTIVE, room16, type_meubels, 850),
            ("Kantoor stoel", "Xpert", "MB-203", AssetStatus.MAINTENANCE, room17, type_meubels, 1100),
            ("Kantoor tafel", "Boss", "MB-204", AssetStatus.ACTIVE, room15, type_meubels, 1500),
            ("Projektor Epson", "Epson", "PR-301", AssetStatus.ACTIVE, room8, type_it, 700),
            ("Projektor Epson", "Epson", "PR-302", AssetStatus.MAINTENANCE, room9, type_it, 950),
            ("Drukker LaserJet", "HP", "PR-303", AssetStatus.ACTIVE, room11, type_it, 600),
            ("Rekenaar Dell Optiplex", "Dell", "IT-310", AssetStatus.ACTIVE, room11, type_it, 1200),
            ("Lugversorging split", "Samsung", "HV-401", AssetStatus.ACTIVE, room8, type_hvac, 1600),
            ("Lugversorging split", "Samsung", "HV-402", AssetStatus.ACTIVE, room21, type_hvac, 1300),
            ("Lugversorging split", " Alliance", "HV-403", AssetStatus.INACTIVE, room12, type_hvac, 2000),
            ("Skoonmaak kar", "Karcher", "KG-501", AssetStatus.ACTIVE, room22, type_alge, 500),
            ("Stofsuig industrieel", "Karcher", "KG-502", AssetStatus.MAINTENANCE, room22, type_alge, 750),
            ("Grasmaaier", "Ryobi", "KG-503", AssetStatus.ACTIVE, room10, type_alge, 400),
            ("Nooduitgang bord", "SafeSys", "VS-601", AssetStatus.ACTIVE, room6, type_veiligheid, 800),
            ("Brandblusser", "SafeSys", "VS-602", AssetStatus.ACTIVE, room7, type_veiligheid, 650),
            ("Alarm paneel", "SafeSys", "VS-603", AssetStatus.ACTIVE, room13, type_veiligheid, 1400),
            ("Yskas kombuis", "Defy", "KB-701", AssetStatus.ACTIVE, room21, type_kombuis, 1250),
            ("Water verwarmer", "Kwikot", "KB-702", AssetStatus.MAINTENANCE, room18, type_kombuis, 1700),
            ("Microgolf", "Sunbeam", "KB-703", AssetStatus.ACTIVE, room22, type_kombuis, 550),
            ("Elektriese paneel", "ACDC", "EL-801", AssetStatus.ACTIVE, room14, type_elek, 1800),
            ("Generator", "Honda", "EL-802", AssetStatus.ACTIVE, room10, type_elek, 1000),
            ("Beligting buite", "Radiant", "EL-803", AssetStatus.ACTIVE, room19, type_elek, 1450),
            ("Krag punt multi", "Ellies", "EL-804", AssetStatus.INACTIVE, room20, type_elek, 1900),
        ]
        _fault_kinds = [
            # (beskrywing-agtervoegsel, FaultStatus, Priority, Type)
            ("werk nie na krag uitval nie", FaultStatus.CLOSED, Priority.HIGH, Type.REPAIR),
            ("vertoon intermitterende foute", FaultStatus.RESOLVED, Priority.MEDIUM, Type.REPAIR),
            ("benodig roetine-diens", FaultStatus.CLOSED, Priority.LOW, Type.MAINTENANCE),
        ]
        for idx, (s_name, s_brand, s_serial, s_status, s_room, s_type, s_age) in enumerate(_survival_rows):
            s_created = now - timedelta(days=s_age)
            asset_s = _get_or_create_asset(
                session, s_name.strip(), s_brand.strip(), s_serial, s_status,
                False, getattr(s_room, "room_id", None), s_type.assettype_id, s_created,
            )
            building_s = None
            if getattr(s_room, "room_id", None):
                room_obj = session.get(Room, s_room.room_id)
                building_s = room_obj.building_id if room_obj else None
            # Twee historigiese foute (vroeë + middel-leeftyd) en een werk elk;
            # die laaste kwart van die bates kry 'n oop fout sonder werk
            # (gesensureerde waarnemings vir die model).
            for fi, (f_suffix, f_status, f_prio, f_type) in enumerate(_fault_kinds[:2 if idx % 4 == 3 else 3]):
                f_days = max(5, int(s_age * (0.25 if fi == 0 else 0.55)))
                _get_or_create_fault(
                    session,
                    description=f"{s_name.strip()} {f_suffix}",
                    status=f_status,
                    priority=f_prio,
                    fault_type=f_type,
                    report_dt=now - timedelta(days=f_days),
                    asset_id=asset_s.asset_id,
                    room_id=getattr(s_room, "room_id", None),
                )
                _get_or_create_job(
                    session,
                    desc=f"{s_name.strip()}: hanteer '{f_suffix}'",
                    status=JobStatus.COMPLETED,
                    job_type="REPAIR" if f_type == Type.REPAIR else "MAINTENANCE",
                    created_dt=now - timedelta(days=max(4, f_days - 1)),
                    finished_dt=now - timedelta(days=max(2, f_days - 3)),
                    asset_id=asset_s.asset_id,
                    room_id=getattr(s_room, "room_id", None),
                    building_id=building_s,
                )
            if idx % 4 == 3:
                _get_or_create_fault(
                    session,
                    description=f"{s_name.strip()} toon nuwe tekens van slyt",
                    status=FaultStatus.WAIT,
                    priority=Priority.MEDIUM,
                    fault_type=Type.REPAIR,
                    report_dt=now - timedelta(days=6),
                    asset_id=asset_s.asset_id,
                    room_id=getattr(s_room, "room_id", None),
                )
        _get_or_create_asset(session, "Wifi-roeterg", "MikroTik", "IT-020", AssetStatus.ACTIVE, False, room6.room_id, type_it.assettype_id, now - timedelta(days=250))
        _get_or_create_asset(session, "Wifi-roeterg AP", "Ubiquiti", "IT-021", AssetStatus.ACTIVE, False, room8.room_id, type_it.assettype_id, now - timedelta(days=150))
        _get_or_create_asset(session, "Lugversorger", "Samsung", "HVAC-001", AssetStatus.ACTIVE, True, room8.room_id, type_hvac.assettype_id, now - timedelta(days=800))
        _get_or_create_asset(session, "Lugversorger", "LG", "HVAC-002", AssetStatus.ACTIVE, True, room9.room_id, type_hvac.assettype_id, now - timedelta(days=600))
        _get_or_create_asset(session, "Lugversorger", "LG", "HVAC-003", AssetStatus.MAINTENANCE, True, room11.room_id, type_hvac.assettype_id, now - timedelta(days=900))
        _get_or_create_asset(session, "Lugversorger", "Daikin", "HVAC-004", AssetStatus.ACTIVE, True, room6.room_id, type_hvac.assettype_id, now - timedelta(days=400))
        _get_or_create_asset(session, "Verwarmer", "Dyson", "HVAC-010", AssetStatus.ACTIVE, False, room15.room_id, type_hvac.assettype_id, now - timedelta(days=200))
        _get_or_create_asset(session, "Plafonwaaier", "Fanco", "HVAC-020", AssetStatus.ACTIVE, False, room8.room_id, type_hvac.assettype_id, now - timedelta(days=365))
        _get_or_create_asset(session, "Plafonwaaier", "Fanco", "HVAC-021", AssetStatus.DECOMMISSIONED, False, room9.room_id, type_hvac.assettype_id, now - timedelta(days=1000))
        _get_or_create_asset(session, "Brandblusser", "Ace", "VEILIG-001", AssetStatus.ACTIVE, False, room3.room_id, type_veiligheid.assettype_id, now - timedelta(days=200))
        _get_or_create_asset(session, "Brandblusser", "Ace", "VEILIG-002", AssetStatus.ACTIVE, False, room8.room_id, type_veiligheid.assettype_id, now - timedelta(days=180))
        _get_or_create_asset(session, "Brandblusser", "Ace", "VEILIG-003", AssetStatus.MAINTENANCE, False, room11.room_id, type_veiligheid.assettype_id, now - timedelta(days=300))
        _get_or_create_asset(session, "Brandblusser", "Ace", "VEILIG-004", AssetStatus.ACTIVE, False, room21.room_id, type_veiligheid.assettype_id, now - timedelta(days=90))
        _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "VEILIG-010", AssetStatus.ACTIVE, False, room3.room_id, type_veiligheid.assettype_id, now - timedelta(days=150))
        _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "VEILIG-011", AssetStatus.ACTIVE, False, room8.room_id, type_veiligheid.assettype_id, now - timedelta(days=150))
        _get_or_create_asset(session, "Nooduitgang-bord", "Eaton", "VEILIG-012", AssetStatus.INACTIVE, False, room9.room_id, type_veiligheid.assettype_id, now - timedelta(days=600))
        _get_or_create_asset(session, "Yskas", "Defy", "KOM-001", AssetStatus.ACTIVE, False, room21.room_id, type_kombuis.assettype_id, now - timedelta(days=500))
        _get_or_create_asset(session, "Mikrogolf", "Samsung", "KOM-002", AssetStatus.ACTIVE, False, room21.room_id, type_kombuis.assettype_id, now - timedelta(days=300))
        _get_or_create_asset(session, "Waterketel", "Russell Hobbs", "KOM-003", AssetStatus.ACTIVE, False, room21.room_id, type_kombuis.assettype_id, now - timedelta(days=100))
        _get_or_create_asset(session, "Koffiemasjien", "Nespresso", "KOM-004", AssetStatus.MAINTENANCE, False, room22.room_id, type_kombuis.assettype_id, now - timedelta(days=250))

        # ── Addisionele voorraad ────────────────────────────────
        _get_or_create_stock(session, "T8 Fluorescerende buis 1200mm", "Osram", 25, 10, 30, "Verbruiksgoedere", "T8 1200mm 36W koelwit fluoresserende buis.", room2.room_id)
        _get_or_create_stock(session, "T8 Fluorescerende buis 600mm", "Osram", 15, 5, 20, "Verbruiksgoedere", "T8 600mm 18W fluoresserende buis.", room2.room_id)
        _get_or_create_stock(session, "LED-paneellig 600x600", "Philips", 8, 2, 10, "Verbruiksgoedere", "LED inbou-paneel 40W 600x600mm koelwit.", room2.room_id)
        _get_or_create_stock(session, "Stopcontact dubbel", "Crabtree", 12, 5, 20, "Onderdele", "Dubbelstopcontact 16A met aarding wit.", room1.room_id)
        _get_or_create_stock(session, "Muur-schakelaar enkel", "Crabtree", 20, 10, 50, "Onderdele", "Ligschakelaar enkelpool 10A wit.", room1.room_id)
        _get_or_create_stock(session, "Draad 1.5mm²", "Apex", 2, 1, 5, "Onderdele", "Elektriese draad 1.5mm² rooi (rol = 100m).", room1.room_id)
        _get_or_create_stock(session, "Draad 2.5mm²", "Apex", 1, 1, 3, "Onderdele", "Elektriese draad 2.5mm² swart (rol = 100m).", room1.room_id)
        _get_or_create_stock(session, "Handseep vulling", "Diversey", 4, 2, 6, "Verbruiksgoedere", "Vloeibare handseep 5l napvulling vir dispenser.", room2.room_id)
        _get_or_create_stock(session, "Handdoekrol", "Kimberly Clark", 6, 3, 10, "Verbruiksgoedere", "Bruin handdoekrol 2-laag 200m.", room2.room_id)
        _get_or_create_stock(session, "Vullissakke 100L", "Glad", 50, 10, 100, "Verbruiksgoedere", "Swart vullissakke 100L sterkte vir buite-dromme.", room2.room_id)
        _get_or_create_stock(session, "Vullissakke 25L", "Glad", 80, 20, 200, "Verbruiksgoedere", "Swart vullissakke 25L vir binnekorwe.", room2.room_id)
        _get_or_create_stock(session, "Sement 50kg", "PPC", 5, 2, 10, "Onderdele", "Gewone Portland sement 50kg sak vir herstelwerk.", room5.room_id)
        _get_or_create_stock(session, "Verf wit 20L", "Dulux", 3, 1, 5, "Verbruiksgoedere", "Wit muurverf 20L emmersie, waterbasis.", room5.room_id)
        _get_or_create_stock(session, "Lugversorger filter", "LG", 4, 2, 8, "Onderdele", "LG lugversorger filter pas HVAC-002/003.", room5.room_id)
        _get_or_create_stock(session, "Linte", "3M", 10, 5, 20, "Verbruiksgoedere", "Skilderslint 48mm x 50m.", room5.room_id)

        # ── Addisionele kontrakteurs ────────────────────────────
        _get_or_create_contractor(session, "CoolAir HVAC", "Thabo", "Mokoena", "thabo@coolair.co.za", "+27 82 555 2233", "HVAC")
        _get_or_create_contractor(session, "SafeSys Fire", "Mpho", "Nkosi", "mpho@safesys.co.za", "+27 72 555 4455", "Fire Safety")
        _get_or_create_contractor(session, "IT Solutions", "David", "Smith", "david@itsolutions.co.za", "+27 11 555 6677", "IT")
        _get_or_create_contractor(session, "Kombuis Werke", "Susan", "Venter", "susan@kombuiswerke.co.za", "+27 81 555 8899", "Kitchen Equipment")

        # Skep User-rekeninge vir nuwe kontrakteurs (jobcard FK verwys na user.user_id)
        _get_or_create_test_user(session, "Thabo", "Mokoena", "thabo@coolair.co.za", "contractor123", contractor_role.role_id)
        _get_or_create_test_user(session, "Mpho", "Nkosi", "mpho@safesys.co.za", "contractor123", contractor_role.role_id)
        _get_or_create_test_user(session, "David", "Smith", "david@itsolutions.co.za", "contractor123", contractor_role.role_id)
        _get_or_create_test_user(session, "Susan", "Venter", "susan@kombuiswerke.co.za", "contractor123", contractor_role.role_id)

        # Haal kontrakteurs op via User-rekeninge (FK in jobcard verwys na user.user_id)
        thabo_user = session.exec(select(User).where(User.user_email == "thabo@coolair.co.za")).first()
        mpho_user = session.exec(select(User).where(User.user_email == "mpho@safesys.co.za")).first()
        david_user = session.exec(select(User).where(User.user_email == "david@itsolutions.co.za")).first()
        susan_user = session.exec(select(User).where(User.user_email == "susan@kombuiswerke.co.za")).first()

        # Haal nuwe bates op vir werksopdragte/foute
        ac_unit = session.exec(select(Asset).where(Asset.asset_serial == "HVAC-003")).first()
        pc_dead = session.exec(select(Asset).where(Asset.asset_serial == "IT-004")).first()
        printer_dead = session.exec(select(Asset).where(Asset.asset_serial == "IT-011")).first()
        coffee_machine = session.exec(select(Asset).where(Asset.asset_serial == "KOM-004")).first()
        fire_extinguisher = session.exec(select(Asset).where(Asset.asset_serial == "VEILIG-003")).first()
        dell_optiplex_005 = session.exec(select(Asset).where(Asset.asset_serial == "IT-005")).first()

        # ── Addisionele foutkaartjies ───────────────────────────
        _get_or_create_fault(session, "Lugversorger blaas warm lug", FaultStatus.OPEN, Priority.HIGH, Type.REPAIR,
            now - timedelta(days=2), ac_unit.asset_id if ac_unit else None, room11.room_id, bld6.building_id, loc1.location_id)
        _get_or_create_fault(session, "Rekenaar vries voortdurend", FaultStatus.OPEN, Priority.MEDIUM, Type.MAINTENANCE,
            now - timedelta(days=5), pc_dead.asset_id if pc_dead else None, room8.room_id, bld3.building_id, loc1.location_id)
        _get_or_create_fault(session, "Drukker papierstoor", FaultStatus.IN_PROGRESS, Priority.LOW, Type.MAINTENANCE,
            now - timedelta(days=8), printer_dead.asset_id if printer_dead else None, room15.room_id, bld9.building_id, loc3.location_id)
        _get_or_create_fault(session, "Koffiemasjien lek water", FaultStatus.OPEN, Priority.LOW, Type.REPAIR,
            now - timedelta(days=1), coffee_machine.asset_id if coffee_machine else None, room22.room_id, bld2.building_id, loc1.location_id)
        _get_or_create_fault(session, "Brandblusser druk laag", FaultStatus.OPEN, Priority.HIGH, Type.MAINTENANCE,
            now - timedelta(days=3), fire_extinguisher.asset_id if fire_extinguisher else None, room11.room_id, bld6.building_id, loc1.location_id)
        _get_or_create_fault(session, "Kraan lek in kombuis", FaultStatus.OPEN, Priority.MEDIUM, Type.REPAIR,
            now - timedelta(days=10), None, room21.room_id, bld2.building_id, loc1.location_id)
        _get_or_create_fault(session, "Toilet oorloop", FaultStatus.OPEN, Priority.HIGH, Type.REPAIR,
            now - timedelta(days=1), None, room1.room_id, bld2.building_id, loc1.location_id)
        _get_or_create_fault(session, "Toilet spoel stukkend", FaultStatus.IN_PROGRESS, Priority.MEDIUM, Type.REPAIR,
            now - timedelta(days=4), None, room2.room_id, bld2.building_id, loc1.location_id)
        _get_or_create_fault(session, "Projektor flikker", FaultStatus.CONFIRMED, Priority.MEDIUM, Type.REPAIR,
            now - timedelta(days=7), projector_asset.asset_id if projector_asset else None, room3.room_id, bld1.building_id, loc1.location_id)
        _get_or_create_fault(session, "Werkstation maak geraas", FaultStatus.RESOLVED, Priority.LOW, Type.MAINTENANCE,
            now - timedelta(days=30), dell_optiplex_005.asset_id if dell_optiplex_005 else None, room9.room_id, bld3.building_id, loc1.location_id)
        _get_or_create_fault(session, "Noodligte werk nie", FaultStatus.CLOSED, Priority.MEDIUM, Type.REPAIR,
            now - timedelta(days=60), None, room6.room_id, bld5.building_id, loc1.location_id)
        _get_or_create_fault(session, "Wifi onstabiel op 2de vloer", FaultStatus.OPEN, Priority.MEDIUM, Type.MAINTENANCE,
            now - timedelta(days=3), None, room8.room_id, bld3.building_id, loc1.location_id)
        _get_or_create_fault(session, "Kantoorligte flikker", FaultStatus.IN_PROGRESS, Priority.LOW, Type.REPAIR,
            now - timedelta(days=12), None, room15.room_id, bld9.building_id, loc3.location_id)
        _get_or_create_fault(session, "Kelder oorstroming", FaultStatus.CLOSED, Priority.HIGH, Type.REPAIR,
            now - timedelta(days=90), None, room5.room_id, bld1.building_id, loc1.location_id)

        # ── Addisionele werksopdragte ───────────────────────────
        cpu_asset_003 = session.exec(select(Asset).where(Asset.asset_serial == "IT-003")).first()
        scanner_asset = session.exec(select(Asset).where(Asset.asset_serial == "IT-012")).first()
        fan_asset = session.exec(select(Asset).where(Asset.asset_serial == "HVAC-020")).first()
        fridge_asset = session.exec(select(Asset).where(Asset.asset_serial == "KOM-001")).first()

        _thabo_id = thabo_user.user_id if thabo_user else None
        _mpho_id = mpho_user.user_id if mpho_user else None
        _david_id = david_user.user_id if david_user else None
        _susan_id = susan_user.user_id if susan_user else None

        _get_or_create_job(session, "Lugversorger HVAC-003 herstel", JobStatus.IN_PROGRESS, "Onderhoud",
            created_dt=now - timedelta(days=2),
            asset_id=ac_unit.asset_id if ac_unit else None,
            room_id=room11.room_id, building_id=bld6.building_id, location_id=loc1.location_id,
            contractor_id=_thabo_id)
        _get_or_create_job(session, "Rekenaar IT-006 buite diens stel", JobStatus.COMPLETED, "Afskrywing",
            created_dt=now - timedelta(days=10),
            room_id=room15.room_id, building_id=bld9.building_id, location_id=loc3.location_id,
            finished_dt=now - timedelta(days=8))
        _get_or_create_job(session, "Brandblusser VEILIG-003 diens", JobStatus.OPEN, "Onderhoud",
            created_dt=now - timedelta(days=3),
            asset_id=fire_extinguisher.asset_id if fire_extinguisher else None,
            room_id=room11.room_id, building_id=bld6.building_id, location_id=loc1.location_id,
            contractor_id=_mpho_id)
        _get_or_create_job(session, "Kombuiskraan vervang", JobStatus.OPEN, "Herstelwerk",
            created_dt=now - timedelta(days=10),
            room_id=room21.room_id, building_id=bld2.building_id, location_id=loc1.location_id,
            contractor_id=lindiwe_contractor_id)
        _get_or_create_job(session, "Drukker IT-011 herstel", JobStatus.CANCELLED, "Herstelwerk",
            created_dt=now - timedelta(days=20),
            asset_id=printer_dead.asset_id if printer_dead else None,
            room_id=room15.room_id, building_id=bld9.building_id, location_id=loc3.location_id)
        _get_or_create_job(session, "Kantoornetwerk opgradering", JobStatus.COMPLETED, "Opgradering",
            created_dt=now - timedelta(days=45),
            room_id=room15.room_id, building_id=bld9.building_id, location_id=loc3.location_id,
            finished_dt=now - timedelta(days=40), contractor_id=_david_id)
        _get_or_create_job(session, "Plafonwaaier HVAC-020 installeer", JobStatus.COMPLETED, "Installasie",
            created_dt=now - timedelta(days=365),
            asset_id=fan_asset.asset_id if fan_asset else None,
            room_id=room8.room_id, building_id=bld3.building_id, location_id=loc1.location_id,
            finished_dt=now - timedelta(days=362))
        _get_or_create_job(session, "Stoel AK MT003767 opknap", JobStatus.OPEN, "Onderhoud",
            created_dt=now - timedelta(days=5),
            room_id=room5.room_id, building_id=bld1.building_id, location_id=loc1.location_id)
        _get_or_create_job(session, "Lesinglokaal B - nuwe witbord installeer", JobStatus.COMPLETED, "Installasie",
            created_dt=now - timedelta(days=14),
            room_id=room9.room_id, building_id=bld3.building_id, location_id=loc1.location_id,
            finished_dt=now - timedelta(days=12))
        _get_or_create_job(session, "Yskas KOM-001 diens", JobStatus.COMPLETED, "Onderhoud",
            created_dt=now - timedelta(days=60),
            asset_id=fridge_asset.asset_id if fridge_asset else None,
            room_id=room21.room_id, building_id=bld2.building_id, location_id=loc1.location_id,
            finished_dt=now - timedelta(days=58), contractor_id=_susan_id)

        # ── Kalender gebeurtenisse ──────────────────────────────
        from ..models.calendar_event import CalendarEvent

        def _get_or_create_event(session, title, start_dt, end_dt=None, desc="", location="", color=None):
            ev = session.exec(select(CalendarEvent).where(CalendarEvent.title == title, CalendarEvent.start_datetime == start_dt)).first()
            if ev:
                return ev
            ev = CalendarEvent(
                title=title,
                description=desc,
                start_datetime=start_dt,
                end_datetime=end_dt or start_dt + timedelta(hours=1),
                all_day=False,
                location=location,
                color=color,
                user_id=3,
            )
            session.add(ev)
            session.commit()
            session.refresh(ev)
            return ev

        # Admin-gebruiker (ID 3) se kalender
        base_today = now.replace(hour=8, minute=0, second=0, microsecond=0)

        _get_or_create_event(session, "Fasiliteitsbestuur vergadering", base_today + timedelta(hours=1),
            base_today + timedelta(hours=2), "Maandelikse opvolg vergadering met fasiliteite span.", "Kantoor 1 - Adminblok", "#935e28")
        _get_or_create_event(session, "HVAC inspeksie - Wetenskapblok", base_today + timedelta(days=1, hours=9),
            base_today + timedelta(days=1, hours=11), "Kwartaallikse HVAC inspeksie van alle eenhede.", "Wetenskapblok", "#2563eb")
        _get_or_create_event(session, "Brandoefening", base_today + timedelta(days=3, hours=10),
            base_today + timedelta(days=3, hours=10, minutes=30), "Verpligte brandoefening vir alle personeel.", "Heel kampus", "#dc2626")
        _get_or_create_event(session, "Kontrakteur evaluering", base_today + timedelta(days=5, hours=14),
            base_today + timedelta(days=5, hours=16), "Evaluering van HVAC en loodgieter kontrakteurs.", "Kantoor 1", "#935e28")
        _get_or_create_event(session, "Voorraadopname", base_today + timedelta(days=7, hours=8),
            base_today + timedelta(days=7, hours=12), "Kwartaallikse voorraadopname van alle stoorkamers.", "Stoorkamer L10", "#16a34a")
        _get_or_create_event(session, "IT-netwerk instandhouding", base_today + timedelta(days=10, hours=18),
            base_today + timedelta(days=10, hours=22), "Geskeduleerde netwerk instandhouding - stelsels sal ontoeganklik wees.", "IT-sentrum", "#2563eb")
        _get_or_create_event(session, "Kafeteria toerusting diens", base_today + timedelta(days=14, hours=9),
            base_today + timedelta(days=14, hours=13), "Jaarlikse diens van kombuistoerusting.", "Spys Kafeteria", "#dc2626")
        _get_or_create_event(session, "Personeel opleiding: Brandveiligheid", base_today + timedelta(days=21, hours=9),
            base_today + timedelta(days=21, hours=11), "Brandveiligheidsopleiding vir nuwe personeel.", "Lesinglokaal A", "#935e28")

        # Add more events with varied dates
        _get_or_create_event(session, "Gebouinspeksie - Residensie A", base_today + timedelta(days=30, hours=8),
            base_today + timedelta(days=30, hours=12), "Jaarlikse gebou inspeksie.", "Residensie A, Gerhardstraat", "#16a34a")
        _get_or_create_event(session, "Fakulteitsraad vergadering", base_today + timedelta(days=60, hours=14),
            base_today + timedelta(days=60, hours=16), "Kwartaallikse fakulteitsraad.", "Konferensiekamer Boerneef", "#935e28")
        _get_or_create_event(session, "Sportdag voorbereiding", base_today + timedelta(days=90, hours=7),
            base_today + timedelta(days=90, hours=17), "Opstel van toerusting vir jaarlikse sportdag.", "Sportkompleks", "#16a34a")

        # ── Addisionele kwotasies ──────────────────────────────
        _get_or_create_test_quote(session)

        # ── Ekstra gebruikers vir data-rykheid ──────────────────
        _get_or_create_test_user(session, "Sandra", "Prinsloo", "sandra@example.com", "sandra123", admin_role.role_id)
        _get_or_create_test_user(session, "Bongani", "Zuma", "bongani@example.com", "bongani123", fk_role.role_id, location_id=loc3.location_id)
        _get_or_create_test_user(session, "Chantelle", "van der Merwe", "chantelle@example.com", "chantelle123", user_role.role_id)
        _get_or_create_test_user(session, "Johan", "Venter", "johan@venter.co.za", "johan123", fk_role.role_id, location_id=loc2.location_id)

        # Create audit logs for all assets
        print("Creating audit logs for assets...")
        all_assets = session.exec(select(Asset)).all()
        base_time = datetime(2025, 1, 1, 8, 0, 0)
        
        for idx, asset in enumerate(all_assets):
            # Create audit log for initial creation
            create_time = base_time + timedelta(days=idx)
            _create_asset_audit_log(
                session,
                asset,
                action="create",
                timestamp=create_time,
            )
        
        # Create update audit logs for some assets (room changes)
        # Projector 1 (AK MT000001): moved twice
        projector1 = session.exec(select(Asset).where(Asset.asset_serial == "AK MT000001")).first()
        if projector1:
            # First update: moved from room3 to room4
            _create_asset_audit_log(
                session,
                projector1,
                action="update",
                affected_columns=["room_id"],
                previous_value={"room_id": room3.room_id},
                new_value={"room_id": room4.room_id},
                timestamp=datetime(2025, 2, 15, 10, 30, 0),
            )
            # Second update: moved back from room4 to room5
            _create_asset_audit_log(
                session,
                projector1,
                action="update",
                affected_columns=["room_id"],
                previous_value={"room_id": room4.room_id},
                new_value={"room_id": room5.room_id},
                timestamp=datetime(2025, 5, 20, 14, 15, 0),
            )
        
        # Chair (AK MT000006): moved once
        chair1 = session.exec(select(Asset).where(Asset.asset_serial == "AK MT000006")).first()
        if chair1:
            _create_asset_audit_log(
                session,
                chair1,
                action="update",
                affected_columns=["room_id"],
                previous_value={"room_id": room4.room_id},
                new_value={"room_id": room1.room_id},
                timestamp=datetime(2025, 3, 10, 9, 0, 0),
            )
        
        # Table (AK MT000011): moved twice
        table = session.exec(select(Asset).where(Asset.asset_serial == "AK MT000011")).first()
        if table:
            # First update: moved from room5 to room2
            _create_asset_audit_log(
                session,
                table,
                action="update",
                affected_columns=["room_id"],
                previous_value={"room_id": room5.room_id},
                new_value={"room_id": room2.room_id},
                timestamp=datetime(2025, 4, 5, 11, 45, 0),
            )
            # Second update: moved back to room5
            _create_asset_audit_log(
                session,
                table,
                action="update",
                affected_columns=["room_id"],
                previous_value={"room_id": room2.room_id},
                new_value={"room_id": room5.room_id},
                timestamp=datetime(2025, 6, 1, 16, 20, 0),
            )

        # Upgrade any legacy plaintext passwords already in the DB to hashes.
        _migrate_plaintext_passwords(session)

        # Seed default notification preferences for all active users
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

        session.commit()
        print("Database seeded successfully!")

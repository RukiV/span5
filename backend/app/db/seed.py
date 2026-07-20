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
from ..models.role import Role
from ..models.user import User
from ..models.audit import Auditlog

from ..models.image import ImageAsset, ImageAssetLink, ImageBlob

def generate_mock_image_bytes(color_hex: str) -> bytes:
    """Generates a tiny, valid 1x1 pixel PNG byte string of a specific color 
    so your BYTEA database fields contain authentic image data structures.
    """
    # Base64 decoded transparent pixel sequence used as an authentic fallback bytes array
    return b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'


def _get_or_create_test_user(session: Session, user_name: str, user_surname: str, user_email: str, user_password: str, role_id: int) -> User:
    """
    Soek bestaande toetsgebruiker of skep nuwe met gegewe rol.
    
    Args:
        session: Databasis-sessie
        user_email: E-posadres vir soeken/skep
        user_password: Wagwoord vir nuwe gebruiker
        role_id: Rol-ID (1=Gebruiker, 2=FK-Koördineerder, 3=Administrateur)
        
    Returns:
        Bestaande of nuwe Gebruiker-objek
    """
    # Soek of gebruiker bestaan reeds
    user = session.exec(select(User).where(User.user_email == user_email)).first()
    if user:
        if user.role_id != role_id:
            user.role_id = role_id
            session.add(user)
            session.commit()
            session.refresh(user)
        return user

    # Skep nuwe toetsgebruiker met gegewe parameters
    user = User(
        user_name=user_name,
        user_surname=user_surname,
        user_email=user_email,
        user_password=user_password,
        user_number="0000000000",
        user_lastlogintime=None,
        user_lastlogouttime=None,
        user_status="active",
        role_id=role_id,  # Toekenning van rol vir toesgang-beheer
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user

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

        # FK-Koördineerder - KAN aanmeld, geen toegang tot Users-blad
        _get_or_create_test_user(
            session,
            user_name="fk",
            user_surname="user",
            user_email="fk@example.com",
            user_password="fk123",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
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

        # FK-Koördineerder - KAN aanmeld, geen toegang tot Users-blad
        _get_or_create_test_user(
            session,
            user_name="Jaco",
            user_surname="Venster",
            user_email="jaco@gmail.com",
            user_password="jaco123",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
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
            raw_data=mock_bytes
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
            image_id=img1.image_id,
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

        session.commit()
        print("Database seeded successfully!")

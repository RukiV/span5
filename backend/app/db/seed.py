from datetime import datetime
from typing import Optional
from sqlmodel import Session, select
from .database import engine
from ..models.location import Location, Room, RoomType, Zipcode
from ..models.asset import Asset, AssetStatus, Assettype
from ..models.stock import Stock
from ..models.job import Jobcard, JobStatus
from ..models.fault import Faultcard, FaultStatus, Priority, Type
from ..models.role import Role
from ..models.user import User

def _get_or_create_test_user(session: Session, user_email: str, user_password: str, role_id: int) -> User:
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
        user_name="Test",
        user_surname="User",
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

def _get_or_create_zipcode(session: Session) -> Zipcode:
    zipcode = session.exec(select(Zipcode)).first()
    if zipcode:
        return zipcode

    zipcode = Zipcode(
        zipcode_suburb="Sentraal",
        zipcode_city="Tegnopolis",
        zipcode_province="Provinsie",
        zipcode_country="Land"
    )
    session.add(zipcode)
    session.commit()
    session.refresh(zipcode)
    return zipcode


def _get_or_create_location(session: Session, name: str, location_type: str, streetnum: str, streetname: str, zipcode_id: int) -> Location:
    location = session.exec(select(Location).where(Location.location_name == name)).first()
    if location:
        return location

    location = Location(
        location_name=name,
        location_type=location_type,
        location_streetnum=streetnum,
        location_streetname=streetname,
        zipcode_id=zipcode_id,
    )
    session.add(location)
    session.commit()
    session.refresh(location)
    return location


def _get_or_create_room(session: Session, name: str, capacity: int, room_type: RoomType, location_id: int) -> Room:
    room = session.exec(select(Room).where(Room.room_name == name)).first()
    if room:
        return room

    room = Room(
        room_name=name,
        room_capacity=capacity,
        room_type=room_type,
        location_id=location_id,
    )
    session.add(room)
    session.commit()
    session.refresh(room)
    return room


def _get_or_create_assettype(session: Session) -> Assettype:
    assettype = session.exec(select(Assettype)).first()
    if assettype:
        return assettype

    assettype = Assettype(
        assettype_name="Algemene Toerusting",
        assettype_avg_lifespan=5,
        assettype_min_lifespan=3,
        assettype_max_lifespan=7,
        assettype_service_interval=12,
    )
    session.add(assettype)
    session.commit()
    session.refresh(assettype)
    return assettype


def _get_or_create_asset(session: Session, name: str, serial: str, status: AssetStatus, is_outdoor: bool, room_id: int | None, assettype_id: int) -> Asset:
    asset = session.exec(select(Asset).where(Asset.asset_name == name)).first()
    if asset:
        return asset

    asset = Asset(
        asset_name=name,
        asset_serial=serial,
        asset_status=status,
        asset_isoutdoor=is_outdoor,
        room_id=room_id,
        assettype_id=assettype_id,
    )
    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset


def _get_or_create_stock(session: Session, name: str, brand: str, amount: int, stock_type: str, desc: str, room_id: int | None) -> Stock:
    stock = session.exec(select(Stock).where(Stock.stock_brand == brand, Stock.stock_type == stock_type)).first()
    if stock:
        return stock

    stock = Stock(
        stock_name=name,
        stock_brand=brand,
        stock_amount=amount,
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
    asset_id: Optional[int] = None,
    fault_id: Optional[int] = None,
    quote_id: Optional[int] = None,
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
        asset_id=asset_id,
        fault_id=fault_id,
        quote_id=quote_id,
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

        # Skep toetsgebruikers vir elke rol
        # Gewone Gebruiker - kan NIE aanmeld nie (403-fout)
        _get_or_create_test_user(
            session,
            user_email="test@example.com",
            user_password="password123",
            role_id=user_role.role_id,  # role_id = 1 (geweier)
        )

        # FK-Koördineerder - KAN aanmeld, geen toegang tot Users-blad
        _get_or_create_test_user(
            session,
            user_email="fk@example.com",
            user_password="fk123",
            role_id=fk_role.role_id,  # role_id = 2 (toelaat)
        )

        # Administrateur - KAN aanmeld EN vol toegang
        _get_or_create_test_user(
            session,
            user_email="admin@example.com",
            user_password="admin123",
            role_id=admin_role.role_id,  # role_id = 3 (toelaat)
        )

        # Skep toetsdata vir lokasies, kamers, bates, ens.
        zipcode = _get_or_create_zipcode(session)

        loc1 = _get_or_create_location(
            session,
            name="Hoofkampus",
            location_type="Onderwys",
            streetnum="123",
            streetname="Universiteitweg",
            zipcode_id=zipcode.zipcode_id,
        )

        loc2 = _get_or_create_location(
            session,
            name="Tegnologiesentrum",
            location_type="Kantoor",
            streetnum="45",
            streetname="Innovasieblvd",
            zipcode_id=zipcode.zipcode_id,
        )

        room1 = _get_or_create_room(
            session,
            name="Aula A",
            capacity=100,
            room_type=RoomType.OTHER,
            location_id=loc1.location_id,
        )

        room2 = _get_or_create_room(
            session,
            name="Bedienervertrek",
            capacity=5,
            room_type=RoomType.OTHER,
            location_id=loc2.location_id,
        )

        assettype = _get_or_create_assettype(session)

        _get_or_create_asset(
            session,
            name="Projektor 4K",
            serial="AK-MT000001",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room1.room_id,
            assettype_id=assettype.assettype_id,
        )

        _get_or_create_asset(
            session,
            name="Buitetoeveiliingskamera",
            serial="AK-MT000002",
            status=AssetStatus.ACTIVE,
            is_outdoor=True,
            room_id=room2.room_id,
            assettype_id=assettype.assettype_id,
        )

        _get_or_create_stock(
            session,
            name="Dell Latitude",
            brand="Dell",
            amount=50,
            stock_type="Skootrekenaar",
            desc="Dell Latitude skootrekenaars vir personeelgebruik",
            room_id=room2.room_id,
        )

        _get_or_create_stock(
            session,
            name="HP LaserJet",
            brand="HP",
            amount=25,
            stock_type="Drukker",
            desc="HP LaserJet-drukkers vir kantoorgebruik",
            room_id=room1.room_id,
        )

        _get_or_create_stock(
            session,
            name="Cisco Switch",
            brand="Cisco",
            amount=10,
            stock_type="Netwerkskakelaars",
            desc="Cisco-netwerkskakelaars vir IT-infrastruktuur",
            room_id=room2.room_id,
        )

        _get_or_create_stock(
            session,
            name="Microsoft Office",
            brand="Microsoft",
            amount=100,
            stock_type="Lisensie",
            desc="Microsoft Office 365-lisensies",
            room_id=None,
        )

        projector_asset = session.exec(select(Asset).where(Asset.asset_name == "Projektor 4K")).first()
        camera_asset = session.exec(select(Asset).where(Asset.asset_name == "Buitetoeveiliingskamera")).first()

        _get_or_create_job(
            session,
            desc="Vervang projektorbólpe in Aula A",
            status=JobStatus.WAIT,
            job_type="maintenance",
            created_dt=datetime.now(),
            asset_id=projector_asset.asset_id if projector_asset else None,
        )

        _get_or_create_job(
            session,
            desc="Inspekteer buitetoeveiliingskamerarigting",
            status=JobStatus.OPEN,
            job_type="inspection",
            created_dt=datetime.now(),
            asset_id=camera_asset.asset_id if camera_asset else None,
        )

        _get_or_create_fault(
            session,
            description="Beveiliingskamera af-lêer vanweë stroomonderbreking",
            status=FaultStatus.WAIT,
            priority=Priority.HIGH,
            fault_type=Type.REPAIR,
            report_dt=datetime.now(),
            asset_id=camera_asset.asset_id if camera_asset else None,
        )

        _get_or_create_fault(
            session,
            description="Projektorbólpe flikkering tydens lesings",
            status=FaultStatus.OPEN,
            priority=Priority.MEDIUM,
            fault_type=Type.MAINTENANCE,
            report_dt=datetime.now(),
            asset_id=projector_asset.asset_id if projector_asset else None,
        )

        session.commit()
        print("Database seeded successfully!")

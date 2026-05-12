from sqlmodel import Session, select
from .database import engine
from ..models.location import Location, Room, RoomType, Zipcode
from ..models.asset import Asset, AssetStatus, Assettype
from ..models.stock import Stock


def _get_or_create_zipcode(session: Session) -> Zipcode:
    zipcode = session.exec(select(Zipcode)).first()
    if zipcode:
        return zipcode

    zipcode = Zipcode(
        zipcode_suburb="Central",
        zipcode_city="Techville",
        zipcode_province="State",
        zipcode_country="Country"
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
        assettype_name="General Equipment",
        assettype_avg_lifespan=5,
        assettype_min_lifespan=3,
        assettype_max_lifespan=7,
        assettype_service_interval=12,
    )
    session.add(assettype)
    session.commit()
    session.refresh(assettype)
    return assettype


def _get_or_create_asset(session: Session, name: str, status: AssetStatus, is_outdoor: bool, room_id: int | None, assettype_id: int) -> Asset:
    asset = session.exec(select(Asset).where(Asset.asset_name == name)).first()
    if asset:
        return asset

    asset = Asset(
        asset_name=name,
        asset_status=status,
        asset_isoutdoor=is_outdoor,
        room_id=room_id,
        assettype_id=assettype_id,
    )
    session.add(asset)
    session.commit()
    session.refresh(asset)
    return asset


def _get_or_create_stock(session: Session, brand: str, amount: int, stock_type: str, desc: str, room_id: int | None) -> Stock:
    stock = session.exec(select(Stock).where(Stock.stock_brand == brand, Stock.stock_type == stock_type)).first()
    if stock:
        return stock

    stock = Stock(
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


def seed_data():
    print("Seed function called")
    with Session(engine) as session:
        zipcode = _get_or_create_zipcode(session)

        loc1 = _get_or_create_location(
            session,
            name="Main Campus",
            location_type="Education",
            streetnum="123",
            streetname="University Way",
            zipcode_id=zipcode.zipcode_id,
        )

        loc2 = _get_or_create_location(
            session,
            name="Tech Hub",
            location_type="Office",
            streetnum="45",
            streetname="Innovation Blvd",
            zipcode_id=zipcode.zipcode_id,
        )

        room1 = _get_or_create_room(
            session,
            name="Lecture Hall A",
            capacity=100,
            room_type=RoomType.OTHER,
            location_id=loc1.location_id,
        )

        room2 = _get_or_create_room(
            session,
            name="Server Room",
            capacity=5,
            room_type=RoomType.OTHER,
            location_id=loc2.location_id,
        )

        assettype = _get_or_create_assettype(session)

        _get_or_create_asset(
            session,
            name="Projector 4K",
            status=AssetStatus.ACTIVE,
            is_outdoor=False,
            room_id=room1.room_id,
            assettype_id=assettype.assettype_id,
        )

        _get_or_create_asset(
            session,
            name="Outdoor Security Camera",
            status=AssetStatus.ACTIVE,
            is_outdoor=True,
            room_id=room2.room_id,
            assettype_id=assettype.assettype_id,
        )

        _get_or_create_stock(
            session,
            brand="Dell",
            amount=50,
            stock_type="Laptop",
            desc="Dell Latitude laptops for staff use",
            room_id=room2.room_id,
        )

        _get_or_create_stock(
            session,
            brand="HP",
            amount=25,
            stock_type="Printer",
            desc="HP LaserJet printers for office use",
            room_id=room1.room_id,
        )

        _get_or_create_stock(
            session,
            brand="Cisco",
            amount=10,
            stock_type="Network Switch",
            desc="Cisco network switches for IT infrastructure",
            room_id=room2.room_id,
        )

        _get_or_create_stock(
            session,
            brand="Microsoft",
            amount=100,
            stock_type="Office License",
            desc="Microsoft Office 365 licenses",
            room_id=None,
        )

        session.commit()
        print("Database seeded successfully!")

from sqlmodel import Session, select
from .database import engine
from ..models.location import Location, Room, RoomType, Zipcode
from ..models.asset import Asset, AssetStatus

def seed_data():
    with Session(engine) as session:
        # 1. Check if data already exists to avoid duplicates
        if session.exec(select(Location)).first():
            return

        # 2. Add one Zipcode first so locations can reference it
        zipcode = Zipcode(
            zipcode_suburb="Central",
            zipcode_city="Techville",
            zipcode_province="State",
            zipcode_country="Country"
        )
        session.add(zipcode)
        session.commit()
        session.refresh(zipcode)

        # 3. Add Dummy Locations
        loc1 = Location(
            location_name="Main Campus", 
            location_type="Education", 
            location_streetnum="123", 
            location_streetname="University Way",
            zipcode_id=zipcode.zipcode_id
        )
        loc2 = Location(
            location_name="Tech Hub", 
            location_type="Office", 
            location_streetnum="45", 
            location_streetname="Innovation Blvd",
            zipcode_id=zipcode.zipcode_id
        )
        session.add(loc1)
        session.add(loc2)
        session.commit() # Commit to get location_ids

        # 3. Add Dummy Rooms
        room1 = Room(room_name="Lecture Hall A", room_capacity=100, room_type=RoomType.OTHER, location_id=loc1.location_id)
        room2 = Room(room_name="Server Room", room_capacity=5, room_type=RoomType.OTHER, location_id=loc2.location_id)
        session.add(room1)
        session.add(room2)
        session.commit()

        # 4. Add Dummy Assets
        asset1 = Asset(
            asset_name="Projector 4K", 
            asset_status=AssetStatus.ACTIVE, 
            asset_isoutdoor=False, 
            room_id=room1.room_id, 
            assettype_id=1
        )
        asset2 = Asset(
            asset_name="Outdoor Security Camera", 
            asset_status=AssetStatus.ACTIVE, 
            asset_isoutdoor=True, 
            room_id=room2.room_id, 
            assettype_id=2
        )
        session.add(asset1)
        session.add(asset2)
        
        session.commit()
        print("Database seeded successfully!")
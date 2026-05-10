from sqlmodel import Session, select, delete
from datetime import datetime
from .database import engine
from ..models import (
    Role, User, Asset, Assettype, Room,
    Faultcard, Jobcard, Contractor, Quote,
    Priority, FaultStatus, JobStatus, AssetStatus, RoomType
)


def create_sample_data():
    """Create sample records"""
    with Session(engine) as session:
        
        # 1. Create Role
        admin_role = Role(role_name="Administrator")
        session.add(admin_role)
        session.commit()
        session.refresh(admin_role)
        print(f"Role created: {admin_role.role_name} (ID: {admin_role.role_id})")

        # 2. Create User
        new_user = User(
            role_id=admin_role.role_id,
            user_name="John",
            user_surname="Doe",
            user_email="john.doe@example.com",
            user_number="0812345678",
            user_password="hashed_password123",  # In production, use proper hashing
            user_status="active"
        )
        session.add(new_user)
        session.commit()
        session.refresh(new_user)
        print(f"User created: {new_user.user_name} {new_user.user_surname} (ID: {new_user.user_id})")

        # 3. Create Asset Type
        asset_type = Assettype(
            assettype_name="Air Conditioner",
            assettype_avg_lifespan=10,
            assettype_min_lifespan=5,
            assettype_max_lifespan=15,
            assettype_service_interval=6
        )
        session.add(asset_type)
        session.commit()
        session.refresh(asset_type)

        # 4. Create Asset
        asset = Asset(
            assettype_id=asset_type.assettype_id,
            asset_name="Office AC Unit 101",
            asset_status=AssetStatus.ACTIVE,
            asset_isoutdoor=False
        )
        session.add(asset)
        session.commit()
        session.refresh(asset)
        print(f"Asset created: {asset.asset_name}")

        print("Sample data creation completed.")


def read_examples():
    """Read operations"""
    with Session(engine) as session:
        
        # Get all users
        users = session.exec(select(User)).all()
        print(f"Total Users: {len(users)}")
        for user in users:
            print(f"   - {user.user_name} {user.user_surname} ({user.user_email})")

        # Get user by email
        statement = select(User).where(User.user_email == "john.doe@example.com")
        user = session.exec(statement).first()
        if user:
            print(f"Found user: {user.user_name} {user.user_surname}")

        # Get all active assets
        active_assets = session.exec(
            select(Asset).where(Asset.asset_status == AssetStatus.ACTIVE)
        ).all()
        print(f"Active Assets: {len(active_assets)}")


def update_example():
    """Update operation"""
    with Session(engine) as session:
        # Find user
        user = session.exec(
            select(User).where(User.user_email == "john.doe@example.com")
        ).first()

        if user:
            user.user_status = "inactive"
            user.user_lastlogintime = datetime.now()
            session.add(user)
            session.commit()
            session.refresh(user)
            print(f"User updated: {user.user_name} status = {user.user_status}")


def delete_example():
    """Delete operation (soft delete recommended in production)"""
    with Session(engine) as session:
        # Example: Delete a quote (be careful with foreign keys in real use)
        # quote = session.exec(select(Quote)).first()
        # if quote:
        #     session.delete(quote)
        #     session.commit()
        #     print("Quote deleted")
        print("Delete example available (commented for safety)")


if __name__ == "__main__":
    print("Starting CRUD examples...")
    
    create_sample_data()
    read_examples()
    update_example()
    # delete_example()   # Uncomment when needed
    
    print("All CRUD examples completed.")
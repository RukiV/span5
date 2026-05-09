from typing import Optional
from datetime import datetime, date
from decimal import Decimal
from sqlmodel import SQLModel
from sqlmodel import SQLModel, Field, Column
from sqlalchemy.dialects.postgresql import JSONB
from sqlmodel import SQLModel, create_engine
#Run net die File om die Tabelle te skep.
DATABASE_URL = "postgresql+psycopg2://admin:1234@localhost:5432/FMS"

engine = create_engine(DATABASE_URL, echo=True)

class RoleRight(SQLModel, table=True):
    role_id: Optional[int] = Field(
        default=None,
        foreign_key="role.role_id",
        primary_key=True
    )

    right_id: Optional[int] = Field(
        default=None,
        foreign_key="rights.right_id",
        primary_key=True
    )


class Rights(SQLModel, table=True):
    right_id: Optional[int] = Field(default=None, primary_key=True)

    right_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    right_description: Optional[str] = None


class Role(SQLModel, table=True):
    role_id: Optional[int] = Field(default=None, primary_key=True)

    role_name: Optional[str] = Field(
        default=None,
        max_length=100
    )


class User(SQLModel, table=True):
    user_id: Optional[int] = Field(default=None, primary_key=True)

    role_id: Optional[int] = Field(
        default=None,
        foreign_key="role.role_id"
    )

    user_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    user_surname: Optional[str] = Field(
        default=None,
        max_length=100
    )

    user_email: Optional[str] = Field(
        default=None,
        max_length=150
    )

    user_number: Optional[str] = Field(
        default=None,
        max_length=20
    )

    user_password: Optional[str] = None

    user_lastlogintime: Optional[datetime] = None

    user_lastlogouttime: Optional[datetime] = None

    user_status: Optional[str] = Field(
        default=None,
        max_length=50
    )


class Auditlog(SQLModel, table=True):
    auditlog_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(
        default=None,
        foreign_key="user.user_id"
    )

    action: Optional[str] = Field(
        default=None,
        max_length=100
    )

    affectedtable: Optional[str] = Field(
        default=None,
        max_length=100
    )

    json_data: Optional[dict] = Field(
        default=None,
        sa_column=Column(JSONB)
    )

    affectedcolumn: Optional[str] = Field(
        default=None,
        max_length=100
    )

    actiondatetime: Optional[datetime] = None


class Zipcode(SQLModel, table=True):
    zipcode_id: Optional[int] = Field(default=None, primary_key=True)

    zipcode_suburb: Optional[str] = Field(
        default=None,
        max_length=100
    )

    zipcode_city: Optional[str] = Field(
        default=None,
        max_length=100
    )

    zipcode_province: Optional[str] = Field(
        default=None,
        max_length=100
    )

    zipcode_country: Optional[str] = Field(
        default=None,
        max_length=100
    )


class Terrain(SQLModel, table=True):
    terrain_id: Optional[int] = Field(default=None, primary_key=True)

    zipcode_id: Optional[int] = Field(
        default=None,
        foreign_key="zipcode.zipcode_id"
    )

    terrain_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    terrain_type: Optional[str] = Field(
        default=None,
        max_length=50
    )

    terrain_streetnum: Optional[str] = Field(
        default=None,
        max_length=20
    )

    terrain_streetname: Optional[str] = Field(
        default=None,
        max_length=100
    )


class Room(SQLModel, table=True):
    room_id: Optional[int] = Field(default=None, primary_key=True)

    terrain_id: Optional[int] = Field(
        default=None,
        foreign_key="terrain.terrain_id"
    )

    room_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    room_capacity: Optional[int] = None

    room_type: Optional[str] = Field(
        default=None,
        max_length=50
    )


class Assettype(SQLModel, table=True):
    assettype_id: Optional[int] = Field(default=None, primary_key=True)

    assettype_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    assettype_avg_lifespan: Optional[int] = None

    assettype_min_lifespan: Optional[int] = None

    assettype_max_lifespan: Optional[int] = None

    assettype_service_interval: Optional[int] = None


class Asset(SQLModel, table=True):
    asset_id: Optional[int] = Field(default=None, primary_key=True)

    room_id: Optional[int] = Field(
        default=None,
        foreign_key="room.room_id"
    )

    assettype_id: Optional[int] = Field(
        default=None,
        foreign_key="assettype.assettype_id"
    )

    asset_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    asset_status: Optional[str] = Field(
        default=None,
        max_length=50
    )

    asset_isoutdoor: Optional[bool] = None


class Stock(SQLModel, table=True):
    stock_id: Optional[int] = Field(default=None, primary_key=True)

    room_id: Optional[int] = Field(
        default=None,
        foreign_key="room.room_id"
    )

    stock_brand: Optional[str] = Field(
        default=None,
        max_length=100
    )

    stock_amount: Optional[int] = None

    stock_type: Optional[str] = Field(
        default=None,
        max_length=50
    )

    stock_desc: Optional[str] = None


class Mappoint(SQLModel, table=True):
    mappoint_id: Optional[int] = Field(default=None, primary_key=True)

    mp_longitude: Optional[Decimal] = Field(
        default=None,
        decimal_places=6
    )

    mp_latitude: Optional[Decimal] = Field(
        default=None,
        decimal_places=6
    )


class Faultcard(SQLModel, table=True):
    fault_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(
        default=None,
        foreign_key="user.user_id"
    )

    asset_id: Optional[int] = Field(
        default=None,
        foreign_key="asset.asset_id"
    )

    room_id: Optional[int] = Field(
        default=None,
        foreign_key="room.room_id"
    )

    mappoint_id: Optional[int] = Field(
        default=None,
        foreign_key="mappoint.mappoint_id"
    )

    fault_description: Optional[str] = None

    fault_type: Optional[str] = Field(
        default=None,
        max_length=50
    )

    fault_status: Optional[str] = Field(
        default=None,
        max_length=50
    )

    fault_priority: Optional[str] = Field(
        default=None,
        max_length=50
    )

    fault_reportdatetime: Optional[datetime] = None

    fault_updatedatetime: Optional[datetime] = None


class Jobrecurring(SQLModel, table=True):
    jobrecurr_id: Optional[int] = Field(default=None, primary_key=True)

    job_recurringinterval: Optional[int] = None


class Contractor(SQLModel, table=True):
    contractor_id: Optional[int] = Field(default=None, primary_key=True)

    contractor_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    contractor_surname: Optional[str] = Field(
        default=None,
        max_length=100
    )

    contractor_email: Optional[str] = Field(
        default=None,
        max_length=150
    )

    contractor_number: Optional[str] = Field(
        default=None,
        max_length=20
    )

    contractor_type: Optional[str] = Field(
        default=None,
        max_length=50
    )


class Quote(SQLModel, table=True):
    quote_id: Optional[int] = Field(default=None, primary_key=True)

    contractor_id: Optional[int] = Field(
        default=None,
        foreign_key="contractor.contractor_id"
    )

    quote_price: Optional[Decimal] = Field(
        default=None,
        decimal_places=2
    )

    quote_desc: Optional[str] = None

    quote_date: Optional[date] = None

    quote_status: Optional[str] = Field(
        default=None,
        max_length=50
    )


class Jobcard(SQLModel, table=True):
    jobcard_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(
        default=None,
        foreign_key="user.user_id"
    )

    asset_id: Optional[int] = Field(
        default=None,
        foreign_key="asset.asset_id"
    )

    fault_id: Optional[int] = Field(
        default=None,
        foreign_key="faultcard.fault_id"
    )

    quote_id: Optional[int] = Field(
        default=None,
        foreign_key="quote.quote_id"
    )

    jobrecurr_id: Optional[int] = Field(
        default=None,
        foreign_key="jobrecurring.jobrecurr_id"
    )

    mappoint_id: Optional[int] = Field(
        default=None,
        foreign_key="mappoint.mappoint_id"
    )

    job_desc: Optional[str] = None

    job_status: Optional[str] = Field(
        default=None,
        max_length=50
    )

    job_type: Optional[str] = Field(
        default=None,
        max_length=50
    )

    job_createddatetime: Optional[datetime] = None

    job_finisheddatetime: Optional[datetime] = None


class Servicehistory(SQLModel, table=True):
    service_id: Optional[int] = Field(default=None, primary_key=True)

    asset_id: Optional[int] = Field(
        default=None,
        foreign_key="asset.asset_id"
    )

    jobcard_id: Optional[int] = Field(
        default=None,
        foreign_key="jobcard.jobcard_id"
    )

    service_desc: Optional[str] = None

    service_datetime: Optional[datetime] = None


class Reports(SQLModel, table=True):
    report_id: Optional[int] = Field(default=None, primary_key=True)

    user_id: Optional[int] = Field(
        default=None,
        foreign_key="user.user_id"
    )

    report_name: Optional[str] = Field(
        default=None,
        max_length=100
    )

    report_desc: Optional[str] = None

    report_file: Optional[str] = None

if __name__ == "__main__":
    print("Creating database tables...")
    SQLModel.metadata.create_all(engine)
    print("✅ All tables created successfully!")
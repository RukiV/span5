import os
from sqlalchemy import inspect, text
from sqlmodel import create_engine, Session, SQLModel

# Database Configuration
# Prefer a full DATABASE_URL, otherwise build one from individual env vars.
DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    DATABASE_URL = (
        "postgresql+psycopg2://"
        f"{os.getenv('DB_USER', 'postgres')}:{os.getenv('DB_PASSWORD', 'password')}@"
        f"{os.getenv('DB_HOST', 'localhost')}:{os.getenv('DB_PORT', '5432')}/"
        f"{os.getenv('DB_NAME', 'facility_db')}"
    )

engine = create_engine(DATABASE_URL, echo=True)


def createDBandTables():
    SQLModel.metadata.create_all(engine)

    with engine.begin() as connection:
        inspector = inspect(connection)
        if "jobcard" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("jobcard")}
            if "quote_ids" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS quote_ids TEXT"))
            if "room_id" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS room_id INTEGER"))
            if "job_scheduled_datetime" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_scheduled_datetime TIMESTAMP"))
            if "job_schedule_type" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_schedule_type VARCHAR(20)"))
            if "job_finisheddatetime" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_finisheddatetime TIMESTAMP"))
            if "job_scheduled_end_datetime" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_scheduled_end_datetime TIMESTAMP"))
            if "assigned_to" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS assigned_to INTEGER REFERENCES \"user\"(user_id)"))
            if "cc_users" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS cc_users TEXT"))
            if "job_priority" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_priority VARCHAR(20) DEFAULT 'Normal'"))
            if "nature" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS nature VARCHAR(100)"))

        if "quote" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("quote")}
            if "contractor_id" not in columns:
                connection.execute(text("ALTER TABLE quote ADD COLUMN IF NOT EXISTS contractor_id INTEGER"))
            if "quote_selection_reason" not in columns:
                connection.execute(text("ALTER TABLE quote ADD COLUMN IF NOT EXISTS quote_selection_reason TEXT"))

        
        if "contractor" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("contractor")}
            if "contractor_businessName" not in columns:
                connection.execute(text("ALTER TABLE contractor ADD COLUMN IF NOT EXISTS contractor_businessName VARCHAR(100)"))

        if "faultcard" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("faultcard")}
            if "image_id_2" not in columns:
                connection.execute(text("ALTER TABLE faultcard ADD COLUMN IF NOT EXISTS image_id_2 INTEGER"))
            if "image_id_3" not in columns:
                connection.execute(text("ALTER TABLE faultcard ADD COLUMN IF NOT EXISTS image_id_3 INTEGER"))


def getSession():
    with Session(engine) as session:
        yield session
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
            connection.execute(text("SELECT setval('quote_quote_id_seq', COALESCE(MAX(quote_id), 1)) FROM quote"))

        
        if "contractor" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("contractor")}
            if "contractor_businessName" not in columns:
                connection.execute(text("ALTER TABLE contractor ADD COLUMN IF NOT EXISTS contractor_businessName VARCHAR(100)"))

        if "quote_document" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("quote_document")}
            if "mime_type" not in columns:
                connection.execute(text("ALTER TABLE quote_document ADD COLUMN IF NOT EXISTS mime_type VARCHAR(100)"))
            if "size_bytes" not in columns:
                connection.execute(text("ALTER TABLE quote_document ADD COLUMN IF NOT EXISTS size_bytes INTEGER"))

        if "faultcard" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("faultcard")}
            if "image_id_2" not in columns:
                connection.execute(text("ALTER TABLE faultcard ADD COLUMN IF NOT EXISTS image_id_2 INTEGER"))
            if "image_id_3" not in columns:
                connection.execute(text("ALTER TABLE faultcard ADD COLUMN IF NOT EXISTS image_id_3 INTEGER"))

        if "user" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("user")}
            if "location_id" not in columns:
                connection.execute(text("ALTER TABLE \"user\" ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES location(location_id)"))

        if "notification" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("notification")}
            if "is_seen" not in columns:
                connection.execute(text("ALTER TABLE notification ADD COLUMN IF NOT EXISTS is_seen BOOLEAN DEFAULT FALSE"))
        else:
            connection.execute(text("""
                CREATE TABLE IF NOT EXISTS notification (
                    notification_id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES "user"(user_id),
                    actor_id INTEGER REFERENCES "user"(user_id),
                    notification_type VARCHAR(50) NOT NULL,
                    title VARCHAR(255) NOT NULL,
                    message TEXT NOT NULL,
                    reference_type VARCHAR(50),
                    reference_id INTEGER,
                    is_read BOOLEAN DEFAULT FALSE,
                    is_seen BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT NOW()
                )
            """))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_notif_user_read ON notification(user_id, is_read)"))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_notif_created ON notification(created_at DESC)"))

        if "notification_preferences" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE IF NOT EXISTS notification_preferences (
                    user_id INTEGER NOT NULL REFERENCES "user"(user_id),
                    notification_type VARCHAR(50) NOT NULL,
                    in_app_enabled BOOLEAN DEFAULT TRUE,
                    email_enabled BOOLEAN DEFAULT FALSE,
                    push_enabled BOOLEAN DEFAULT TRUE,
                    PRIMARY KEY (user_id, notification_type)
                )
            """))

        if "device_tokens" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE IF NOT EXISTS device_tokens (
                    token_id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES "user"(user_id),
                    fcm_token TEXT NOT NULL,
                    platform VARCHAR(10) NOT NULL,
                    created_at TIMESTAMP DEFAULT NOW(),
                    updated_at TIMESTAMP DEFAULT NOW()
                )
            """))


def getSession():
    with Session(engine) as session:
        yield session
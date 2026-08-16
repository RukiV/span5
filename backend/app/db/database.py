import os
from sqlalchemy import inspect, text
from sqlmodel import create_engine, Session, SQLModel

# Import models so SQLModel.metadata.create_all() picks them up
from ..models.idempotency import IdempotencyRecord  # noqa: F401

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
            if "job_notes" not in columns:
                connection.execute(text("ALTER TABLE jobcard ADD COLUMN IF NOT EXISTS job_notes TEXT"))
            # Brei die job_status PostgreSQL-enum uit vir die nuwe status
            # (Geskeduleer). SQLAlchemy stoor die enum-lidname (WAIT/OPEN/...).
            try:
                job_cols = {
                    col["name"]: col["type"] for col in inspector.get_columns("jobcard")
                }
                job_status = job_cols.get("job_status")
                enum_name = getattr(job_status, "name", None)
                if enum_name:
                    connection.execute(
                        text(f"ALTER TYPE {enum_name} ADD VALUE IF NOT EXISTS 'SCHEDULED'")
                    )
            except Exception:
                # Nie 'n native enum nie (bv. VARCHAR) of reeds bygevoeg — ignoreer.
                pass

        if "quote" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("quote")}
            if "contractor_id" not in columns:
                connection.execute(text("ALTER TABLE quote ADD COLUMN IF NOT EXISTS contractor_id INTEGER"))
            if "quote_selection_reason" not in columns:
                connection.execute(text("ALTER TABLE quote ADD COLUMN IF NOT EXISTS quote_selection_reason TEXT"))
            connection.execute(text("ALTER TABLE quote DROP COLUMN IF EXISTS quote_price"))
            connection.execute(text("ALTER TABLE quote DROP COLUMN IF EXISTS quote_desc"))
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
            if "is_outdoor" not in columns:
                connection.execute(text("ALTER TABLE faultcard ADD COLUMN IF NOT EXISTS is_outdoor BOOLEAN DEFAULT FALSE"))
            # Brei die fault_type PostgreSQL-enum uit vir die nuwe werksoort-
            # waardes (Inspeksie/Installasie). SQLAlchemy stoor die enum-lidname
            # (MAINTENANCE/REPAIR/...), so bestaande rye word nie geraak nie.
            try:
                fault_cols = {
                    col["name"]: col["type"] for col in inspector.get_columns("faultcard")
                }
                fault_type = fault_cols.get("fault_type")
                enum_name = getattr(fault_type, "name", None)
                if enum_name:
                    connection.execute(
                        text(f"ALTER TYPE {enum_name} ADD VALUE IF NOT EXISTS 'INSPECTION'")
                    )
                    connection.execute(
                        text(f"ALTER TYPE {enum_name} ADD VALUE IF NOT EXISTS 'INSTALLATION'")
                    )
            except Exception:
                # Nie 'n native enum nie (bv. VARCHAR) of reeds bygevoeg — ignoreer.
                pass

        if "location" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("location")}
            if "location_latitude" not in columns:
                connection.execute(text("ALTER TABLE location ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION"))
            if "location_longitude" not in columns:
                connection.execute(text("ALTER TABLE location ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION"))
            if "location_radius" not in columns:
                connection.execute(text("ALTER TABLE location ADD COLUMN IF NOT EXISTS location_radius DOUBLE PRECISION DEFAULT 110"))

        if "user" in inspector.get_table_names():
            columns = {column["name"] for column in inspector.get_columns("user")}
            if "location_id" not in columns:
                connection.execute(text("ALTER TABLE \"user\" ADD COLUMN IF NOT EXISTS location_id INTEGER REFERENCES location(location_id)"))
            if "failed_login_attempts" not in columns:
                connection.execute(text("ALTER TABLE \"user\" ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER DEFAULT 0"))
            if "locked_until" not in columns:
                connection.execute(text("ALTER TABLE \"user\" ADD COLUMN IF NOT EXISTS locked_until TIMESTAMP"))

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

        if "revoked_tokens" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE IF NOT EXISTS revoked_tokens (
                    token_id SERIAL PRIMARY KEY,
                    token_hash VARCHAR(64) NOT NULL,
                    revoked_at TIMESTAMP DEFAULT NOW(),
                    expires_at TIMESTAMP NOT NULL,
                    user_id INTEGER NOT NULL
                )
            """))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_revoked_hash ON revoked_tokens(token_hash)"))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_revoked_expires ON revoked_tokens(expires_at)"))

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

        if "password_reset_tokens" not in inspector.get_table_names():
            connection.execute(text("""
                CREATE TABLE IF NOT EXISTS password_reset_tokens (
                    reset_id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES "user"(user_id),
                    token_hash VARCHAR(64) NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    used BOOLEAN DEFAULT FALSE
                )
            """))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_reset_token_hash ON password_reset_tokens(token_hash)"))
            connection.execute(text("CREATE INDEX IF NOT EXISTS idx_reset_user ON password_reset_tokens(user_id)"))

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


def purge_expired_revoked_tokens():
    with engine.begin() as connection:
        connection.execute(
            text("DELETE FROM revoked_tokens WHERE expires_at < NOW()")
        )


def getSession():
    with Session(engine) as session:
        yield session
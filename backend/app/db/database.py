import os
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

def getSession():
    with Session(engine) as session:
        yield session
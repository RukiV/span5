from sqlmodel import create_engine
from sqlalchemy.engine import Engine

# Database Configuration
DATABASE_URL = "postgresql+psycopg2://admin:1234@localhost:5432/FMS"

# Create engine
engine: Engine = create_engine(
    DATABASE_URL, 
    echo=True,           # Set to False in production
    pool_pre_ping=True   # Helps with connection stability in Docker
)
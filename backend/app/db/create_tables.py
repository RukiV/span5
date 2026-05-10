from sqlmodel import SQLModel
from .database import engine

# Import all models to register them with SQLModel.metadata
from ..models import *

def create_db_and_tables():
    print("Creating all database tables...")
    SQLModel.metadata.create_all(engine)
    print("All tables created successfully.")


def drop_all_tables():
    """Use this carefully - it will delete all data!"""
    print("Dropping all tables...")
    SQLModel.metadata.drop_all(engine)
    print("All tables dropped.")


if __name__ == "__main__":
    create_db_and_tables()
    # Uncomment the line below if you want to reset the database:
    # drop_all_tables()
    # create_db_and_tables()
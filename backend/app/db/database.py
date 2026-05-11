from sqlmodel import create_engine, Session, SQLModel

# Database Configuration
DATABASE_URL = "postgresql+psycopg2://admin:1234@localhost:5432/FMS"
engine = create_engine(DATABASE_URL, echo=True)

def createDBandTables():
    SQLModel.metadata.create_all(engine)

def getSession():
    with Session(engine) as session:
        yield session
from sqlmodel import SQLModel, Field

class FacilityManagementBase(SQLModel):
    id: int = Field(default=None, primary_key=True)
    name: str = Field(index=True)
from typing import Optional
from sqlmodel import SQLModel, Field

class ImageAssetBase(SQLModel):
    filename: str = Field(index=True)
    mime_type: str  # e.g., "image/jpeg", "image/png"
    
    # This maps directly to PostgreSQL BYTEA
    file_bytes: bytes = Field(nullable=False)

class ImageAsset(ImageAssetBase, Base, table=True):
    image_id: Optional[int] = Field(default=None, primary_key=True)

class ImageAssetCreate(ImageAssetBase):
    image_id: int

class ImageAssetRead(ImageAssetBase):
    image_id: int
    
class ImageAssetUpdate(ImageAssetBase):
    image_id: Optional[int] = None
    
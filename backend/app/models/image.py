# File: app/models/image_models.py
from typing import Optional
from sqlmodel import SQLModel, Field, Relationship
from .base import Base  # Adjust this import to match your project base setup

class ImageAssetBase(SQLModel):
    """Base attributes shared across image schemas."""
    filename: str = Field(index=True)
    mime_type: str 
    size_bytes: int

class ImageAssetCreate(SQLModel):
    pass

class ImageAssetRead(ImageAssetBase):
    image_id: int

class ImageAssetUpdate(SQLModel):
    filename: Optional[str] = None


class ImageAsset(ImageAssetBase, Base, table=True):
    """Primary universal metadata lookup table for images."""
    __tablename__: str = "image"
    
    image_id: Optional[int] = Field(default=None, primary_key=True)

    # 1:1 relationship with its corresponding binary storage row
    file_blob: "ImageBlob" = Relationship(
        back_populates="image_asset", 
        sa_relationship_kwargs={"cascade": "all, delete-orphan", "uselist": False}
    )


class ImageBlob(SQLModel, table=True):
    """Isolated high-footprint binary table to keep queries fast."""
    __tablename__: str = "image_blobs"

    image_id: Optional[int] = Field(
        default=None, 
        foreign_key="image.image_id", 
        primary_key=True                 
    )
    
    file_bytes: bytes = Field(nullable=False)

    image_asset: ImageAsset = Relationship(back_populates="file_blob")
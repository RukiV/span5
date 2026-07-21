from enum import IntEnum
from typing import List, Optional

from pydantic import model_validator
from sqlmodel import Field, Relationship, SQLModel

from .base import Base


class ImageLimit(IntEnum):
    ASSET = 1
    STOCK = 1
    TICKET = 3
    JOB = 3


class ImageAssetBase(SQLModel):
    """Shared metadata for a single uploaded image file."""

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

    file_blob: "ImageBlob" = Relationship(
        back_populates="image_asset",
        sa_relationship_kwargs={"cascade": "all, delete-orphan", "uselist": False},
    )
    parent_links: List["ImageAssetLink"] = Relationship(
        back_populates="image_asset",
        sa_relationship_kwargs={"cascade": "all, delete-orphan"},
    )


class ImageAssetLinkBase(SQLModel):
    image_id: int = Field(foreign_key="image.image_id", index=True)
    parent_id: int = Field(index=True)
    parent_type: str = Field(index=True)
    display_order: int = Field(default=1)


class ImageAssetLink(ImageAssetLinkBase, Base, table=True):
    """Join table that links one image to one parent record context."""

    __tablename__: str = "image_link"

    link_id: Optional[int] = Field(default=None, primary_key=True)
    image_asset: Optional[ImageAsset] = Relationship(back_populates="parent_links")

    @model_validator(mode="after")
    def check_limits_by_type(self) -> "ImageAssetLink":
        clean_type = self.parent_type.upper()

        if clean_type not in ImageLimit.__members__:
            raise ValueError(f"Unsupported target entity type: '{self.parent_type}'")

        limit = ImageLimit[clean_type].value
        if self.display_order > limit or self.display_order < 1:
            raise ValueError(
                f"Invalid position slot '{self.display_order}' for entity '{self.parent_type}'. "
                f"Valid allowed limit range for '{self.parent_type}' is 1 to {limit}."
            )
        return self


class ImageBlob(SQLModel, table=True):
    """Isolated high-footprint binary table to keep queries fast."""

    __tablename__: str = "image_blobs"

    image_id: Optional[int] = Field(
        default=None,
        foreign_key="image.image_id",
        primary_key=True,
    )

    file_bytes: bytes = Field(nullable=False)
    image_asset: ImageAsset = Relationship(back_populates="file_blob")
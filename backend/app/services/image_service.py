from typing import List, Optional

from fastapi import HTTPException, UploadFile, status
from sqlmodel import Session, func, select

from ..models.image import ImageAsset, ImageAssetLink, ImageAssetUpdate, ImageBlob, ImageLimit


class ImageAssetService:
    def __init__(self, session: Session):
        self.session = session

    async def create(self, file: UploadFile, parent_id: int, parent_type: str, existing_image_id: Optional[int] = None) -> ImageAsset:
        clean_type = parent_type.upper()
        if clean_type not in ImageLimit.__members__:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported target entity type: '{parent_type}'",
            )

        if existing_image_id is not None:
            db_asset = self.session.get(ImageAsset, existing_image_id)
            if not db_asset:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image profile not found")
        else:
            file_content = await file.read()
            blob_data = ImageBlob(file_bytes=file_content)
            db_asset = ImageAsset(
                filename=file.filename or "unknown",
                mime_type=file.content_type or "application/octet-stream",
                size_bytes=len(file_content),
                file_blob=blob_data,
            )
            self.session.add(db_asset)

        if db_asset.image_id is None:
            self.session.flush()
            self.session.refresh(db_asset)

        self._attach_to_parent(db_asset.image_id, parent_id, parent_type.lower())
        self.session.commit()
        self.session.refresh(db_asset)
        return db_asset

    def attach_existing_image(self, image_id: int, parent_id: int, parent_type: str) -> ImageAsset:
        db_asset = self.session.get(ImageAsset, image_id)
        if not db_asset:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Image profile not found")

        self._attach_to_parent(db_asset.image_id, parent_id, parent_type.lower())
        self.session.commit()
        self.session.refresh(db_asset)
        return db_asset

    def _attach_to_parent(self, image_id: int, parent_id: int, parent_type: str) -> None:
        clean_type = parent_type.upper()
        if clean_type not in ImageLimit.__members__:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Unsupported target entity type: '{parent_type}'",
            )

        existing_link = self.session.exec(
            select(ImageAssetLink).where(
                ImageAssetLink.image_id == image_id,
                ImageAssetLink.parent_id == parent_id,
                ImageAssetLink.parent_type == parent_type.lower(),
            )
        ).first()
        if existing_link:
            return

        limit = ImageLimit[clean_type].value
        count_statement = select(func.count()).where(
            ImageAssetLink.parent_id == parent_id,
            ImageAssetLink.parent_type == parent_type.lower(),
        )
        current_count = self.session.exec(count_statement).one()

        if current_count >= limit:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Upload blocked. Max limit of {limit} reached for {parent_type} #{parent_id}.",
            )

        link = ImageAssetLink(
            image_id=image_id,
            parent_id=parent_id,
            parent_type=parent_type.lower(),
            display_order=current_count + 1,
        )
        self.session.add(link)

    def get_by_parent(self, parent_id: int, parent_type: str) -> List[ImageAsset]:
        """Queries image collections linked to a targeted ticket, asset, or stock item row."""
        statement = (
            select(ImageAsset)
            .join(ImageAssetLink, ImageAsset.image_id == ImageAssetLink.image_id)
            .where(
                ImageAssetLink.parent_id == parent_id,
                ImageAssetLink.parent_type == parent_type.lower(),
            )
            .order_by(ImageAssetLink.display_order.asc(), ImageAsset.image_id.asc())
        )
        return self.session.exec(statement).all()

    def get_by_id(self, image_id: int) -> Optional[ImageAsset]:
        return self.session.get(ImageAsset, image_id)

    def get_multi(self, skip: int = 0, limit: int = 100) -> List[ImageAsset]:
        statement = select(ImageAsset).offset(skip).limit(limit)
        return self.session.exec(statement).all()

    def get_raw_bytes(self, image_id: int) -> Optional[tuple[bytes, str]]:
        db_asset = self.get_by_id(image_id)
        if not db_asset or not db_asset.file_blob:
            return None
        return db_asset.file_blob.file_bytes, db_asset.mime_type

    def update(self, image_id: int, obj_in: ImageAssetUpdate) -> Optional[ImageAsset]:
        db_asset = self.get_by_id(image_id)
        if not db_asset:
            return None
        update_data = obj_in.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(db_asset, key, value)
        self.session.add(db_asset)
        self.session.commit()
        self.session.refresh(db_asset)
        return db_asset

    def delete(self, image_id: int) -> bool:
        db_asset = self.get_by_id(image_id)
        if not db_asset:
            return False
        self.session.delete(db_asset)
        self.session.commit()
        return True
from fastapi import UploadFile, HTTPException, status
from sqlmodel import Session, select
from typing import Optional, List
from ..models.image import ImageAsset, ImageBlob, ImageAssetUpdate

class ImageAssetService:
    def __init__(self, session: Session):
        self.session = session

    # CREATE: Saves both metadata and binary data together via relationships
    async def create(self, file: UploadFile) -> ImageAsset:
        file_content = await file.read()
        
        # Instantiate the child row holding bytes
        blob_data = ImageBlob(file_bytes=file_content)
        
        # Instantiate parent metadata row and attach the child blob
        db_asset = ImageAsset(
            filename=file.filename,
            mime_type=file.content_type,
            size_bytes=len(file_content),
            file_blob=blob_data  # SQLModel automatically sets up matching IDs
        )
        
        self.session.add(db_asset)
        self.session.commit()
        self.session.refresh(db_asset)
        return db_asset

    # READ METADATA: Fast lookup skipping binary data entirely
    def get_by_id(self, image_id: int) -> Optional[ImageAsset]:
        return self.session.get(ImageAsset, image_id)

    # READ ALL METADATA: Safe for bulk lists without RAM bloat
    def get_multi(self, skip: int = 0, limit: int = 100) -> List[ImageAsset]:
        statement = select(ImageAsset).offset(skip).limit(limit)
        return self.session.exec(statement).all()

    # READ BYTES: Explicitly triggers lazy-load of bytes for serving files
    def get_raw_bytes(self, image_id: int) -> Optional[tuple[bytes, str]]:
        db_asset = self.get_by_id(image_id)
        if not db_asset or not db_asset.file_blob:
            return None
        return db_asset.file_blob.file_bytes, db_asset.mime_type

    # UPDATE: Standard metadata update function
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

    # DELETE: Automatically purges metadata and binary row due to cascading settings
    def delete(self, image_id: int) -> bool:
        db_asset = self.get_by_id(image_id)
        if not db_asset:
            return False
            
        self.session.delete(db_asset)
        self.session.commit()
        return True
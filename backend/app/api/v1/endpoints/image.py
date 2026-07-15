from fastapi import APIRouter, Depends, UploadFile, Response, HTTPException, status
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession  # Your actual central session dependency
from ....models.image import ImageAssetRead, ImageAssetUpdate
from ....services.image_service import ImageAssetService

router = APIRouter(prefix="", tags=["images"])


# 1. UPLOAD IMAGE
@router.post("/", response_model=ImageAssetRead, status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile, 
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id) # Keeps endpoint secure
):
    # Enforce 10MB safety threshold to protect server RAM from OOM crashes
    MAX_FILE_SIZE = 10 * 1024 * 1024  
    if file.size and file.size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="File size exceeds the maximum allowed limit of 10MB."
        )

    service = ImageAssetService(session)
    return await service.create(file)


# 2. VIEW RAW IMAGE FILE IN BROWSER
@router.get("/{image_id}/file")
async def get_image_file(image_id: int, session=Depends(getSession)):
    service = ImageAssetService(session)
    result = service.get_raw_bytes(image_id)
    if not result:
        raise HTTPException(status_code=404, detail="Image file asset not found")
        
    raw_bytes, mime_type = result
    # Returns raw database bytes with proper formatting so browsers render it natively
    return Response(content=raw_bytes, media_type=mime_type)


# 3. GET IMAGE DETAILS/METADATA
@router.get("/{image_id}", response_model=ImageAssetRead)
def get_image_metadata(image_id: int, session=Depends(getSession)):
    service = ImageAssetService(session)
    db_asset = service.get_by_id(image_id)
    if not db_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return db_asset


# 4. LIST ALL IMAGES METADATA
@router.get("/", response_model=List[ImageAssetRead])
def list_images(skip: int = 0, limit: int = 100, session=Depends(getSession)):
    service = ImageAssetService(session)
    return service.get_multi(skip=skip, limit=limit)


# 5. UPDATE IMAGE METADATA
@router.patch("/{image_id}", response_model=ImageAssetRead)
def update_image_metadata(
    image_id: int, 
    payload: ImageAssetUpdate, 
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id)
):
    service = ImageAssetService(session)
    updated_asset = service.update(image_id, payload)
    if not updated_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return updated_asset


# 6. DELETE IMAGE AND BYTES
@router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_image(
    image_id: int, 
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id)
):
    service = ImageAssetService(session)
    if not service.delete(image_id):
        raise HTTPException(status_code=404, detail="Image target not found")
    return None
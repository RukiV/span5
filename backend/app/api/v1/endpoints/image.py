from typing import List

from fastapi import APIRouter, Depends, HTTPException, Response, UploadFile, status

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.image import ImageAssetRead, ImageAssetUpdate, ImageLimit
from ....services.image_service import ImageAssetService

router = APIRouter(prefix="", tags=["images"])


@router.get("/limits", status_code=status.HTTP_200_OK)
def get_image_limits():
    """Returns the maximum allowed image limits for all entity types."""
    return {item.name.lower(): item.value for item in ImageLimit}


@router.post("/", response_model=ImageAssetRead, status_code=status.HTTP_201_CREATED)
async def upload_image(
    parent_id: int,
    parent_type: str,
    file: UploadFile,
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id),
):
    clean_type = parent_type.upper()
    if clean_type not in ImageLimit.__members__:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported target entity type: '{parent_type}'",
        )

    MAX_FILE_SIZE = 10 * 1024 * 1024
    if file.size and file.size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File size exceeds the maximum allowed limit of 10MB.",
        )

    service = ImageAssetService(session)
    return await service.create(file, parent_id=parent_id, parent_type=parent_type.lower())


@router.post("/{image_id}/attach", response_model=ImageAssetRead)
def attach_existing_image(
    image_id: int,
    parent_id: int,
    parent_type: str,
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id),
):
    service = ImageAssetService(session)
    return service.attach_existing_image(image_id=image_id, parent_id=parent_id, parent_type=parent_type)


@router.get("/{image_id}/file")
async def get_image_file(image_id: int, session=Depends(getSession)):
    service = ImageAssetService(session)
    result = service.get_raw_bytes(image_id)
    if not result:
        raise HTTPException(status_code=404, detail="Image file asset not found")
    raw_bytes, mime_type = result
    return Response(content=raw_bytes, media_type=mime_type)


@router.get("/{image_id}", response_model=ImageAssetRead)
def get_image_metadata(image_id: int, session=Depends(getSession)):
    service = ImageAssetService(session)
    db_asset = service.get_by_id(image_id)
    if not db_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return db_asset


@router.get("/", response_model=List[ImageAssetRead])
def list_images(skip: int = 0, limit: int = 100, session=Depends(getSession)):
    service = ImageAssetService(session)
    return service.get_multi(skip=skip, limit=limit)


@router.get("/parent/{parent_type}/{parent_id}", response_model=List[ImageAssetRead])
def list_images_by_parent(parent_type: str, parent_id: int, session=Depends(getSession)):
    """Fetches ordered collections of image metadata for a given ticket, asset, or stock item."""
    clean_type = parent_type.upper()
    if clean_type not in ImageLimit.__members__:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported target entity type: '{parent_type}'",
        )
    service = ImageAssetService(session)
    return service.get_by_parent(parent_id, parent_type)


@router.patch("/{image_id}", response_model=ImageAssetRead)
def update_image_metadata(
    image_id: int,
    payload: ImageAssetUpdate,
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id),
):
    service = ImageAssetService(session)
    updated_asset = service.update(image_id, payload)
    if not updated_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return updated_asset


@router.delete("/{image_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_image(
    image_id: int,
    session=Depends(getSession),
    current_user_id: int = Depends(get_current_user_id),
):
    service = ImageAssetService(session)
    if not service.delete(image_id):
        raise HTTPException(status_code=404, detail="Image target not found")
    return None
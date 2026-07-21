from fastapi import APIRouter, Depends, UploadFile, Response, HTTPException, status
from typing import List

from ....auth.permissions import get_current_user, require_right, require_any_right
from ....db.database import getSession  # Your actual central session dependency
from ....models.image import ImageAssetRead, ImageAssetUpdate
from ....models.user import User
from ....services.image_service import ImageAssetService

router = APIRouter(prefix="", tags=["images"])


# 1. UPLOAD IMAGE
# Reachable by asset managers (assets.manage) AND by students attaching a photo
# to their own fault card (faults.create_own): the mobile fault-reporting flow
# uploads here before creating the Faultcard. Gating on assets.manage alone would
# break fault reporting for the one role that is supposed to have it.
@router.post("/", response_model=ImageAssetRead, status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile,
    session=Depends(getSession),
    _user: User = Depends(require_any_right("assets.manage", "faults.create_own")),
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
# Intentionally left UNAUTHENTICATED: this URL is consumed directly by browser
# <img src="..."> tags (see frontend imageAPI.getFileUrl) and Flutter
# Image.network, neither of which can attach an Authorization header. The bytes
# are non-enumerable by design (opaque integer id) and carry no PII. This is the
# one explicit anonymous-access opt-in in the image router.
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
def get_image_metadata(image_id: int, session=Depends(getSession), _user: User = Depends(get_current_user)):
    service = ImageAssetService(session)
    db_asset = service.get_by_id(image_id)
    if not db_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return db_asset


# 4. LIST ALL IMAGES METADATA
@router.get("/", response_model=List[ImageAssetRead])
def list_images(skip: int = 0, limit: int = 100, session=Depends(getSession), _user: User = Depends(require_right("assets.manage"))):
    service = ImageAssetService(session)
    return service.get_multi(skip=skip, limit=limit)


# 5. UPDATE IMAGE METADATA
@router.patch("/{image_id}", response_model=ImageAssetRead)
def update_image_metadata(
    image_id: int,
    payload: ImageAssetUpdate,
    session=Depends(getSession),
    _user: User = Depends(require_right("assets.manage")),
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
    _user: User = Depends(require_right("assets.manage")),
):
    service = ImageAssetService(session)
    if not service.delete(image_id):
        raise HTTPException(status_code=404, detail="Image target not found")
    return None

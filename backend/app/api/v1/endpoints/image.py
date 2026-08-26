from typing import List

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select

from ....auth.permissions import get_current_user, require_right, require_any_right, user_has_right
from ....db.database import getSession
from ....models.image import ImageAssetRead, ImageAssetUpdate, ImageAssetLink, ImageLimit
from ....models.job import Jobcard
from ....models.user import User
from ....services.image_service import ImageAssetService

router = APIRouter(prefix="", tags=["images"])


def _contractor_job_access(session: Session, user: User, parent_type: str, parent_id: int) -> bool:
    """Kontrakteurs mag slegs foto's by hul eie werksopdragte (parent_type 'job')
    voeg. Andersins word toegang geweier."""
    if (parent_type or "").lower() != "job":
        return False
    job = session.get(Jobcard, parent_id)
    return bool(job and job.contractor_id == user.user_id)


def _contractor_owns_linked_job(session: Session, user: User, image_id: int) -> bool:
    """Waar: die beeld is aan ten minste een werksopdrag gekoppel wat aan die
    kontrakteur behoort."""
    links = session.exec(select(ImageAssetLink).where(ImageAssetLink.image_id == image_id)).all()
    for link in links:
        if (link.parent_type or "").lower() != "job":
            continue
        job = session.get(Jobcard, link.parent_id)
        if job and job.contractor_id == user.user_id:
            return True
    return False


@router.get("/limits", status_code=status.HTTP_200_OK)
def get_image_limits(_user: User = Depends(get_current_user)):
    """Returns the maximum allowed image limits for all entity types."""
    return {item.name.lower(): item.value for item in ImageLimit}


# UPLOAD IMAGE
# Reachable by asset managers (assets.manage), by students attaching a photo to
# their own fault card (faults.create_own), AND by contractors attaching a photo
# to their own jobcard (jobs.update_own_status, scoped to own jobs below). The
# mobile fault-reporting flow uploads here before creating the Faultcard.
@router.post("/", response_model=ImageAssetRead, status_code=status.HTTP_201_CREATED)
async def upload_image(
    parent_id: int,
    parent_type: str,
    file: UploadFile,
    session=Depends(getSession),
    user: User = Depends(get_current_user),
):
    manage = user_has_right(session, user.role_id, "assets.manage")
    can_fault = user_has_right(session, user.role_id, "faults.create_own")
    can_job = user_has_right(session, user.role_id, "jobs.update_own_status")
    if not (manage or can_fault or can_job):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    if not manage and not can_fault:
        # Slegs-kontrakteur-pad: net eie werksopdragte.
        if not _contractor_job_access(session, user, parent_type, parent_id):
            raise HTTPException(status_code=403, detail="Contractors can only upload photos to their own jobs")
    clean_type = parent_type.upper()
    if clean_type not in ImageLimit.__members__:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported target entity type: '{parent_type}'",
        )
    # Let the service compress first and then validate size after compression.
    # This avoids rejecting images that become small after compression.
    service = ImageAssetService(session)
    return await service.create(file=file, parent_id=parent_id, parent_type=parent_type.lower())


@router.post("/{image_id}/attach", response_model=ImageAssetRead)
def attach_existing_image(
    image_id: int,
    parent_id: int,
    parent_type: str,
    session=Depends(getSession),
    _user: User = Depends(require_any_right("assets.manage", "faults.create_own")),
):
    service = ImageAssetService(session)
    return service.attach_existing_image(image_id=image_id, parent_id=parent_id, parent_type=parent_type)


# VIEW RAW IMAGE FILE IN BROWSER
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
    headers = {"Content-Disposition": f'inline; filename="image_{image_id}"'}
    return StreamingResponse(iter([raw_bytes]), media_type=mime_type or "application/octet-stream", headers=headers)


@router.get("/{image_id}", response_model=ImageAssetRead)
def get_image_metadata(image_id: int, session=Depends(getSession), _user: User = Depends(get_current_user)):
    service = ImageAssetService(session)
    db_asset = service.get_by_id(image_id)
    if not db_asset:
        raise HTTPException(status_code=404, detail="Image profile not found")
    return db_asset


@router.get("/", response_model=List[ImageAssetRead])
def list_images(skip: int = 0, limit: int = 100, session=Depends(getSession), _user: User = Depends(require_right("assets.manage"))):
    service = ImageAssetService(session)
    return service.get_multi(skip=skip, limit=limit)


@router.get("/parent/{parent_type}/{parent_id}", response_model=List[ImageAssetRead])
def list_images_by_parent(parent_type: str, parent_id: int, session=Depends(getSession), _user: User = Depends(get_current_user)):
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
    _user: User = Depends(require_right("assets.manage")),
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
    user: User = Depends(get_current_user),
):
    manage = user_has_right(session, user.role_id, "assets.manage")
    if not manage:
        # Kontrakteurs mag slegs foto's verwyder wat aan hul eie werksopdragte
        # gekoppel is (nodig om binne die 3-foto-perk te bly).
        can_job = user_has_right(session, user.role_id, "jobs.update_own_status")
        if not can_job or not _contractor_owns_linked_job(session, user, image_id):
            raise HTTPException(status_code=403, detail="Insufficient permissions")
    service = ImageAssetService(session)
    if not service.delete(image_id):
        raise HTTPException(status_code=404, detail="Image target not found")
    return None

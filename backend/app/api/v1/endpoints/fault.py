from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile, Form
from sqlmodel import Session
from typing import List, Optional
import os
import uuid

from ....db.database import getSession
from ....models.fault import FaultcardRead, FaultcardCreate, FaultcardUpdate
from ....services.fault_service import fault_service

router = APIRouter()

@router.get("", response_model=List[FaultcardRead])
def readFaults(session: Session = Depends(getSession)):
    #Fetch all faults
    return fault_service.getAll(session)

@router.get("/{faultID}", response_model=FaultcardRead)
def readFault(faultID: int, session: Session = Depends(getSession)):
    #Fetch single fault
    fault = fault_service.getByID(session, faultID)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return fault

@router.post("", response_model=FaultcardRead, status_code=status.HTTP_201_CREATED)
async def addFault(
    # --- MOBILE MULTIPART SUPPORT ---
    # These parameters use 'Form' and 'File' instead of 'Body'.
    # This is required so the mobile app can send both an image and report data in one request.
    # Note: If you change this back to a JSON Body, mobile image uploads will fail.
    fault_description: str = Form(...),
    asset_id: Optional[int] = Form(None),
    room_id: Optional[int] = Form(None),
    mappoint_id: Optional[int] = Form(None),
    fault_type: Optional[str] = Form(None),
    fault_priority: str = Form("medium"),
    user_id: Optional[int] = Form(None),
    image: Optional[UploadFile] = File(None),
    # --------------------------------
    session: Session = Depends(getSession)
):
    # Create the Create model
    faultIn = FaultcardCreate(
        fault_description=fault_description,
        asset_id=asset_id,
        room_id=room_id,
        mappoint_id=mappoint_id,
        fault_type=fault_type,
        fault_priority=fault_priority,
        user_id=user_id
    )

    if image:
        UPLOAD_DIR = "uploads"
        file_extension = os.path.splitext(image.filename)[1]
        filename = f"{uuid.uuid4()}{file_extension}"
        filepath = os.path.join(UPLOAD_DIR, filename)

        with open(filepath, "wb") as buffer:
            content = await image.read()
            buffer.write(content)

        faultIn.fault_image_url = f"/uploads/{filename}"

    #Create new fault
    return fault_service.create(session, faultIn)
    
@router.patch("/{faultID}", response_model=FaultcardRead)
def patchFault(faultID: int, faultIn: FaultcardUpdate, session: Session = Depends(getSession)):
    #Update existing fault
    fault = fault_service.update(session, faultID, faultIn)
    if not fault:
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return fault

@router.delete("/{faultID}", status_code=status.HTTP_204_NO_CONTENT)
def removeFault(faultID: int, session: Session = Depends(getSession)):
    #Delete fault
    if not fault_service.delete(session, faultID):
        raise HTTPException(status_code=404, detail="Fault not found")
    
    return None
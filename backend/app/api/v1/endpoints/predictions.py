from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.prediction import AssetPredictionRead
from ....models.user import User
from ....services.prediction_service import prediction_service

router = APIRouter()

@router.get("", response_model=List[AssetPredictionRead])
def readPredictions(session: Session = Depends(getSession), _user: User = Depends(require_right("predictions.view"))):
    return prediction_service.getPredictions(session)

@router.get("/{assetID}", response_model=AssetPredictionRead)
def readAssetPrediction(assetID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("predictions.view"))):
    pred = prediction_service.getAssetPrediction(session, assetID)
    if not pred:
        raise HTTPException(status_code=404, detail="Asset not found")
    return pred

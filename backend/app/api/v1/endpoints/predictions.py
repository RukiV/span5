from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import engine, getSession
from ....models.prediction import AssetPredictionRead
from ....models.user import User
from ....services import survival_service
from ....services.prediction_service import prediction_service

router = APIRouter()


@router.get("", response_model=List[AssetPredictionRead])
def readPredictions(
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("predictions.view")),
):
    return prediction_service.getPredictions(session)


@router.get("/model/status")
def readModelStatus(_user: User = Depends(require_right("predictions.view"))):
    """Status van die ML-survival-laag vir die Predictions-bladsy se modelstrook."""
    return survival_service.get_status()


@router.post("/model/retrain")
def retrainModel(_user: User = Depends(require_right("predictions.manage"))):
    """Forceer her-opleiding van die survival-model (kenmerk-/data-regstelling)."""
    return survival_service.force_retrain(engine)


class ModelEnabledIn(BaseModel):
    enabled: bool


@router.post("/model/enabled")
def setModelEnabled(
    payload: ModelEnabledIn,
    _user: User = Depends(require_right("predictions.manage")),
):
    """Skakel die survival-laag aan/af vir hierdie proses."""
    survival_service.set_enabled(payload.enabled)
    return survival_service.get_status()


@router.get("/{assetID}", response_model=AssetPredictionRead)
def readAssetPrediction(
    assetID: int,
    session: Session = Depends(getSession),
    _user: User = Depends(require_right("predictions.view")),
):
    pred = prediction_service.getAssetPrediction(session, assetID)
    if not pred:
        raise HTTPException(status_code=404, detail="Asset not found")
    return pred


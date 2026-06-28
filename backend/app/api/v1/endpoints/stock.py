from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.stock import StockRead, StockCreate, StockUpdate
from ....services.stock_service import stock_service

router = APIRouter()

@router.get("", response_model=List[StockRead])
def readStocks(session: Session = Depends(getSession)):
    #Fetch all stocks
    return stock_service.getAll(session)

@router.get("/{stockID}", response_model=StockRead)
def readStock(stockID: int, session: Session = Depends(getSession)):
    #Fetch single stock
    stock = stock_service.getByID(session, stockID)
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")

    return stock

@router.post("", response_model=StockRead, status_code=status.HTTP_201_CREATED)
def addStock(stockIn: StockCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new stock
    return stock_service.create(session, stockIn, user_id=user_id)

@router.patch("/{stockID}", response_model=StockRead)
def patchStock(stockID: int, stockIn: StockUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing stock
    stock = stock_service.update(session, stockID, stockIn, user_id=user_id)
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")

    return stock

@router.delete("/{stockID}", status_code=status.HTTP_204_NO_CONTENT)
def removeStock(stockID: int, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete stock
    if not stock_service.delete(session, stockID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Stock not found")

    return None
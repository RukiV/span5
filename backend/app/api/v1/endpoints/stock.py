from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.stock import StockRead, StockCreate, StockUpdate
from ....models.user import User
from ....services.stock_service import stock_service

router = APIRouter()

@router.get("", response_model=List[StockRead])
def readStocks(session: Session = Depends(getSession), _user: User = Depends(require_right("stock.manage"))):
    #Fetch all stocks
    return stock_service.getAll(session)

@router.get("/{stockID}", response_model=StockRead)
def readStock(stockID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("stock.manage"))):
    #Fetch single stock
    stock = stock_service.getByID(session, stockID)
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")

    return stock

@router.post("", response_model=StockRead, status_code=status.HTTP_201_CREATED)
def addStock(stockIn: StockCreate, session: Session = Depends(getSession), user: User = Depends(require_right("stock.manage"))):
    #Create new stock
    return stock_service.create(session, stockIn, user_id=user.user_id)

@router.patch("/{stockID}", response_model=StockRead)
def patchStock(stockID: int, stockIn: StockUpdate, session: Session = Depends(getSession), user: User = Depends(require_right("stock.manage"))):
    #Update existing stock
    stock = stock_service.update(session, stockID, stockIn, user_id=user.user_id)
    if not stock:
        raise HTTPException(status_code=404, detail="Stock not found")

    return stock

@router.delete("/{stockID}", status_code=status.HTTP_204_NO_CONTENT)
def removeStock(stockID: int, session: Session = Depends(getSession), user: User = Depends(require_right("stock.manage"))):
    #Delete stock
    if not stock_service.delete(session, stockID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Stock not found")

    return None

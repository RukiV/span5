from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.permissions import require_right
from ....db.database import getSession
from ....models.stock import StockRead, StockCreate, StockUpdate
from ....models.user import User
from ....services.stock_service import stock_service
from ....services.notification_service import NotificationService

router = APIRouter()

@router.get("", response_model=List[StockRead])
def readStocks(session: Session = Depends(getSession), _user: User = Depends(require_right("stock.view"))):
    #Fetch all stocks
    return stock_service.getAll(session)

@router.get("/{stockID}", response_model=StockRead)
def readStock(stockID: int, session: Session = Depends(getSession), _user: User = Depends(require_right("stock.view"))):
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

    if stock.stock_amount < stock.stock_minimum:
        notif_svc = NotificationService(session)
        if stock.room_id:
            from ....models.room import Room
            room = session.get(Room, stock.room_id)
            if room and room.building_id:
                from ....models.location import Building
                bld = session.get(Building, room.building_id)
                if bld and bld.location_id:
                    notif_svc.notify_location_users(
                        location_id=bld.location_id,
                        notification_type="stock.low",
                        title="Voorraad laag",
                        message=f"{stock.stock_name} ({stock.stock_amount}/{stock.stock_minimum}) is onder minimum",
                        actor_id=user.user_id,
                        reference_type="stock",
                        reference_id=stock.stock_id,
                    )

    return stock

@router.delete("/{stockID}", status_code=status.HTTP_204_NO_CONTENT)
def removeStock(stockID: int, session: Session = Depends(getSession), user: User = Depends(require_right("stock.manage"))):
    #Delete stock
    if not stock_service.delete(session, stockID, user_id=user.user_id):
        raise HTTPException(status_code=404, detail="Stock not found")

    return None

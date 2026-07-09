from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session
from typing import List

from ....auth.dependencies import get_current_user_id
from ....db.database import getSession
from ....models.quote import QuoteRead, QuoteCreate, QuoteUpdate
from ....services.quote_service import quote_service

router = APIRouter()

@router.get("", response_model=List[QuoteRead])
def readQuotes(session: Session = Depends(getSession)):
    #Fetch all quotes
    return quote_service.getAll(session)

@router.get("/{quoteID}", response_model=QuoteRead)
def readQuote(quoteID: int, session: Session = Depends(getSession)):
    #Fetch single quote by id
    quote = quote_service.getByID(session, quoteID)
    if not quote:
        raise HTTPException(status_code=404, detail="Quote not found")
    
    return quote

@router.post("", response_model=QuoteRead, status_code=status.HTTP_201_CREATED)
def addQuote(QuoteIn: QuoteCreate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Create new quote
    return quote_service.create(session, QuoteIn, user_id=user_id)

@router.patch("/{quoteID}", response_model=QuoteRead)
def patchQuote(quoteID: int, QuoteIn: QuoteUpdate, session: Session = Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Update existing quote
    quote = quote_service.update(session, quoteID, QuoteIn, user_id=user_id)
    if not quote:
        raise HTTPException(status_code=404, detail="Quote not found")
    
    return quote

@router.delete("/{quoteID}", status_code=status.HTTP_204_NO_CONTENT)
def removeQuote(quoteID: int, session: Session =Depends(getSession), user_id: int | None = Depends(get_current_user_id)):
    #Delete quote
    if not quote_service.delete(session, quoteID, user_id=user_id):
        raise HTTPException(status_code=404, detail="Quote not found")
    
    return None
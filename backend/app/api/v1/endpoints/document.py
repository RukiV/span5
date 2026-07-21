from typing import List

from fastapi import APIRouter, Depends, HTTPException, Response, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlmodel import Session

from ....db.database import getSession
from ....models.document import QuoteDocumentRead, QuoteDocumentUpdate
from ....services.document_service import QuoteDocumentService

router = APIRouter(prefix="", tags=["quote-documents"])


@router.post("/quotes/{quote_id}/documents", response_model=QuoteDocumentRead, status_code=status.HTTP_201_CREATED)
def upload_quote_document(
    quote_id: int,
    file: UploadFile,
    session: Session = Depends(getSession),
):
    service = QuoteDocumentService(session)
    return service.create(quote_id, file)


@router.get("/quotes/{quote_id}/documents", response_model=List[QuoteDocumentRead])
def list_quote_documents(quote_id: int, session: Session = Depends(getSession)):
    service = QuoteDocumentService(session)
    return service.get_by_quote(quote_id)


@router.get("/documents/{document_id}", response_model=QuoteDocumentRead)
def get_quote_document_metadata(document_id: int, session: Session = Depends(getSession)):
    service = QuoteDocumentService(session)
    document = service.get_by_id(document_id)
    if not document:
        raise HTTPException(status_code=404, detail="Quote document not found")
    return document


@router.get("/documents/{document_id}/file")
def get_quote_document_file(document_id: int, session: Session = Depends(getSession)):
    service = QuoteDocumentService(session)
    # Retrieve the document record so we can include filename in headers
    document = service.get_by_id(document_id)
    if not document:
        raise HTTPException(status_code=404, detail="Quote document not found")

    raw_bytes = document.file_bytes
    mime_type = document.mime_type or "application/octet-stream"

    # Use StreamingResponse so browsers handle binary PDFs correctly in Swagger and direct requests.
    headers = {"Content-Disposition": f'inline; filename="{document.filename}"'}
    return StreamingResponse(iter([raw_bytes]), media_type=mime_type, headers=headers)


@router.patch("/documents/{document_id}", response_model=QuoteDocumentRead)
def update_quote_document_metadata(
    document_id: int,
    payload: QuoteDocumentUpdate,
    session: Session = Depends(getSession),
):
    service = QuoteDocumentService(session)
    document = service.update(document_id, payload)
    if not document:
        raise HTTPException(status_code=404, detail="Quote document not found")
    return document


@router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quote_document(document_id: int, session: Session = Depends(getSession)):
    service = QuoteDocumentService(session)
    if not service.delete(document_id):
        raise HTTPException(status_code=404, detail="Quote document not found")
    return None

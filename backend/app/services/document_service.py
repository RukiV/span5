from typing import List, Optional

from fastapi import HTTPException, UploadFile, status
from sqlmodel import Session, select

from ..models.document import QuoteDocument, QuoteDocumentRead, QuoteDocumentUpdate


class QuoteDocumentService:
    MAX_PDF_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB
    PDF_MAGIC = b"%PDF"

    def __init__(self, session: Session):
        self.session = session

    def create(self, quote_id: int, file: UploadFile) -> QuoteDocument:
        if not quote_id:
            raise HTTPException(status_code=400, detail="quote_id is required")

        content = file.file.read() if file.file else b""
        if not content:
            raise HTTPException(status_code=400, detail="Uploaded file is empty")

        if len(content) > self.MAX_PDF_UPLOAD_SIZE:
            raise HTTPException(
                status_code=400,
                detail="PDF file exceeds the maximum allowed size of 10MB",
            )

        # Server-side content sniffing: verify the PDF header (%PDF) instead of
        # trusting the spoofable client-supplied Content-Type header.
        if not content[:4].startswith(self.PDF_MAGIC):
            raise HTTPException(status_code=400, detail="Only PDF files are supported")

        document = QuoteDocument(
            quote_id=quote_id,
            filename=file.filename or "quote.pdf",
            mime_type=file.content_type or "application/pdf",
            size_bytes=len(content),
            file_bytes=content,
        )
        self.session.add(document)
        self.session.commit()
        self.session.refresh(document)
        return document

    def get_by_quote(self, quote_id: int) -> List[QuoteDocument]:
        statement = select(QuoteDocument).where(QuoteDocument.quote_id == quote_id)
        return self.session.exec(statement).all()

    def get_by_id(self, document_id: int) -> Optional[QuoteDocument]:
        return self.session.get(QuoteDocument, document_id)

    def get_raw_bytes(self, document_id: int) -> Optional[tuple[bytes, str]]:
        document = self.get_by_id(document_id)
        if not document:
            return None
        return document.file_bytes, document.mime_type

    def update(self, document_id: int, payload: QuoteDocumentUpdate) -> Optional[QuoteDocument]:
        document = self.get_by_id(document_id)
        if not document:
            return None

        update_data = payload.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(document, key, value)

        self.session.add(document)
        self.session.commit()
        self.session.refresh(document)
        return document

    def delete(self, document_id: int) -> bool:
        document = self.get_by_id(document_id)
        if not document:
            return False

        self.session.delete(document)
        self.session.commit()
        return True

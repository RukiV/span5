from typing import Optional

from sqlmodel import Field, SQLModel

from .base import Base


class QuoteDocumentBase(SQLModel):
    """Metadata for a PDF document attached to a quote."""

    quote_id: int = Field(foreign_key="quote.quote_id", index=True)
    filename: str = Field(index=True)
    mime_type: str = Field(default="application/pdf")
    size_bytes: int


class QuoteDocument(QuoteDocumentBase, Base, table=True):
    """Stores uploaded quote PDFs as binary blobs."""

    __tablename__ = "quote_document"

    document_id: Optional[int] = Field(default=None, primary_key=True)
    file_bytes: bytes = Field(nullable=False)


class QuoteDocumentRead(QuoteDocumentBase):
    document_id: int


class QuoteDocumentUpdate(SQLModel):
    filename: Optional[str] = None

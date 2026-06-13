# models/validators.py
import re
import logging
from typing import Any
from pydantic import field_validator, model_validator

logger = logging.getLogger(__name__)

def sanitize_text(value: str) -> str:
    """Clean text: remove dangerous characters and whitespace."""
    if not isinstance(value, str):
        return value
    value = value.strip()
    value = re.sub(r'[\x00-\x1F\x7F]', '', value)           # control chars
    value = re.sub(r'[<>"\';{}()\[\]\\\\/]', '', value)     # harmful chars
    value = re.sub(r'\s+', ' ', value)                      # collapse spaces
    return value


@field_validator('*', mode='before')
def sanitize_all_strings(cls, v: Any, info) -> Any:
    """Automatically sanitize **every** string field in all models."""
    if isinstance(v, str):
        cleaned = sanitize_text(v)
        if cleaned != v:
            logger.warning(
                f"Sanitized input in {cls.__name__}.{info.field_name}: "
                f"'{v}' -> '{cleaned}'"
            )
        return cleaned
    return v


# Extra reusable validators (you can call these in model files)
def validate_email(v: str) -> str:
    if not re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', v):
        raise ValueError("Invalid email format")
    return v


def validate_phone(v: str) -> str:
    if v and not re.match(r'^\+?\d{7,15}$', v):
        raise ValueError("Invalid phone number format")
    return v


def validate_positive_int(v: int) -> int:
    if v is not None and v < 0:
        raise ValueError("Value must be positive or zero")
    return v
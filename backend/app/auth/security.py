import re
from passlib.context import CryptContext

pwd_context = CryptContext(
    schemes=["bcrypt", "pbkdf2_sha256"],
    deprecated="auto",
    bcrypt__rounds=12,
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not plain_password or not hashed_password:
        return False
    try:
        return pwd_context.verify(plain_password, hashed_password)
    except (ValueError, TypeError):
        return False


def is_hashed(value: str) -> bool:
    if not value:
        return False
    try:
        return pwd_context.identify(value) is not None
    except (ValueError, TypeError):
        return False


_MIN_LENGTH = 8
_MAX_LENGTH = 128

_PASSWORD_REQUIREMENTS = {
    "lower": r"[a-z]",
    "upper": r"[A-Z]",
    "digit": r"\d",
    "special": r"[!@#$%^&*(),.?\":{}|<>_\-+=\[\]\\';/`~]",
}


class PasswordError(Exception):
    ...


class PasswordTooShort(PasswordError):
    ...


class PasswordTooLong(PasswordError):
    ...


class PasswordMissingLowercase(PasswordError):
    ...


class PasswordMissingUppercase(PasswordError):
    ...


class PasswordMissingDigit(PasswordError):
    ...


class PasswordMissingSpecial(PasswordError):
    ...


def validate_password_strength(password: str) -> None:
    if len(password) < _MIN_LENGTH:
        raise PasswordTooShort(
            f"Password must be at least {_MIN_LENGTH} characters long"
        )
    if len(password) > _MAX_LENGTH:
        raise PasswordTooLong(
            f"Password must be at most {_MAX_LENGTH} characters long"
        )
    if not re.search(_PASSWORD_REQUIREMENTS["lower"], password):
        raise PasswordMissingLowercase(
            "Password must contain at least one lowercase letter"
        )
    if not re.search(_PASSWORD_REQUIREMENTS["upper"], password):
        raise PasswordMissingUppercase(
            "Password must contain at least one uppercase letter"
        )
    if not re.search(_PASSWORD_REQUIREMENTS["digit"], password):
        raise PasswordMissingDigit(
            "Password must contain at least one digit"
        )
    if not re.search(_PASSWORD_REQUIREMENTS["special"], password):
        raise PasswordMissingSpecial(
            "Password must contain at least one special character"
        )

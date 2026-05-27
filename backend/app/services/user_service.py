from ..models.user import User, UserCreate, UserUpdate
from .base_service import BaseService

user_service = BaseService[User, UserCreate, UserUpdate](User)
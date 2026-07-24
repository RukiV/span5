from ..models.asset import Assettype, AssettypeCreate, AssettypeUpdate
from .base_service import BaseService

assettype_service = BaseService[Assettype, AssettypeCreate, AssettypeUpdate](Assettype)

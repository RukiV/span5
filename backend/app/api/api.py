from fastapi import APIRouter
from .v1.endpoints import assets, room, location, fault, job

api_router = APIRouter(redirect_slashes=False)

api_router.include_router(assets.router, prefix="/assets", tags=["Assets"])
api_router.include_router(room.router, prefix="/rooms", tags=["Room"])
api_router.include_router(location.router, prefix="/location", tags=["Location"])
api_router.include_router(fault.router, prefix="/fault", tags=["Fault"])
api_router.include_router(job.router, prefix="/job", tags=["Job"])
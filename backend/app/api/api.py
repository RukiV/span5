from fastapi import APIRouter
from .v1.endpoints import assets, assettype, room, location, building, fault, job, stock, auth, user, contractor, quote, audit, predictions, image, calendar, role, rights, document

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(assets.router, prefix="/assets", tags=["assets"])
api_router.include_router(assettype.router, prefix="/assettypes", tags=["assettypes"])
api_router.include_router(room.router, prefix="/rooms", tags=["rooms"])
api_router.include_router(location.router, prefix="/location", tags=["location"])
api_router.include_router(building.router, prefix="/building", tags=["building"])
api_router.include_router(fault.router, prefix="/fault", tags=["fault"])
api_router.include_router(job.router, prefix="/job", tags=["job"])
api_router.include_router(stock.router, prefix="/stock", tags=["stock"])
api_router.include_router(user.router, prefix="/users", tags=["users"])
api_router.include_router(role.router, prefix="/roles", tags=["roles"])
api_router.include_router(rights.router, prefix="/rights", tags=["rights"])
api_router.include_router(contractor.router, prefix="/contractors", tags=["contractors"])
api_router.include_router(quote.router, prefix="/quotes", tags=["quotes"])
api_router.include_router(audit.router, prefix="/audit", tags=["audit"])
api_router.include_router(predictions.router, prefix="/predictions", tags=["predictions"])
api_router.include_router(image.router, prefix="/image", tags=["image"])
api_router.include_router(document.router, prefix="", tags=["documents"])
api_router.include_router(calendar.router, prefix="/calendar", tags=["calendar"])

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
import os

import asyncio
from .api.api import api_router
from .db.database import createDBandTables, engine, purge_expired_revoked_tokens
from .db.seed import seed_data
from .services import auto_draft_scheduler, survival_service
from .services.reminder_scheduler import reminder_loop

from .middleware.idempotency import IdempotencyMiddleware
from .middleware.security_headers import add_security_headers

app = FastAPI(
    title="FBS Facility Management API", 
    version="1.0.0"
)

# --- MOBILE ASSET HOSTING ---
# This section ensures that images uploaded from the mobile app are stored
# locally on the server and served via a public URL.
#
# How it works:
# 1. We define an 'uploads' directory.
# 2. We 'mount' it so that http://server-ip:8000/uploads/file.jpg becomes accessible.
#
# FUTURE IMPROVEMENT: In production, consider moving this to a dedicated
# storage provider like AWS S3 or Azure Blob Storage.
UPLOAD_DIR = "uploads"
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
# ----------------------------

@app.on_event("startup")
async def onStartup():
    createDBandTables()

    seed_data()

    # Survival layer (Phase 2c): train/load on boot when the data has enough
    # signal. Guarded off for tests (tests use their own in-memory engine).
    if os.getenv("ENVIRONMENT", "development") != "test":
        asyncio.create_task(asyncio.to_thread(survival_service.maybe_train, engine))

    asyncio.create_task(reminder_loop())

    if auto_draft_scheduler.AI_AUTO_DRAFT_ENABLED:
        asyncio.create_task(auto_draft_scheduler.auto_draft_loop())

    if survival_service.is_enabled():
        asyncio.create_task(survival_service.maybe_retrain_loop())

origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://frontend:3000",
    "https://localhost",
    "https://localhost:443",
    "https://127.0.0.1",
    "http://localhost",
    "http://127.0.0.1",
]

# =============================================================================
# DEBUG: Maak CORS oop vir alle bronne sodat die fisiese selfoon nie deur
# die blaaier se sekuriteitsreëls geblokkeer word tydens toetsing op WiFi nie.
# =============================================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# =============================================================================

# Security headers middleware
app.add_middleware(BaseHTTPMiddleware, dispatch=add_security_headers)

# Idempotency middleware — prevents duplicate POST submissions.
# Must be added AFTER CORS so it runs inside CORS (outermost = first).
app.add_middleware(IdempotencyMiddleware)

app.include_router(api_router, prefix="/api/v1")

@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "message": "API is running"
    }
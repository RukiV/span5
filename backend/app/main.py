from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

import asyncio
from .api.api import api_router
from .db.database import createDBandTables
from .db.seed import seed_data
from .services.reminder_scheduler import reminder_loop

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

    asyncio.create_task(reminder_loop())

origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://frontend:3000",
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

app.include_router(api_router, prefix="/api/v1")

@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "message": "API is running"
    }
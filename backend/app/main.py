from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.api import api_router
from .db.database import createDBandTables
from .db.seed import seed_data

app = FastAPI(
    title="FBS Facility Management API", 
    version="1.0.0"
)

@app.on_event("startup")
def onStartup():
    createDBandTables()

    seed_data()
#ports

origins = [ 
    "http://localhost:3000", 
    "http://frontend:3000"
]

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")

@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "message": "API is running"
    }
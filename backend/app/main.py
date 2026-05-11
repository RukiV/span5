from fastapi import FastAPI
from api.v1.endpoints import assets

app = FastAPI(title="Eh")

app.include_router(assets.router, prefix="/assets", tags=["Assets"])

@app.get("/")
def root():
    return {"message": "API is running"}
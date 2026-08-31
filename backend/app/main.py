from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware
import os

from .api.api import api_router
from .db.database import createDBandTables, engine, purge_expired_revoked_tokens
from .db.seed import seed_data
<<<<<<< HEAD
from .services import auto_draft_scheduler, survival_service
from .services.reminder_scheduler import reminder_loop
=======
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

from .middleware.idempotency import IdempotencyMiddleware
from .middleware.security_headers import add_security_headers
from .middleware.rate_limit import limiter
from .middleware.datetimes import UtcDatetimeMiddleware
from .auth.security import PasswordError

app = FastAPI(
    title="FBS Facility Management API", 
    version="1.0.0"
)

@app.exception_handler(PasswordError)
async def password_error_handler(request, exc):
    return JSONResponse(
        status_code=422,
        content={
            "detail": (
                "Wagwoord voldoen nie aan die vereistes nie: moet ten minste 8 "
                "karakters lank wees, een hoofletter, een syfer en een simbool bevat."
            )
        },
    )

_ENV = os.getenv("ENVIRONMENT", "development").strip().lower()
_is_prod = _ENV not in {"development", "dev", "local", "test", "testing"}

if _ENV not in {"test", "testing"}:
    from slowapi.errors import RateLimitExceeded
    from slowapi.middleware import SlowAPIMiddleware
    from slowapi import _rate_limit_exceeded_handler

    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
    app.add_middleware(SlowAPIMiddleware)

# Tag naive (UTC) datetimes in JSON responses with an explicit "Z" so clients in
# any timezone render the correct local time (10:00 UTC -> 12:00 for a UTC+2 user).
app.add_middleware(UtcDatetimeMiddleware)

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
def onStartup():
    createDBandTables()

    seed_data()
<<<<<<< HEAD

    # Log scheduler configuration for debugging
    import logging
    logger = logging.getLogger(__name__)
    logger.info("=" * 60)
    logger.info("BACKGROUND SCHEDULER CONFIGURATION")
    logger.info("=" * 60)
    logger.info(f"Reminder scheduler:       interval={os.getenv('REMINDER_CHECK_INTERVAL', '60')}s")
    logger.info(f"Auto-draft scheduler:     enabled={auto_draft_scheduler.AI_AUTO_DRAFT_ENABLED}, "
                f"interval={auto_draft_scheduler.AI_AUTO_DRAFT_INTERVAL}s "
                f"(min={auto_draft_scheduler.MIN_AUTO_DRAFT_INTERVAL}s)")
    logger.info(f"Survival retrain loop:    enabled={survival_service.is_enabled()}, "
                f"interval={os.getenv('SURVIVAL_RETRAIN_INTERVAL', '900')}s")
    logger.info(f"Survival min assets:      {os.getenv('AI_SURVIVAL_MIN_ASSETS', '50')}")
    logger.info(f"Survival min events:      {os.getenv('AI_SURVIVAL_MIN_EVENTS', '80')}")
    logger.info("=" * 60)

    # Survival layer (Phase 2c): train/load on boot when the data has enough
    # signal. Guarded off for tests (tests use their own in-memory engine).
    if os.getenv("ENVIRONMENT", "development") != "test":
        asyncio.create_task(asyncio.to_thread(survival_service.maybe_train, engine))

    asyncio.create_task(reminder_loop())
=======
#ports
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

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
# MIDDLEWARE STACK (outermost runs first on incoming requests):
#
#   1. CORSMiddleware          (OUTERMOST — runs first)
#   2. security_headers        (middle)
#   3. IdempotencyMiddleware   (INNERMOST — runs last, closest to route handler)
#
# Starlette app.add_middleware() builds a stack: each call WRAPS the previous
# one, so the LAST call becomes the OUTERMOST layer. CORSMiddleware MUST be
# outermost so it intercepts OPTIONS preflight requests before any other
# middleware can touch them.
#
# In production the origin list is explicit; in development any origin is
# allowed (credentials still protected by Bearer tokens).
# =============================================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if _is_prod else ["*"],
    allow_origin_regex=None if _is_prod else ".*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security headers middleware
app.add_middleware(BaseHTTPMiddleware, dispatch=add_security_headers)

# Idempotency middleware — prevents duplicate POST submissions.
# Runs INSIDE CORS (innermost), so OPTIONS preflights are handled by CORS first.
app.add_middleware(IdempotencyMiddleware)

app.include_router(api_router, prefix="/api/v1")

@app.get("/", tags=["Health"])
def root():
    return {
        "status": "online",
        "message": "API is running"
    }
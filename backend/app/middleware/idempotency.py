import json
from datetime import datetime

from fastapi import Request, Response
from sqlmodel import Session, select
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from ..db.database import engine as _prod_engine
from ..models.idempotency import IdempotencyRecord
from ..services.idempotency_service import (
    compute_key_hash,
    try_claim,
    get_cached,
    complete,
    release,
)

# If a claim record was created longer than this many seconds ago and still
# has no response, it is considered stale (the original request was aborted
# or the server crashed before completing).  The lock is released so that
# a subsequent request can proceed instead of seeing a permanent 409.
STALE_LOCK_SECONDS = 30


def _fetch_any_record(session: Session, key_hash: str):
    """Fetch idempotency record by key_hash even if it has no response yet."""
    return session.exec(
        select(IdempotencyRecord).where(IdempotencyRecord.key_hash == key_hash)
    ).first()


def _resolve_engine(request: Request):
    """Use test engine if set via ``app.state.idempotency_engine``.

    This lets the test suite inject a SQLite engine without the middleware
    needing to know about dependency overrides.
    """
    return getattr(request.app.state, "idempotency_engine", None) or _prod_engine


class IdempotencyMiddleware(BaseHTTPMiddleware):
    """Prevent duplicate POST requests by caching successful responses.

    Only **2xx** responses are cached. Auth errors (401 / 403) are never
    stored so that different users with different permissions can each
    get the correct response.

    How it works
    ------------
    1. Compute the dedup key:
       - If an ``X-Idempotency-Key`` header is present, it is used as the
         dedup key (``sha256(method + ":" + path + ":" + key)``).  This
         survives body changes, so clients can retry the same logical
         request even when the body differs (e.g. a ``new Date().toISOString()``
         timestamp injected on every click).
       - Otherwise fall back to ``sha256(method + ":" + path + ":" + body)``.
    2. Try to INSERT a record with that hash (DB unique constraint =
       distributed lock).
    3. INSERT succeeds -> this is the **first** request -> let it through.
       After the handler finishes, cache the response **only if 2xx**.
    4. INSERT fails (duplicate) -> another request is or was processing the
       same payload.
       a. If a *completed* 2xx response exists -> **return cached**.
       b. If still processing (no response yet) -> **return 409 Conflict**
          (the client can retry).
       c. If previously failed (non-2xx / 5xx) -> **release the lock** and
          let the new request retry.

    Only ``POST`` endpoints known to be non-idempotent are intercepted.
    GET / PUT / DELETE / PATCH are left alone.
    """

    # Prefix whitelist — only POST endpoints that CREATE resources or trigger
    # side-effects are idempotent-protected.  Auth, roles/rights management,
    # and file uploads are excluded because their responses vary per user or
    # request body type.
    IDEMPOTENT_PREFIXES = {
        "/api/v1/job",
        "/api/v1/fault",
        "/api/v1/assets",
        "/api/v1/assettypes",
        "/api/v1/stock",
        "/api/v1/rooms",
        "/api/v1/building",
        "/api/v1/location",
        "/api/v1/contractors",
        "/api/v1/quotes",
        "/api/v1/users",
        "/api/v1/calendar",
        "/api/v1/room-checks",
        # /api/v1/ai is deliberately NOT idempotent-protected: the dedup key
        # hashes (method, path, body) without the user, so two students
        # submitting identical free text would collide and one would receive
        # the other's draft. Draft creation is cheap and the FK/Admin review
        # actions are governed by the draft's own state (409 "already
        # reviewed"), so the business logic owns double-submit handling here.
    }

    @staticmethod
    def _should_idempotent(path: str) -> bool:
        return any(path.startswith(p) for p in IdempotencyMiddleware.IDEMPOTENT_PREFIXES)

    async def dispatch(self, request: Request, call_next):
        if request.method != "POST":
            return await call_next(request)

        path = str(request.url.path)
        if not self._should_idempotent(path):
            return await call_next(request)

        # --- 1. Read & restore the request body ---
        body = await request.body()

        async def receive():
            return {"type": "http.request", "body": body, "more_body": False}

        request._receive = receive

        # --- 1b. Determine the dedup key ---
        # If the client supplies an X-Idempotency-Key header, prefer it as the
        # dedup key (method + path + key) so retries of the same logical
        # request are deduplicated even if the body changed between attempts.
        # Otherwise fall back to hashing the raw body.
        idempotency_key = request.headers.get("X-Idempotency-Key")
        if idempotency_key:
            key_hash = compute_key_hash(request.method, path, idempotency_key.encode())
        else:
            key_hash = compute_key_hash(request.method, path, body)
        engine = _resolve_engine(request)

        # --- 2. Try to claim this hash ---
        with Session(engine) as session:
            claimed = try_claim(session, key_hash, request.method, path)

        if not claimed:
            # Another request already claimed or a stale record exists
            with Session(engine) as session:
                cached = get_cached(session, key_hash)

            if cached and cached.response_status is not None:
                if 200 <= cached.response_status < 300:
                    # Return the cached response
                    content = (
                        json.loads(cached.response_body)
                        if cached.response_body
                        else {}
                    )
                    return JSONResponse(
                        content=content,
                        status_code=cached.response_status,
                        headers={"X-Idempotent-Replay": "true"},
                    )

                # Previously failed (non-2xx) -> release the stale record
                # and retry the claim so this request can proceed fresh.
                with Session(engine) as session:
                    release(session, key_hash)

                with Session(engine) as session:
                    claimed = try_claim(session, key_hash, request.method, path)

                if claimed:
                    # Successfully re-claimed after releasing stale lock
                    pass  # fall through to the processing block below
                else:
                    # Still racing — someone else grabbed it first
                    return JSONResponse(
                        content={
                            "detail": "Hierdie versoek word reeds verwerk. "
                            "Wag asseblief en probeer weer."
                        },
                        status_code=409,
                        headers={"X-Idempotent-Key": key_hash},
                    )
            else:
                # cached is None or has no response_status yet.
                # Check whether there is a *stale* lock with response_status=None
                # that was never released (aborted request, etc.).
                with Session(engine) as session:
                    stale = _fetch_any_record(session, key_hash)
                if stale and stale.response_status is None:
                    age = (datetime.utcnow() - stale.created_at).total_seconds()
                    if age > STALE_LOCK_SECONDS:
                        # Stale lock — release and let this request proceed
                        with Session(engine) as session:
                            release(session, key_hash)
                        with Session(engine) as session:
                            claimed = try_claim(session, key_hash, request.method, path)
                        if claimed:
                            pass
                        else:
                            return JSONResponse(
                                content={
                                    "detail": "Hierdie versoek word reeds verwerk. "
                                    "Wag asseblief en probeer weer."
                                },
                                status_code=409,
                                headers={"X-Idempotent-Key": key_hash},
                            )
                    else:
                        # Genuinely still processing — keep 409
                        return JSONResponse(
                            content={
                                "detail": "Hierdie versoek word reeds verwerk. "
                                "Wag asseblief en probeer weer."
                            },
                            status_code=409,
                            headers={"X-Idempotent-Key": key_hash},
                        )
                else:
                    # No record at all, or a completed record that get_cached
                    # somehow missed — treat as still processing
                    return JSONResponse(
                        content={
                            "detail": "Hierdie versoek word reeds verwerk. "
                            "Wag asseblief en probeer weer."
                        },
                        status_code=409,
                        headers={"X-Idempotent-Key": key_hash},
                    )

        # --- 3. First claim --- process the request ---
        try:
            response = await call_next(request)

            # Collect response body *before* the stream is consumed
            resp_body = b""
            async for chunk in response.body_iterator:
                resp_body += chunk

            if 200 <= response.status_code < 300:
                with Session(engine) as session:
                    complete(
                        session,
                        key_hash,
                        response.status_code,
                        resp_body.decode("utf-8"),
                    )
            else:
                # Non-2xx → release the lock so subsequent requests can retry
                with Session(engine) as session:
                    release(session, key_hash)

            # Return a new response with the collected body
            return Response(
                content=resp_body,
                status_code=response.status_code,
                headers=dict(response.headers),
                media_type=response.media_type,
            )
        except Exception:
            # Release the lock so subsequent retries can proceed
            with Session(engine) as session:
                release(session, key_hash)
            raise

"""HTTP security headers middleware.

Adds defense-in-depth headers to every response (including 4xx/5xx). Shared by
the production app (app/main.py) and the pytest TestClient so tests exercise the
same guarantee shipped in production.
"""

from starlette.requests import Request

_SECURITY_HEADERS = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "Cache-Control": "no-store",
}


async def add_security_headers(request: Request, call_next):
    """Set security headers on the response produced by the downstream app."""
    response = await call_next(request)
    for name, value in _SECURITY_HEADERS.items():
        response.headers[name] = value
    return response

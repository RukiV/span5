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
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
}

#: FastAPI's auto-generated interactive docs (Swagger UI / ReDoc) load their
#: CSS/JS from public CDNs and run an inline bootstrap <script>. The strict
#: ``default-src 'none'`` CSP blocks all of that and renders these pages blank.
#: They are dev-facing tooling, not API data endpoints, so we exempt them (and
#: their asset/redirect sub-paths) from the CSP while keeping every other
#: security header intact. All real API routes keep the strict CSP.
_DOCS_PATHS = ("/docs", "/redoc")


async def add_security_headers(request: Request, call_next):
    """Set security headers on the response produced by the downstream app."""
    response = await call_next(request)
    for name, value in _SECURITY_HEADERS.items():
        if (
            name == "Content-Security-Policy"
            and request.url.path.startswith(_DOCS_PATHS)
        ):
            continue
        response.headers[name] = value
    return response

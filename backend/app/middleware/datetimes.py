import re
import json

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response


# Datetimes are written to the DB as naive UTC. Pydantic v2 serialises a naive
# datetime without any offset (e.g. "2026-08-28T10:00:00"), which clients then
# misinterpret as *local* time. This middleware tags every naive ISO datetime in a
# JSON response body as UTC by appending "Z", so a UTC+2 user sees 10:00 UTC as 12:00.
_NAIVE_DATETIME = re.compile(
    r'(?<!\d)(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?)(?!Z|[+-]\d{2}:?\d{2})'
)


def _tag_utc(body: str) -> str:
    return _NAIVE_DATETIME.sub(r"\1Z", body)


class UtcDatetimeMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        content_type = response.headers.get("content-type", "")
        if "application/json" not in content_type:
            return response
        if response.status_code in (204, 304):
            return response

        body = b"".join([chunk async for chunk in response.body_iterator])
        if not body:
            return response

        text = body.decode("utf-8", errors="ignore")
        tagged = _tag_utc(text)
        headers = dict(response.headers)
        headers.pop("content-length", None)
        if tagged != text:
            return Response(
                content=tagged.encode("utf-8"),
                status_code=response.status_code,
                headers=headers,
                media_type="application/json",
            )
        return Response(
            content=body,
            status_code=response.status_code,
            headers=headers,
            media_type="application/json",
        )

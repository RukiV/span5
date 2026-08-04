"""Idempotency middleware tests.

Regression tests for the "spam-click on Stoor Kaart creates duplicate jobcards"
bug.  The middleware dedupes on ``sha256(method + path + body)`` by default, but
the web frontend injects a fresh ``new Date().toISOString()`` into
``job_createddatetime`` / ``job_scheduled_datetime`` on every click — so every
spam-click had a different body hash and dedup never triggered.

The fix: if the client sends an ``X-Idempotency-Key`` header, the middleware
keys on ``method + path + key`` instead of the body, so retries of the same
logical request are deduplicated even with different bodies.

These tests verify:
  1. Same key + different bodies -> single jobcard (the bug scenario).
  2. No header + identical bodies -> still deduped (legacy body-hash path).
  3. Different keys -> two jobcards (no over-dedup).
"""

from sqlmodel import Session, select, func

from app.models.job import Jobcard


API = "/api/v1"

JOB_BODY_A = {"job_desc": "idempotency test job A"}
JOB_BODY_B = {"job_desc": "idempotency test job B"}


def _count_jobs_by_desc(engine, job_desc: str) -> int:
    """Count jobcards whose job_desc matches exactly."""
    with Session(engine) as session:
        return session.exec(
            select(func.count())
            .select_from(Jobcard)
            .where(Jobcard.job_desc == job_desc)
        ).one()


def test_post_with_same_idempotency_key_creates_single_record(client, headers_for, engine):
    """The bug scenario: same X-Idempotency-Key but DIFFERENT bodies must only
    create one jobcard — the second request is served from the cached response."""
    h = headers_for("admin")

    resp1 = client.post(f"{API}/job", json=JOB_BODY_A, headers={**h, "X-Idempotency-Key": "key-1"})
    assert resp1.status_code == 201, resp1.text
    assert resp1.headers.get("X-Idempotent-Replay") is None
    first_id = resp1.json()["jobcard_id"]

    # Different body (simulates a fresh timestamp injected on every click),
    # same idempotency key -> must be a replay, not a new jobcard.
    resp2 = client.post(f"{API}/job", json=JOB_BODY_B, headers={**h, "X-Idempotency-Key": "key-1"})
    assert resp2.status_code == 201, resp2.text
    assert resp2.headers.get("X-Idempotent-Replay") == "true"
    assert resp2.json()["jobcard_id"] == first_id

    assert _count_jobs_by_desc(engine, JOB_BODY_A["job_desc"]) == 1
    assert _count_jobs_by_desc(engine, JOB_BODY_B["job_desc"]) == 0


def test_post_without_header_identical_body_dedupes(client, headers_for, engine):
    """No header + identical body -> the legacy body-hash path still dedupes."""
    h = headers_for("admin")

    resp1 = client.post(f"{API}/job", json=JOB_BODY_A, headers=h)
    assert resp1.status_code == 201, resp1.text
    assert resp1.headers.get("X-Idempotent-Replay") is None
    first_id = resp1.json()["jobcard_id"]

    resp2 = client.post(f"{API}/job", json=JOB_BODY_A, headers=h)
    assert resp2.status_code == 201, resp2.text
    assert resp2.headers.get("X-Idempotent-Replay") == "true"
    assert resp2.json()["jobcard_id"] == first_id

    assert _count_jobs_by_desc(engine, JOB_BODY_A["job_desc"]) == 1


def test_different_keys_create_two_records(client, headers_for, engine):
    """Different X-Idempotency-Keys are distinct logical requests -> two jobcards."""
    h = headers_for("admin")

    resp1 = client.post(f"{API}/job", json=JOB_BODY_A, headers={**h, "X-Idempotency-Key": "key-a"})
    assert resp1.status_code == 201, resp1.text
    assert resp1.headers.get("X-Idempotent-Replay") is None

    resp2 = client.post(f"{API}/job", json=JOB_BODY_B, headers={**h, "X-Idempotency-Key": "key-b"})
    assert resp2.status_code == 201, resp2.text
    assert resp2.headers.get("X-Idempotent-Replay") is None

    assert _count_jobs_by_desc(engine, JOB_BODY_A["job_desc"]) == 1
    assert _count_jobs_by_desc(engine, JOB_BODY_B["job_desc"]) == 1

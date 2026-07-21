"""Authorization matrix tests.

Covers, for a fully anonymous caller plus each of the 4 roles, the expected
status code on representative routes for every resource — the regression test
for the critical "unauthenticated writes" bug and the enforcement of the target
permission matrix.
"""

import os
import subprocess
import sys

from sqlmodel import Session, select, func

from app.auth.security import is_hashed, verify_password
from app.models.user import User


API = "/api/v1"

# A valid body for each write endpoint we probe, so the ONLY possible failure is
# authorization (never a 422 from body validation).
NEW_USER_BODY = {
    "user_name": "Mallory",
    "user_surname": "Attacker",
    "user_email": "mallory@evil.local",
    "user_password": "supersecret1",
    "user_status": "active",
    "role_id": 3,  # tries to self-create an admin
}
NEW_FAULT_BODY = {"fault_description": "leaking tap"}
NEW_JOB_BODY = {"job_desc": "fix the tap"}
NEW_ASSET_BODY = {
    "asset_name": "Drill",
    "asset_brand": "Bosch",
    "asset_serial": "SER-TEST-1",
    "asset_status": "active",
    "asset_isoutdoor": False,
    "assettype_id": 1,
}


# --------------------------------------------------------------------------
# Anonymous
# --------------------------------------------------------------------------

ANON_ENDPOINTS = [
    ("get", f"{API}/users", None),
    ("get", f"{API}/assets", None),
    ("get", f"{API}/stock", None),
    ("get", f"{API}/building", None),
    ("get", f"{API}/rooms", None),
    ("get", f"{API}/location", None),
    ("get", f"{API}/contractors", None),
    ("get", f"{API}/quotes", None),
    ("get", f"{API}/predictions", None),
    ("get", f"{API}/audit", None),
    ("get", f"{API}/fault", None),
    ("get", f"{API}/job", None),
    ("get", f"{API}/image/", None),
    ("post", f"{API}/users", NEW_USER_BODY),
    ("post", f"{API}/assets", NEW_ASSET_BODY),
    ("post", f"{API}/fault", NEW_FAULT_BODY),
    ("post", f"{API}/job", NEW_JOB_BODY),
]


def test_anonymous_gets_401_everywhere(client):
    for method, path, body in ANON_ENDPOINTS:
        if method == "get":
            resp = client.get(path)
        else:
            resp = getattr(client, method)(path, json=body)
        assert resp.status_code == 401, f"{method.upper()} {path} -> {resp.status_code}"


def test_anonymous_write_has_no_side_effects(client, engine):
    """The critical regression: anonymous POST /users must not create a user."""
    with Session(engine) as session:
        before = session.exec(select(func.count()).select_from(User)).one()

    resp = client.post(f"{API}/users", json=NEW_USER_BODY)
    assert resp.status_code == 401

    with Session(engine) as session:
        after = session.exec(select(func.count()).select_from(User)).one()
    assert after == before


# --------------------------------------------------------------------------
# Student — mobile only, own fault cards only
# --------------------------------------------------------------------------

def test_student_can_read_and_create_own_faults(client, headers_for):
    h = headers_for("student")
    assert client.get(f"{API}/fault", headers=h).status_code == 200
    assert client.post(f"{API}/fault", json=NEW_FAULT_BODY, headers=h).status_code == 201


def test_student_forbidden_elsewhere(client, headers_for):
    h = headers_for("student")
    for path in [f"{API}/assets", f"{API}/users", f"{API}/job", f"{API}/stock", f"{API}/contractors"]:
        assert client.get(path, headers=h).status_code == 403, path
    assert client.post(f"{API}/assets", json=NEW_ASSET_BODY, headers=h).status_code == 403
    assert client.post(f"{API}/job", json=NEW_JOB_BODY, headers=h).status_code == 403


def test_student_web_login_rejected(client, seeded):
    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": seeded["emails"]["student"], "user_password": seeded["passwords"]["student"]},
        headers={"X-Client-Type": "web"},
    )
    assert resp.status_code == 403


def test_student_mobile_login_ok(client, seeded):
    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": seeded["emails"]["student"], "user_password": seeded["passwords"]["student"]},
        headers={"X-Client-Type": "mobile"},
    )
    assert resp.status_code == 200


# --------------------------------------------------------------------------
# Contractor — mobile only, own jobs + calendar view
# --------------------------------------------------------------------------

def test_contractor_can_read_own_jobs_and_calendar(client, headers_for):
    h = headers_for("contractor")
    assert client.get(f"{API}/job", headers=h).status_code == 200
    assert client.get(
        f"{API}/calendar/events", params={"start": "2025-01-01", "end": "2025-12-31"}, headers=h
    ).status_code == 200


def test_contractor_can_update_status_on_own_job(client, headers_for, seeded):
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    ok = client.patch(f"{API}/job/{job_id}", json={"job_finisheddatetime": "2025-06-01T10:00:00"}, headers=h)
    assert ok.status_code == 200


def test_contractor_cannot_edit_non_status_fields(client, headers_for, seeded):
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    resp = client.patch(f"{API}/job/{job_id}", json={"job_desc": "hijacked"}, headers=h)
    assert resp.status_code == 403


def test_contractor_forbidden_elsewhere(client, headers_for):
    h = headers_for("contractor")
    for path in [f"{API}/assets", f"{API}/fault", f"{API}/users", f"{API}/stock"]:
        assert client.get(path, headers=h).status_code == 403, path
    assert client.post(f"{API}/job", json=NEW_JOB_BODY, headers=h).status_code == 403


def test_contractor_web_login_rejected(client, seeded):
    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": seeded["emails"]["contractor"], "user_password": seeded["passwords"]["contractor"]},
        headers={"X-Client-Type": "web"},
    )
    assert resp.status_code == 403


# --------------------------------------------------------------------------
# FK — everything except /users
# --------------------------------------------------------------------------

# NOTE: report.py (/report) is deliberately NOT included in api.py's router, so
# it has no live route. It is still gated with require_right("reports.view") as
# defense-in-depth if it is ever mounted, but there is nothing to probe here.
FK_ALLOWED_GETS = [
    f"{API}/assets", f"{API}/assettypes", f"{API}/stock", f"{API}/building",
    f"{API}/rooms", f"{API}/location", f"{API}/contractors", f"{API}/quotes",
    f"{API}/predictions", f"{API}/audit", f"{API}/fault",
    f"{API}/job", f"{API}/image/",
]


def test_fk_allowed_everywhere_except_users(client, headers_for):
    h = headers_for("fk")
    for path in FK_ALLOWED_GETS:
        assert client.get(path, headers=h).status_code == 200, path


def test_fk_forbidden_on_users(client, headers_for):
    h = headers_for("fk")
    assert client.get(f"{API}/users", headers=h).status_code == 403
    assert client.post(f"{API}/users", json=NEW_USER_BODY, headers=h).status_code == 403
    assert client.patch(f"{API}/users/1", json={"user_status": "inactive"}, headers=h).status_code == 403
    assert client.delete(f"{API}/users/1", headers=h).status_code == 403


def test_fk_web_login_ok(client, seeded):
    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": seeded["emails"]["fk"], "user_password": seeded["passwords"]["fk"]},
        headers={"X-Client-Type": "web"},
    )
    assert resp.status_code == 200


# --------------------------------------------------------------------------
# Admin — everything
# --------------------------------------------------------------------------

def test_admin_allowed_everywhere(client, headers_for):
    h = headers_for("admin")
    for path in FK_ALLOWED_GETS + [f"{API}/users"]:
        assert client.get(path, headers=h).status_code == 200, path


def test_admin_can_create_user(client, headers_for):
    h = headers_for("admin")
    resp = client.post(f"{API}/users", json=NEW_USER_BODY, headers=h)
    assert resp.status_code == 201
    # Password (hash) must never be echoed back in the response.
    assert "user_password" not in resp.json()


def test_admin_web_login_ok(client, seeded):
    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": seeded["emails"]["admin"], "user_password": seeded["passwords"]["admin"]},
        headers={"X-Client-Type": "web"},
    )
    assert resp.status_code == 200


# --------------------------------------------------------------------------
# Audit log is read-only via the API
# --------------------------------------------------------------------------

def test_audit_write_routes_removed(client, headers_for):
    h = headers_for("admin")
    # POST/PATCH/DELETE /audit no longer exist -> 405 (path exists for GET) / 404,
    # never a successful write.
    assert client.post(f"{API}/audit", json={}, headers=h).status_code in (404, 405)
    assert client.delete(f"{API}/audit/1", headers=h).status_code in (404, 405)


# --------------------------------------------------------------------------
# Password hashing + migration
# --------------------------------------------------------------------------

def test_seeded_passwords_are_hashed(engine, seeded):
    with Session(engine) as session:
        users = session.exec(select(User)).all()
        assert users
        for user in users:
            assert is_hashed(user.user_password), f"{user.user_email} not hashed"


def test_me_response_never_leaks_password(client, headers_for):
    resp = client.get(f"{API}/auth/me", headers=headers_for("admin"))
    assert resp.status_code == 200
    body = resp.json()
    assert "user_password" not in body
    assert "rights" in body and isinstance(body["rights"], list)


def test_legacy_plaintext_password_login_then_upgraded(client, engine):
    """A legacy plaintext password logs in once, then is stored hashed."""
    from app.models.user import User as UserModel

    with Session(engine) as session:
        legacy = UserModel(
            user_name="Legacy", user_surname="User",
            user_email="legacy@test.local", user_password="plaintextpw",  # NOT hashed
            user_status="active", role_id=3,
        )
        session.add(legacy)
        session.commit()

    resp = client.post(
        f"{API}/auth/login",
        json={"user_email": "legacy@test.local", "user_password": "plaintextpw"},
        headers={"X-Client-Type": "web"},
    )
    assert resp.status_code == 200

    with Session(engine) as session:
        migrated = session.exec(select(User).where(User.user_email == "legacy@test.local")).one()
        assert is_hashed(migrated.user_password)
        assert verify_password("plaintextpw", migrated.user_password)


# --------------------------------------------------------------------------
# SECRET_KEY startup validation (runs auth/session.py in a subprocess)
# --------------------------------------------------------------------------

_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _import_session_with_env(env_overrides: dict):
    env = {k: v for k, v in os.environ.items() if k != "AUTH_SECRET_KEY"}
    env["DATABASE_URL"] = "sqlite://"
    env.update(env_overrides)
    return subprocess.run(
        [sys.executable, "-c", "import app.auth.session"],
        env=env, cwd=_BACKEND_DIR, capture_output=True, text=True,
    )


def test_secret_key_required_outside_dev():
    result = _import_session_with_env({"ENVIRONMENT": "production"})
    assert result.returncode != 0
    assert "AUTH_SECRET_KEY" in result.stderr


def test_secret_key_ok_when_set_in_production():
    result = _import_session_with_env({"ENVIRONMENT": "production", "AUTH_SECRET_KEY": "a-strong-random-secret"})
    assert result.returncode == 0, result.stderr


def test_secret_key_default_allowed_in_dev():
    result = _import_session_with_env({"ENVIRONMENT": "development"})
    assert result.returncode == 0, result.stderr

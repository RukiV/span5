"""Pytest fixtures for the authorization test-suite.

The suite runs the real API router against an isolated in-memory SQLite database
(so it needs neither Postgres nor psycopg2). Env vars are set BEFORE importing
any app module so that:
  - auth/session.py's AUTH_SECRET_KEY fail-fast is satisfied (ENVIRONMENT=test),
  - db/database.py's module-level engine builds against SQLite (unused; every
    request gets a session from the per-test engine via a dependency override).
"""

import os

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("AUTH_SECRET_KEY", "test-secret-key-for-pytest")
os.environ.setdefault("DATABASE_URL", "sqlite://")

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.pool import StaticPool
from sqlmodel import SQLModel, Session, create_engine
from starlette.middleware.base import BaseHTTPMiddleware


# The audit model uses Postgres JSONB columns. Teach SQLite's DDL compiler to
# emit a plain JSON column for them so the schema can be created for tests.
@compiles(JSONB, "sqlite")
def _compile_jsonb_sqlite(element, compiler, **kw):  # noqa: ANN001, D401
    return "JSON"


# Import app pieces only AFTER the env is configured above.
from app.api.api import api_router  # noqa: E402
from app.auth import permissions  # noqa: E402
from app.auth.session import create_session_token  # noqa: E402
from app.db import seed  # noqa: E402
from app.db.database import getSession  # noqa: E402
from app.middleware.idempotency import IdempotencyMiddleware  # noqa: E402
from app.middleware.security_headers import add_security_headers  # noqa: E402
from app.middleware.datetimes import UtcDatetimeMiddleware  # noqa: E402
from app.models.fault import Faultcard  # noqa: E402
from app.models.job import Jobcard  # noqa: E402


@pytest.fixture(name="engine")
def engine_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    yield engine
    SQLModel.metadata.drop_all(engine)


@pytest.fixture(name="seeded")
def seeded_fixture(engine):
    """Seed roles (1-5), the rights catalog + assignments, one user per role, and
    a student-owned fault + a contractor-assigned job to exercise ownership scoping.
    """
    permissions.clear_rights_cache()
    with Session(engine) as session:
        # Roles must be created in this order so they get ids 1..5.
        seed._get_or_create_default_role(session)      # 1 = Student
        seed._get_or_create_fk_role(session)           # 2 = FK
        seed._get_or_create_admin_role(session)        # 3 = Admin
        seed._get_or_create_contractor_role(session)   # 4 = Contractor
        seed._get_or_create_dosent_role(session)       # 5 = Dosent
        seed.seed_rights(session)

        student = seed._get_or_create_test_user(session, "s", "s", "student@test.local", "studentpw", seed.ROLE_STUDENT)
        fk = seed._get_or_create_test_user(session, "f", "f", "fk@test.local", "fkpw", seed.ROLE_FK)
        admin = seed._get_or_create_test_user(session, "a", "a", "admin@test.local", "adminpw", seed.ROLE_ADMIN)
        contractor = seed._get_or_create_test_user(session, "c", "c", "contractor@test.local", "contractorpw", seed.ROLE_CONTRACTOR)
        dosent = seed._get_or_create_test_user(session, "d", "d", "dosent@test.local", "dosentpw", seed.ROLE_DOSENT)

        fault = Faultcard(fault_description="student's own fault", user_id=student.user_id)
        job = Jobcard(job_desc="contractor's assigned job", contractor_id=contractor.user_id)
        session.add(fault)
        session.add(job)
        session.commit()
        session.refresh(fault)
        session.refresh(job)

        data = {
            "ids": {
                "student": student.user_id,
                "fk": fk.user_id,
                "admin": admin.user_id,
                "contractor": contractor.user_id,
                "dosent": dosent.user_id,
            },
            "emails": {
                "student": "student@test.local",
                "fk": "fk@test.local",
                "admin": "admin@test.local",
                "contractor": "contractor@test.local",
                "dosent": "dosent@test.local",
            },
            "passwords": {
                "student": "studentpw",
                "fk": "fkpw",
                "admin": "adminpw",
                "contractor": "contractorpw",
                "dosent": "dosentpw",
            },
            "fault_id": fault.fault_id,
            "job_id": job.jobcard_id,
        }
    yield data


@pytest.fixture(name="client")
def client_fixture(engine, seeded):
    app = FastAPI()
    app.include_router(api_router, prefix="/api/v1")

    # Same security headers shipped by the production app (app/main.py).
    app.add_middleware(BaseHTTPMiddleware, dispatch=add_security_headers)

    # Add idempotency middleware with the test engine so it uses SQLite
    app.add_middleware(IdempotencyMiddleware)
    app.state.idempotency_engine = engine

    # Same UTC-tagging middleware shipped by the production app (app/main.py),
    # so responses carry an explicit "Z" on naive (UTC) datetimes.
    app.add_middleware(UtcDatetimeMiddleware)

    def override_get_session():
        with Session(engine) as session:
            yield session

    app.dependency_overrides[getSession] = override_get_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture(name="headers_for")
def headers_for_fixture(seeded):
    """Return a helper that builds auth headers for a given role.

    Mints a session token directly (bypassing /auth/login) so the authorization
    matrix is tested independently of the login flow. Defaults to the mobile
    client-type header; pass client_type="web" to exercise the web gate.
    """

    def _make(role: str, client_type: str = "mobile") -> dict:
        user_id = seeded["ids"][role]
        token = create_session_token(user_id)
        return {"Authorization": f"Bearer {token}", "X-Client-Type": client_type}

    return _make

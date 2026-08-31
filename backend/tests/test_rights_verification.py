"""
test_rights_verification.py
───────────────────────────
Verifieer dat elke reg korrek API-toegang beheer.
Toets elke rol teen alle beskermde endpoints.
"""
import pytest

API = "/api/v1"


@pytest.fixture()
def admin_h(headers_for):
    return headers_for("admin")


@pytest.fixture()
def fk_h(headers_for):
    return headers_for("fk")


@pytest.fixture()
def student_h(headers_for):
    return headers_for("student")


@pytest.fixture()
def contractor_h(headers_for):
    return headers_for("contractor")


def _get(client, path, headers=None):
    return client.get(path, headers=headers)


# ── Kalender: regte pad is /calendar/events?start=...&end=... ───────────────
CAL_EVENTS = "/calendar/events?start=2026-01-01&end=2026-12-31"

# ── Admin: verwag 200 op ALLE endpoints ────────────────────────────────────
ADMIN_ENDPOINTS = [
    "/assets", "/stock", "/rooms", "/building", "/location",
    "/fault", "/job", CAL_EVENTS, "/quotes",
    "/users", "/roles", "/rights",
    "/predictions", "/notifications",
]

@pytest.mark.parametrize("path", ADMIN_ENDPOINTS,
                         ids=[p.split("/")[-1] or p.strip("/") for p in ADMIN_ENDPOINTS])
def test_admin_200_everywhere(client, admin_h, path):
    resp = _get(client, f"{API}{path}", admin_h)
    assert resp.status_code == 200, f"Admin {path} → {resp.status_code}"


# ── Anoniem: verwag 401 op ALLE endpoints ──────────────────────────────────
@pytest.mark.parametrize("path", ADMIN_ENDPOINTS,
                         ids=[p.split("/")[-1] or p.strip("/") for p in ADMIN_ENDPOINTS])
def test_anonymous_401_everywhere(client, path):
    resp = _get(client, f"{API}{path}")
    assert resp.status_code == 401, f"Anoniem {path} → {resp.status_code}"


# ── FK: 200 op fasiliteite+fault+job+calendar+quotes, 403 op users/roles/rights
FK_ALLOWED_GETS = [
    "/assets", "/stock", "/rooms", "/building", "/location",
    "/fault", "/job", CAL_EVENTS, "/quotes", "/notifications",
]

@pytest.mark.parametrize("path", FK_ALLOWED_GETS,
                         ids=[p.split("/")[-1] or p.strip("/") for p in FK_ALLOWED_GETS])
def test_fk_200_allowed(client, fk_h, path):
    resp = _get(client, f"{API}{path}", fk_h)
    assert resp.status_code == 200, f"FK {path} → {resp.status_code}"


FK_BLOCKED_GETS = ["/users", "/roles", "/rights"]

@pytest.mark.parametrize("path", FK_BLOCKED_GETS,
                         ids=[p.split("/")[-1] for p in FK_BLOCKED_GETS])
def test_fk_403_blocked(client, fk_h, path):
    resp = _get(client, f"{API}{path}", fk_h)
    assert resp.status_code == 403, f"FK {path} → {resp.status_code}"


# ── Student: faults.create gee toegang tot rooms/building/location lys
#    (nodig om foutkaartjies te skep). Blokkeer: assets, stock, job, quotes,
#    users, roles, rights, predictions, calendar.
#    Let op: /rooms, /building, /location = 200 (require_any_right: faults.create)

STUDENT_BLOCKED = [
    "/assets", "/stock",
    "/job", CAL_EVENTS, "/quotes",
    "/users", "/roles", "/rights", "/predictions",
]

@pytest.mark.parametrize("path", STUDENT_BLOCKED,
                         ids=[p.split("/")[-1] or p.strip("/") for p in STUDENT_BLOCKED])
def test_student_403_blocked(client, student_h, path):
    resp = _get(client, f"{API}{path}", student_h)
    assert resp.status_code == 403, f"Student {path} → {resp.status_code}"


STUDENT_ALLOWED_GETS = [
    "/rooms", "/building", "/location",   # require_any_right(..., "faults.create")
    "/fault",                              # faults.view_own
    "/notifications",
]

@pytest.mark.parametrize("path", STUDENT_ALLOWED_GETS,
                         ids=[p.split("/")[-1] for p in STUDENT_ALLOWED_GETS])
def test_student_200_allowed(client, student_h, path):
    resp = _get(client, f"{API}{path}", student_h)
    assert resp.status_code == 200, f"Student {path} → {resp.status_code}"


# ── Kontrakteur: calendar.view + jobs.view_own. Blokkeer: fasiliteite, users.
#    Kontrakteur het NIE faults.create nie → /rooms, /building, /location = 403

CONTRACTOR_BLOCKED = [
    "/assets", "/stock", "/rooms", "/building", "/location",
    "/quotes", "/users", "/roles", "/rights", "/predictions",
]

@pytest.mark.parametrize("path", CONTRACTOR_BLOCKED,
                         ids=[p.split("/")[-1] for p in CONTRACTOR_BLOCKED])
def test_contractor_403_blocked(client, contractor_h, path):
    resp = _get(client, f"{API}{path}", contractor_h)
    assert resp.status_code == 403, f"Kontrakteur {path} → {resp.status_code}"


def test_contractor_can_see_calendar(client, contractor_h):
    resp = _get(client, f"{API}/calendar/events?start=2026-01-01&end=2026-12-31", contractor_h)
    assert resp.status_code == 200, f"Kontrakteur /calendar/events → {resp.status_code}"


def test_contractor_can_see_own_jobs(client, contractor_h):
    resp = _get(client, f"{API}/job", contractor_h)
    assert resp.status_code == 200, f"Kontrakteur /job → {resp.status_code}"

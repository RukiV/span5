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
from app.models.job import Jobcard
from app.models.notification import Notification
from app.models.user import User


API = "/api/v1"

# A valid body for each write endpoint we probe, so the ONLY possible failure is
# authorization (never a 422 from body validation).
NEW_USER_BODY = {
    "user_name": "Mallory",
    "user_surname": "Attacker",
    "user_email": "mallory@evil.local",
    "user_password": "Supersecret1!",
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
    for path in [f"{API}/assets", f"{API}/users", f"{API}/job", f"{API}/stock"]:
        assert client.get(path, headers=h).status_code == 403, path
    assert client.post(f"{API}/assets", json=NEW_ASSET_BODY, headers=h).status_code == 403
    assert client.post(f"{API}/job", json=NEW_JOB_BODY, headers=h).status_code == 403


def test_student_can_read_faultcard_lookup_data(client, headers_for):
    """The mobile fault-card flow needs read access to the campus tree, asset
    types, and serial-code lookup so a scanned asset can auto-populate the form
    (same read-only relaxation as the image-upload gate). Writes and the asset
    *list* stay manage-only; the *single* asset endpoints just lose the 403."""
    h = headers_for("student")
    for path in [f"{API}/location", f"{API}/building", f"{API}/rooms", f"{API}/assettypes"]:
        assert client.get(path, headers=h).status_code == 200, path
    # Authorized but not found (404), never a 403 permission wall.
    assert client.get(f"{API}/assets/serial/NO-SUCH-SERIAL", headers=h).status_code == 404
    # The asset list endpoint remains manage-only.
    assert client.get(f"{API}/assets", headers=h).status_code == 403


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


def test_contractor_can_update_werknotas_on_own_job(client, headers_for, seeded):
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    resp = client.patch(f"{API}/job/{job_id}", json={"job_notes": "eerste werknota"}, headers=h)
    assert resp.status_code == 200, resp.text
    assert resp.json().get("job_notes") == "eerste werknota"
    got = client.get(f"{API}/job/{job_id}", headers=h)
    assert got.status_code == 200
    assert got.json().get("job_notes") == "eerste werknota"


def test_contractor_cannot_update_werknotas_on_other_job(client, headers_for, engine, seeded):
    h = headers_for("contractor")
    with Session(engine) as session:
        other = Jobcard(job_desc="someone else's job", contractor_id=seeded["ids"]["fk"])
        session.add(other)
        session.commit()
        session.refresh(other)
        other_id = other.jobcard_id
    resp = client.patch(f"{API}/job/{other_id}", json={"job_notes": "hijacked"}, headers=h)
    assert resp.status_code == 403


def test_job_response_includes_real_names(client, headers_for, engine, seeded):
    """Jobcard responses carry the assigned staff member's and contractor's names,
    so contractors never see raw user ids."""
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    with Session(engine) as session:
        job = session.get(Jobcard, job_id)
        job.assigned_to = seeded["ids"]["admin"]
        session.commit()

    detail = client.get(f"{API}/job/{job_id}", headers=h)
    assert detail.status_code == 200
    body = detail.json()
    assert body["contractor_name"] == "c c"
    assert body["assigned_name"] == "a a"

    listed = client.get(f"{API}/job", headers=h).json()
    assert any(
        j["jobcard_id"] == job_id
        and j["contractor_name"] == "c c"
        and j["assigned_name"] == "a a"
        for j in listed
    )


def test_contractor_completion_request_notifies_assigned_staff(client, headers_for, engine, seeded):
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    with Session(engine) as session:
        job = session.get(Jobcard, job_id)
        job.assigned_to = seeded["ids"]["admin"]
        session.commit()
    resp = client.post(f"{API}/job/{job_id}/complete-request", headers=h)
    assert resp.status_code == 200, resp.text
    with Session(engine) as session:
        notifs = session.exec(select(Notification).where(
            Notification.reference_id == job_id,
            Notification.notification_type == "job.completion_requested",
        )).all()
    assert any(n.user_id == seeded["ids"]["admin"] for n in notifs)


def test_contractor_completion_request_falls_back_to_admins(client, headers_for, engine, seeded):
    """Without an assigned staff member the request still reaches admins/FK."""
    h = headers_for("contractor")
    job_id = seeded["job_id"]  # seeded job has assigned_to = None
    resp = client.post(f"{API}/job/{job_id}/complete-request", headers=h)
    assert resp.status_code == 200, resp.text
    with Session(engine) as session:
        notifs = session.exec(select(Notification).where(
            Notification.notification_type == "job.completion_requested",
            Notification.reference_id == job_id,
        )).all()
    ids = {n.user_id for n in notifs}
    assert seeded["ids"]["admin"] in ids or seeded["ids"]["fk"] in ids


def test_contractor_completion_request_denied_on_other_job(client, headers_for, engine, seeded):
    h = headers_for("contractor")
    with Session(engine) as session:
        other = Jobcard(job_desc="someone else's job", contractor_id=seeded["ids"]["fk"])
        session.add(other)
        session.commit()
        session.refresh(other)
        other_id = other.jobcard_id
    resp = client.post(f"{API}/job/{other_id}/complete-request", headers=h)
    assert resp.status_code == 403


def test_contractor_can_upload_and_delete_own_job_photos(client, headers_for, seeded):
    h = headers_for("contractor")
    job_id = seeded["job_id"]
    files = {"file": ("foto.jpg", b"fake-jpeg-bytes", "image/jpeg")}

    up = client.post(
        f"{API}/image/",
        params={"parent_id": job_id, "parent_type": "job"},
        files=files,
        headers=h,
    )
    assert up.status_code == 201, up.text
    image_id = up.json()["image_id"]

    listed = client.get(f"{API}/image/parent/job/{job_id}", headers=h)
    assert listed.status_code == 200
    assert any(img["image_id"] == image_id for img in listed.json())

    # The contractor may also view the source faultcard's photos.
    fault_id = seeded["fault_id"]
    assert client.get(f"{API}/image/parent/ticket/{fault_id}", headers=h).status_code == 200

    rm = client.delete(f"{API}/image/{image_id}", headers=h)
    assert rm.status_code == 204


def test_contractor_cannot_upload_or_delete_outside_own_jobs(client, headers_for, engine, seeded):
    h = headers_for("contractor")
    ah = headers_for("admin")
    files = {"file": ("foto.jpg", b"fake-jpeg-bytes", "image/jpeg")}

    with Session(engine) as session:
        other = Jobcard(job_desc="fk's job", contractor_id=seeded["ids"]["fk"])
        session.add(other)
        session.commit()
        session.refresh(other)
        other_id = other.jobcard_id

    # Upload to another contractor's job -> 403.
    resp = client.post(
        f"{API}/image/",
        params={"parent_id": other_id, "parent_type": "job"},
        files=files,
        headers=h,
    )
    assert resp.status_code == 403
    # Upload to a non-job parent -> 403.
    resp = client.post(
        f"{API}/image/",
        params={"parent_id": 1, "parent_type": "asset"},
        files=files,
        headers=h,
    )
    assert resp.status_code == 403

    # Admin uploads a photo to the FK-owned job; the contractor cannot delete it.
    up = client.post(
        f"{API}/image/",
        params={"parent_id": other_id, "parent_type": "job"},
        files=files,
        headers=ah,
    )
    assert up.status_code == 201, up.text
    image_id = up.json()["image_id"]
    rm = client.delete(f"{API}/image/{image_id}", headers=h)
    assert rm.status_code == 403


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
    f"{API}/rooms", f"{API}/location", f"{API}/quotes",
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
# Quote-document routes are gated by quotes.manage (post-merge fix)
# --------------------------------------------------------------------------

def test_document_routes_require_quotes_manage(client, headers_for):
    # Anonymous -> 401 everywhere (was fully unauthenticated before the fix).
    assert client.get(f"{API}/quotes/1/documents").status_code == 401
    assert client.delete(f"{API}/documents/1").status_code == 401
    # Student lacks quotes.manage -> 403.
    s = headers_for("student")
    assert client.get(f"{API}/quotes/1/documents", headers=s).status_code == 403
    assert client.delete(f"{API}/documents/1", headers=s).status_code == 403
    # Admin/FK hold quotes.manage -> past the auth gate (200/404, not 401/403).
    a = headers_for("admin")
    assert client.get(f"{API}/quotes/1/documents", headers=a).status_code not in (401, 403)


# --------------------------------------------------------------------------
# Contractor-kalender: slegs eie geskeduleerde werksopdragte
# --------------------------------------------------------------------------

def test_contractor_calendar_shows_only_own_scheduled_jobs(client, headers_for, engine, seeded):
    from datetime import datetime
    from app.models.calendar_event import CalendarEvent

    h = headers_for("contractor")
    ah = headers_for("admin")
    with Session(engine) as session:
        other_job = Jobcard(
            job_desc="fk se werksopdrag", contractor_id=seeded["ids"]["fk"],
            job_scheduled_datetime=datetime(2025, 6, 10, 9, 0),
        )
        own_job = Jobcard(
            job_desc="eie werksopdrag", contractor_id=seeded["ids"]["contractor"],
            job_scheduled_datetime=datetime(2025, 6, 11, 9, 0),
        )
        evt = CalendarEvent(
            title="afspraak", start_datetime=datetime(2025, 6, 12, 9, 0),
            user_id=seeded["ids"]["admin"],
        )
        session.add_all([other_job, own_job, evt])
        session.commit()
        session.refresh(other_job)
        session.refresh(own_job)
        session.refresh(evt)
        other_id, own_id, evt_id = other_job.jobcard_id, own_job.jobcard_id, evt.event_id

    resp = client.get(
        f"{API}/calendar/events",
        params={"start": "2025-06-01", "end": "2025-06-30"},
        headers=h,
    )
    assert resp.status_code == 200, resp.text
    sources = [(e["source"], e["source_id"]) for e in resp.json()]
    assert ("jobcard", own_id) in sources
    assert ("jobcard", other_id) not in sources
    assert all(s != "calendar_event" for s, _ in sources)

    resp_admin = client.get(
        f"{API}/calendar/events",
        params={"start": "2025-06-01", "end": "2025-06-30"},
        headers=ah,
    )
    assert resp_admin.status_code == 200
    admin_sources = [(e["source"], e["source_id"]) for e in resp_admin.json()]
    assert ("calendar_event", evt_id) in admin_sources
    assert ("jobcard", other_id) in admin_sources


# --------------------------------------------------------------------------
# Kontrakteur-kennisgewings: slegs hul eie werksopdragte
# --------------------------------------------------------------------------

def test_contractor_excluded_from_location_broadcasts(engine, seeded):
    from app.models.user import User
    from app.services.notification_service import NotificationService

    with Session(engine) as session:
        contractor = session.get(User, seeded["ids"]["contractor"])
        admin = session.get(User, seeded["ids"]["admin"])
        contractor.location_id = 1
        admin.location_id = 1
        session.commit()

        notif_svc = NotificationService(session)
        notif_svc.notify_location_users(1, "fault.created", "titel", "boodskap")
        session.commit()

    with Session(engine) as session:
        notifs = session.exec(select(Notification)).all()
        users = {n.user_id for n in notifs}
    assert seeded["ids"]["contractor"] not in users
    assert seeded["ids"]["admin"] in users


def test_contractor_notified_when_job_created_for_them(client, headers_for, engine, seeded):
    ah = headers_for("admin")
    resp = client.post(
        f"{API}/job",
        json={"job_desc": "nuwe werk", "contractor_id": seeded["ids"]["contractor"]},
        headers=ah,
    )
    assert resp.status_code == 201, resp.text
    job_id = resp.json()["jobcard_id"]

    with Session(engine) as session:
        notifs = session.exec(select(Notification).where(
            Notification.reference_type == "job",
            Notification.notification_type == "job.created",
            Notification.reference_id == job_id,
        )).all()
    assert any(n.user_id == seeded["ids"]["contractor"] for n in notifs)


# --------------------------------------------------------------------------
# Foutkaartjie-outeur word outomaties CC'd wanneer 'n werksopdrag geskep word
# --------------------------------------------------------------------------

def test_job_created_for_fault_ccs_fault_creator(client, headers_for, engine, seeded):
    ah = headers_for("admin")
    resp = client.post(
        f"{API}/job",
        json={"job_desc": "werk vir student se fout", "fault_id": seeded["fault_id"]},
        headers=ah,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert seeded["ids"]["student"] in [int(i.strip()) for i in (data["cc_users"] or "").split(",")]

    with Session(engine) as session:
        notifs = session.exec(select(Notification).where(
            Notification.reference_type == "job",
            Notification.notification_type == "job.created",
            Notification.reference_id == data["jobcard_id"],
        )).all()
    assert any(n.user_id == seeded["ids"]["student"] for n in notifs)


def test_job_created_for_fault_merges_creator_into_existing_cc(client, headers_for, engine, seeded):
    ah = headers_for("admin")
    resp = client.post(
        f"{API}/job",
        json={
            "job_desc": "werk vir student se fout",
            "fault_id": seeded["fault_id"],
            "cc_users": str(seeded["ids"]["fk"]),
        },
        headers=ah,
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    cc = [int(i.strip()) for i in (data["cc_users"] or "").split(",")]
    assert seeded["ids"]["fk"] in cc
    assert seeded["ids"]["student"] in cc
    assert len(cc) == len(set(cc))


def test_job_created_without_fault_does_not_add_cc(client, headers_for, seeded):
    ah = headers_for("admin")
    resp = client.post(
        f"{API}/job",
        json={"job_desc": "geen foutkaartjie nie"},
        headers=ah,
    )
    assert resp.status_code == 201, resp.text
    assert not resp.json().get("cc_users")


# --------------------------------------------------------------------------
# Werksopdrag voltooi → gekoppelde foutkaartjie word opgelos
# --------------------------------------------------------------------------

def test_completing_jobcard_resolves_linked_fault(client, headers_for, engine, seeded):
    from app.models.enums import FaultStatus
    from app.models.fault import Faultcard

    ah = headers_for("admin")
    fault_id = seeded["fault_id"]
    with Session(engine) as session:
        job = Jobcard(
            job_desc="maak die krane reg",
            contractor_id=seeded["ids"]["contractor"],
            fault_id=fault_id,
        )
        session.add(job)
        session.commit()
        session.refresh(job)
        job_id = job.jobcard_id

    resp = client.patch(f"{API}/job/{job_id}", json={"job_status": "Voltooid"}, headers=ah)
    assert resp.status_code == 200, resp.text

    with Session(engine) as session:
        assert session.get(Faultcard, fault_id).fault_status == FaultStatus.RESOLVED


def test_completing_job_ignores_already_closed_fault(client, headers_for, engine, seeded):
    from app.models.enums import FaultStatus
    from app.models.fault import Faultcard

    ah = headers_for("admin")
    with Session(engine) as session:
        fault = Faultcard(
            fault_description="reeds gesluit", user_id=seeded["ids"]["student"],
            fault_status=FaultStatus.CLOSED,
        )
        session.add(fault)
        session.commit()
        session.refresh(fault)
        fault_id = fault.fault_id
        job = Jobcard(job_desc="nie meer nodig nie", fault_id=fault_id)
        session.add(job)
        session.commit()
        session.refresh(job)
        job_id = job.jobcard_id

    resp = client.patch(f"{API}/job/{job_id}", json={"job_status": "Voltooid"}, headers=ah)
    assert resp.status_code == 200, resp.text

    with Session(engine) as session:
        assert session.get(Faultcard, fault_id).fault_status == FaultStatus.CLOSED


# --------------------------------------------------------------------------
# Geskeduleer-status: afgelei uit die skedule + outomatiese 'Besig'
# --------------------------------------------------------------------------

def test_job_schedule_future_sets_geskeduleer(client, headers_for, seeded):
    ah = headers_for("admin")
    job_id = seeded["job_id"]
    resp = client.patch(
        f"{API}/job/{job_id}",
        json={"job_scheduled_datetime": "2030-01-01T08:00:00"},
        headers=ah,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json().get("job_status") == "Geskeduleer"


def test_job_schedule_past_sets_besig(client, headers_for, seeded):
    ah = headers_for("admin")
    job_id = seeded["job_id"]
    resp = client.patch(
        f"{API}/job/{job_id}",
        json={"job_scheduled_datetime": "2020-01-01T08:00:00"},
        headers=ah,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json().get("job_status") == "Besig"


def test_scheduled_job_flips_to_besig_when_start_passes(client, engine, seeded):
    from datetime import datetime
    from app.models.enums import JobStatus
    from app.services.reminder_scheduler import _check_and_start_scheduled_jobs

    with Session(engine) as session:
        past = Jobcard(
            job_desc="geskeduleerde werk", contractor_id=seeded["ids"]["contractor"],
            job_status=JobStatus.SCHEDULED,
            job_scheduled_datetime=datetime(2020, 1, 1, 8, 0),
        )
        future = Jobcard(
            job_desc="toekomstige werk", contractor_id=seeded["ids"]["contractor"],
            job_status=JobStatus.SCHEDULED,
            job_scheduled_datetime=datetime(2030, 1, 1, 8, 0),
        )
        session.add_all([past, future])
        session.commit()
        past_id, future_id = past.jobcard_id, future.jobcard_id

    _check_and_start_scheduled_jobs(db_engine=engine)

    with Session(engine) as session:
        assert session.get(Jobcard, past_id).job_status == JobStatus.IN_PROGRESS
        assert session.get(Jobcard, future_id).job_status == JobStatus.SCHEDULED


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

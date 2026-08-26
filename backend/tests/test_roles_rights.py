"""Tests for the Roles & Rights management API.

Covers the users.manage gate, built-in protection, end-to-end right-assignment
(including live cache invalidation), and the delete/self-lockout guardrails.
"""

from sqlmodel import Session, select

from app.auth.security import hash_password
from app.auth.session import create_session_token
from app.models.role import Rights, RoleRight
from app.models.user import User


API = "/api/v1"


def _rights_by_name(client, admin_headers):
    resp = client.get(f"{API}/rights", headers=admin_headers)
    assert resp.status_code == 200
    return {r["right_name"]: r["right_id"] for r in resp.json()}


# --------------------------------------------------------------------------
# Access gate (users.manage — Admin only)
# --------------------------------------------------------------------------

def test_only_admin_can_reach_roles_and_rights(client, headers_for):
    for role in ("student", "fk", "contractor"):
        h = headers_for(role)
        assert client.get(f"{API}/roles", headers=h).status_code == 403, role
        assert client.get(f"{API}/rights", headers=h).status_code == 403, role
        assert client.post(f"{API}/roles", json={"role_name": "X"}, headers=h).status_code == 403, role
    # Anonymous
    assert client.get(f"{API}/roles").status_code == 401
    assert client.get(f"{API}/rights").status_code == 401


def test_admin_lists_builtin_roles_and_rights(client, headers_for):
    h = headers_for("admin")
    roles = client.get(f"{API}/roles", headers=h).json()
    assert len(roles) == 4
    assert all(r["is_builtin"] for r in roles)
    admin_role = next(r for r in roles if r["role_id"] == 3)
    assert "right_ids" in admin_role and len(admin_role["right_ids"]) >= 1

    rights = client.get(f"{API}/rights", headers=h).json()
    assert len(rights) == 25  # 23 + ai.use + ai.approve (AI fault-draft pipeline)
    assert all(r["is_builtin"] for r in rights)


# --------------------------------------------------------------------------
# Built-in protection
# --------------------------------------------------------------------------

def test_builtin_role_name_and_delete_protected(client, headers_for):
    h = headers_for("admin")
    assert client.patch(f"{API}/roles/3", json={"role_name": "Hacked"}, headers=h).status_code == 403
    assert client.delete(f"{API}/roles/3", headers=h).status_code == 403


def test_builtin_right_modify_and_delete_protected(client, headers_for):
    h = headers_for("admin")
    right_id = _rights_by_name(client, h)["assets.manage"]
    assert client.patch(f"{API}/rights/{right_id}", json={"right_description": "x"}, headers=h).status_code == 403
    assert client.delete(f"{API}/rights/{right_id}", headers=h).status_code == 403


def test_admin_role_cannot_lose_users_manage(client, headers_for):
    h = headers_for("admin")
    names = _rights_by_name(client, h)
    without_users_manage = [i for n, i in names.items() if n != "users.manage"]
    resp = client.put(f"{API}/roles/3/rights", json={"right_ids": without_users_manage}, headers=h)
    assert resp.status_code == 403


# --------------------------------------------------------------------------
# Custom rights CRUD
# --------------------------------------------------------------------------

def test_custom_right_full_crud(client, headers_for):
    h = headers_for("admin")
    created = client.post(f"{API}/rights", json={"right_name": "custom.thing", "right_description": "d"}, headers=h)
    assert created.status_code == 201
    body = created.json()
    assert body["is_builtin"] is False
    rid = body["right_id"]

    assert client.patch(f"{API}/rights/{rid}", json={"right_description": "updated"}, headers=h).status_code == 200
    assert client.delete(f"{API}/rights/{rid}", headers=h).status_code == 204
    assert client.get(f"{API}/rights/{rid}", headers=h).status_code == 404


# --------------------------------------------------------------------------
# Custom roles + end-to-end assignment (with live cache invalidation)
# --------------------------------------------------------------------------

def test_custom_role_assignment_takes_effect_live(client, headers_for, engine):
    h = headers_for("admin")

    # Create a custom role with no rights.
    role = client.post(f"{API}/roles", json={"role_name": "Toetsrol"}, headers=h).json()
    role_id = role["role_id"]
    assert role["is_builtin"] is False
    assert role["right_ids"] == []

    # A user with this (right-less) role is forbidden on /assets. This also
    # populates the rights cache for the new role_id with an empty set.
    with Session(engine) as session:
        member = User(
            user_name="m", user_surname="m", user_email="member@test.local",
            user_password=hash_password("pw"), user_status="active", role_id=role_id,
        )
        session.add(member)
        session.commit()
        session.refresh(member)
        member_id = member.user_id

    member_headers = {"Authorization": f"Bearer {create_session_token(member_id)}", "X-Client-Type": "web"}
    assert client.get(f"{API}/assets", headers=member_headers).status_code == 403

    # Grant assets.manage to the role -> must take effect immediately (cache cleared).
    assets_manage_id = _rights_by_name(client, h)["assets.manage"]
    put = client.put(f"{API}/roles/{role_id}/rights", json={"right_ids": [assets_manage_id]}, headers=h)
    assert put.status_code == 200
    assert put.json() == [assets_manage_id]

    assert client.get(f"{API}/assets", headers=member_headers).status_code == 200


def test_delete_custom_role_blocked_when_in_use_then_allowed(client, headers_for, engine):
    h = headers_for("admin")
    role_id = client.post(f"{API}/roles", json={"role_name": "Wegdoenbaar"}, headers=h).json()["role_id"]

    # Assign a user -> delete blocked with 409.
    with Session(engine) as session:
        u = User(
            user_name="u", user_surname="u", user_email="user2@test.local",
            user_password=hash_password("pw"), user_status="active", role_id=role_id,
        )
        session.add(u)
        session.commit()
        session.refresh(u)
        uid = u.user_id
    assert client.delete(f"{API}/roles/{role_id}", headers=h).status_code == 409

    # Reassign the user elsewhere, then delete succeeds (204).
    with Session(engine) as session:
        u = session.get(User, uid)
        u.role_id = 3
        session.add(u)
        session.commit()
    assert client.delete(f"{API}/roles/{role_id}", headers=h).status_code == 204
    assert client.get(f"{API}/roles/{role_id}", headers=h).status_code == 404


def test_deleting_custom_role_cascades_its_assignments(client, headers_for, engine):
    h = headers_for("admin")
    assets_manage_id = _rights_by_name(client, h)["assets.manage"]
    role_id = client.post(
        f"{API}/roles",
        json={"role_name": "Kaskade", "right_ids": [assets_manage_id]},
        headers=h,
    ).json()["role_id"]

    with Session(engine) as session:
        assert session.exec(select(RoleRight).where(RoleRight.role_id == role_id)).all()

    assert client.delete(f"{API}/roles/{role_id}", headers=h).status_code == 204

    with Session(engine) as session:
        assert session.exec(select(RoleRight).where(RoleRight.role_id == role_id)).all() == []

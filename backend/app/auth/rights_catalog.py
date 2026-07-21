"""Built-in roles & rights catalog — the single source of truth.

Moved out of ``db/seed.py`` so lightweight modules (endpoints/services) can
answer "is this a built-in role/right?" without importing the heavy seed module
(which pulls the DB engine and every model). ``db/seed.py`` imports these back.

Built-ins are load-bearing: the 4 role ids are referenced by ``auth.py``'s login
gate and re-created by name in ``seed.py``; the right names are referenced by
``require_right("...")`` all over the endpoints. So the management API refuses to
rename/delete any of them (see BUILTIN_ROLE_IDS / BUILTIN_RIGHT_NAMES).
"""

# Role IDs. Assigned by insertion order in seed_data() and relied on throughout
# the codebase — do NOT renumber.
ROLE_STUDENT = 1
ROLE_FK = 2
ROLE_ADMIN = 3
ROLE_CONTRACTOR = 4

# --- Rights catalog --------------------------------------------------------
# right_name -> human description. Kept intentionally small: one right per
# resource, split into view/manage only where a role genuinely needs
# read-without-write (calendar, jobs, faults).
RIGHTS_CATALOG: dict[str, str] = {
    "users.manage": "Full CRUD on users (Admin only).",
    "assets.manage": "Create/read/update/delete assets and asset types.",
    "stock.manage": "Manage stock items.",
    "buildings.manage": "Manage buildings.",
    "rooms.manage": "Manage rooms.",
    "locations.manage": "Manage campuses / terrains.",
    "contractors.manage": "Manage contractors.",
    "quotes.manage": "Manage quotes.",
    "predictions.view": "View asset lifespan predictions.",
    "reports.view": "View analytics reports.",
    "audit.view": "Read the audit log (read-only, no manage right exists).",
    "calendar.manage": "Full CRUD on calendar events.",
    "calendar.view": "Read-only calendar access.",
    "faults.manage_all": "See/edit/delete every fault card.",
    "faults.create_own": "Create a fault card.",
    "faults.view_own": "See only fault cards you created.",
    "jobs.manage": "Create/delete/edit any job.",
    "jobs.view_own": "See only jobs assigned to you.",
    "jobs.update_own_status": "Update only status fields on your own jobs.",
}

# --- RoleRight assignments -------------------------------------------------
# role_id -> set of right names. Admin == FK plus users.manage; note that Admin
# does NOT hold the contractor-only jobs.view_own / jobs.update_own_status
# rights (Admin manages jobs via jobs.manage instead).
_FK_RIGHTS = {
    "assets.manage", "stock.manage", "buildings.manage", "rooms.manage",
    "locations.manage", "contractors.manage", "quotes.manage",
    "predictions.view", "reports.view", "audit.view",
    "calendar.manage", "calendar.view",
    "faults.manage_all", "faults.create_own", "faults.view_own",
    "jobs.manage",
}
ROLE_RIGHTS: dict[int, set[str]] = {
    ROLE_ADMIN: _FK_RIGHTS | {"users.manage"},
    ROLE_FK: set(_FK_RIGHTS),
    ROLE_STUDENT: {"faults.create_own", "faults.view_own"},
    ROLE_CONTRACTOR: {"calendar.view", "jobs.view_own", "jobs.update_own_status"},
}

# The management API protects these from rename/delete.
BUILTIN_ROLE_IDS: frozenset[int] = frozenset({ROLE_STUDENT, ROLE_FK, ROLE_ADMIN, ROLE_CONTRACTOR})
BUILTIN_RIGHT_NAMES: frozenset[str] = frozenset(RIGHTS_CATALOG)

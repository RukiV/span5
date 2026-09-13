"""Built-in roles & rights catalog — the single source of truth.

Moved out of ``db/seed.py`` so lightweight modules (endpoints/services) can
answer "is this a built-in role/right?" without importing the heavy seed module
(which pulls the DB engine and every model). ``db/seed.py`` imports these back.

Built-ins are load-bearing: the 4 role ids are referenced by ``auth.py``'s login
gate and re-created by name in ``seed.py``; the right names are referenced by
``require_right("...")`` all over the endpoints. So the management API refuses to
rename/delete any of them (see BUILTIN_ROLE_IDS / BUILTIN_RIGHT_NAMES).

Rights follow a ``<resource>.<verb>`` scheme: ``view`` = read-only access, and
``manage`` = create/update/delete (a ``manage`` role always holds ``view`` too).
Resources with ownership scoping (faults, jobs) add ``_own`` variants so that a
low-privilege role can never see/edit other users' records. Special actions that
do not fit CRUD (notifications.send) keep their own right name.
"""

# Role IDs. Assigned by insertion order in seed_data() and relied on throughout
# the codebase — do NOT renumber.
ROLE_STUDENT = 1
ROLE_FK = 2
ROLE_ADMIN = 3
ROLE_CONTRACTOR = 4
ROLE_DOSENT = 5

# --- Rights catalog --------------------------------------------------------
# right_name -> human description. Resources are split into view (read) and
# manage (create/update/delete). faults/jobs keep _own scope variants so that
# contractors and students can only reach their own records.
RIGHTS_CATALOG: dict[str, str] = {
    # Assets & Stock
    "assets.view": "Read assets and asset types.",
    "assets.manage": "Create/update/delete assets and asset types.",
    "stock.view": "Read stock items.",
    "stock.manage": "Create/update/delete stock items.",
    "room_checks.manage": "Run and view room checklists.",
    # Campus, Buildings & Rooms
    "locations.view": "Read campuses / terrains.",
    "locations.manage": "Create/update/delete campuses / terrains.",
    "buildings.view": "Read buildings.",
    "buildings.manage": "Create/update/delete buildings.",
    "rooms.view": "Read rooms.",
    "rooms.manage": "Create/update/delete rooms.",
    # Fault cards
    "faults.create": "Create a fault card.",
    "faults.view_own": "See only fault cards you created.",
    "faults.view": "See every fault card.",
    "faults.manage": "Update/delete every fault card.",
    # Job cards
    "jobs.view_own": "See only jobs assigned to you.",
    "jobs.view": "See every job.",
    "jobs.manage": "Create/update/delete every job.",
    "jobs.update_own_status": "Update status/finish time/werknotas on your own jobs.",
    # Calendar
    "calendar.view": "Read-only calendar access.",
    "calendar.manage": "Create/update/delete calendar events.",
    # Contractors & Quotes
    "contractors.view": "Read contractors.",
    "contractors.manage": "Create/update/delete contractors.",
    "quotes.view": "Read quotes.",
    "quotes.manage": "Create/update/delete quotes.",
    # Users, Roles & Rights (Admin)
    "users.view": "Read users.",
    "users.manage": "Create/update/delete users.",
    "roles.manage": "Manage roles and their rights.",
    "rights.manage": "Manage the rights catalog.",
    # Notifications
    "notifications.view": "View own notifications and history.",
    "notifications.manage": "Manage own notification preferences.",
    "notifications.send": "Send system-wide announcements.",
    # Analytics & Audit
    "predictions.view": "View asset lifespan predictions.",
    "reports.view": "View analytics reports.",
    "analytics.view": "View AI analytics panel.",
    "audit.view": "Read the audit log (read-only, no manage right exists).",
    # AI
    "ai.use": "Submit a fault description for AI drafting.",
    "ai.approve": "Review, approve or reject AI fault drafts.",
    # Dosent
    "roomchecks.execute": "Execute room checklists (Dosent).",
}

# --- RoleRight assignments -------------------------------------------------
# role_id -> set of right names. Admin == FK plus users/roles/rights management.
# Neither Admin nor FK holds the contractor-only jobs.view_own /
# jobs.update_own_status rights (staff manage jobs via jobs.manage instead).
_FK_RIGHTS = {
    "assets.view", "assets.manage",
    "stock.view", "stock.manage",
    "room_checks.manage",
    "locations.view", "locations.manage",
    "buildings.view", "buildings.manage",
    "rooms.view", "rooms.manage",
    "faults.create", "faults.view", "faults.manage",
    "jobs.view", "jobs.manage",
    "calendar.view", "calendar.manage",
    "contractors.view", "contractors.manage",
    "quotes.view", "quotes.manage",
    "notifications.view", "notifications.manage",
    "users.view", "users.manage",
    "roles.manage", "rights.manage",
    "predictions.view", "reports.view", "analytics.view", "audit.view",
    "ai.use", "ai.approve",
}
ROLE_RIGHTS: dict[int, set[str]] = {
    ROLE_ADMIN: _FK_RIGHTS | {
        "users.view", "users.manage", "roles.manage", "rights.manage",
        "notifications.send",
    },
    ROLE_FK: set(_FK_RIGHTS),
    ROLE_STUDENT: {"faults.create", "faults.view_own", "notifications.view", "notifications.manage"},
    ROLE_CONTRACTOR: {"calendar.view", "jobs.view_own", "jobs.update_own_status", "notifications.view", "notifications.manage"},
    ROLE_DOSENT: {"roomchecks.execute", "calendar.view", "notifications.view", "notifications.manage"},
}

# The management API protects these from rename/delete.
BUILTIN_ROLE_IDS: frozenset[int] = frozenset({ROLE_STUDENT, ROLE_FK, ROLE_ADMIN, ROLE_CONTRACTOR, ROLE_DOSENT})
BUILTIN_RIGHT_NAMES: frozenset[str] = frozenset(RIGHTS_CATALOG)

# --- Legacy right migration -------------------------------------------------
# One-time remap of the pre-split right names (old -> replacement set). Applied
# by seed.py so existing databases keep working without manual intervention:
# for every role that holds an old name, the mapped rights are granted and the
# old name is pruned. Keys that are no longer part of the catalog are dropped.
LEGACY_RIGHT_MIGRATION: dict[str, set[str]] = {
    "users.manage": {"users.view", "users.manage", "roles.manage", "rights.manage"},
    "assets.manage": {"assets.view", "assets.manage", "room_checks.manage"},
    "stock.manage": {"stock.view", "stock.manage"},
    "buildings.manage": {"buildings.view", "buildings.manage"},
    "rooms.manage": {"rooms.view", "rooms.manage"},
    "locations.manage": {"locations.view", "locations.manage"},
    "contractors.manage": {"contractors.view", "contractors.manage"},
    "quotes.manage": {"quotes.view", "quotes.manage"},
    "calendar.manage": {"calendar.view", "calendar.manage"},
    "calendar.view": {"calendar.view"},
    "faults.manage_all": {"faults.view", "faults.manage"},
    "faults.create_own": {"faults.create"},
    "faults.view_own": {"faults.view_own"},
    "jobs.manage": {"jobs.view", "jobs.manage"},
    "jobs.view_own": {"jobs.view_own"},
    "jobs.update_own_status": {"jobs.update_own_status"},
    "roomchecks.manage": {"room_checks.manage"},
    "roomchecks.execute": {"roomchecks.execute"},
    "notifications.view": {"notifications.view"},
    "notifications.manage": {"notifications.manage"},
    "notifications.send": {"notifications.send"},
    "predictions.view": {"predictions.view"},
    "reports.view": {"reports.view"},
    "analytics.view": {"analytics.view"},
    "audit.view": {"audit.view"},
}

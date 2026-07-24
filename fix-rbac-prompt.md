# Fix role-based access control across FBS (backend, frontend, frontendMobile)

## Context

FBS is a facility management system: FastAPI + SQLModel backend (`backend/`), React web app (`frontend/`), Flutter mobile app (`frontendMobile/`). Four roles exist, seeded in `backend/app/db/seed.py`:

| role_id | name (DB) | Shorthand |
|---|---|---|
| 1 | User (`role_name="User"`) | **Student** |
| 2 | Fasiliteit Koördineerder | **FK** |
| 3 | Administrateur | **Admin** |
| 4 | Kontrakteur | **Contractor** |

Do not renumber these — `role_id` values are relied on throughout seed data and existing code.

A security review found that authorization is almost entirely missing outside of two files, and the `Rights`/`RoleRight` tables that exist in `backend/app/models/role.py` for exactly this purpose are completely unused — every check in the codebase is an ad hoc `role_id == N` comparison, and most endpoints have no check at all. Your job is to make `Rights`/`RoleRight` the actual source of truth and wire it in everywhere, plus fix a handful of adjacent auth bugs found during the review.

## Target permission matrix (from product owner)

- **Admin** — Web: full access to all pages, data, and functions. Mobile: everything except "Verslae" (Reports) and "Gebruikers" (Users).
- **FK** — Web: everything except "Gebruikers". Mobile: everything except "Verslae".
- **Student** — No web access at all (login must be rejected). Mobile: only "Rapportering" (fault reporting), and only ever sees/creates their own fault cards, never anyone else's.
- **Contractor** — No web access at all (login must be rejected). Mobile: only "Werksopdragte" (jobs) and "Kalender" pages; only their own assigned jobs, and can only update job status, not other job fields.

Note the mobile app currently has no "Verslae" (analytics reports) page at all — it only has "Foutkaartjies"/"Rapportering" (fault reporting), which is a different feature. So "Admin/FK: no Verslae on mobile" is already satisfied by the app simply not having that screen; just make sure the underlying `/report` API route itself is still gated so it can't be hit directly.

## Verified problems to fix

### Backend — critical (unauthenticated/unauthorized writes)

1. `backend/app/auth/dependencies.py` — `get_current_user`/`get_current_user_id` return `None` on missing or invalid token instead of raising 401. Nothing downstream checks for `None`, so any endpoint that only depends on these (not on an explicit `if user is None: raise HTTPException(401)`) is reachable **with no Authorization header at all**.
2. Because of (1), every write endpoint in `assettype.py`, `assets.py`, `audit.py`, `building.py`, `calendar.py`, `contractor.py`, `location.py`, `quote.py`, `report.py`, `room.py`, `stock.py`, `user.py`, `image.py` accepts unauthenticated requests. `user.py` is the worst case: `POST/PATCH/DELETE /users` let anyone create a user with `role_id: 3` (admin), change any user's role, or delete any user, without logging in.
3. Same files' `GET` routes mostly have **no dependency at all** (e.g. `readUsers`, `readAssettypes`, `readAuditLogs`) — fully open, no token required, leaking PII (names, emails, phone numbers, roles) to anyone.
4. `backend/app/api/v1/endpoints/image.py` line 17 has a stale comment `# Keeps endpoint secure` next to a dependency that does not secure anything (same root cause as #1) — fix the code, and remove the misleading comment.
5. `backend/app/api/v1/endpoints/audit.py` has two `@router.get("")` handlers (`readAuditLogs` and `readAudits`) — the second is dead code, shadowed by the first. Remove the dead one. Also: **audit log write endpoints should not exist** — `POST/PATCH/DELETE /audit` let any client rewrite audit history via the API today. Audit rows must only ever be created internally by `BaseService._create_audit_log`. Delete the write routes from `audit.py` entirely; keep only reads.
6. `backend/app/api/v1/endpoints/fault.py` and `job.py` are the *only* files doing real role checks today (`role_id == ROLE_STUDENT`, etc., with correct 401-then-403 ordering and correct ownership scoping — e.g. contractors can only PATCH `job_status`/`job_finisheddatetime` on their own jobs). This logic is correct and should be preserved, just re-pointed at the new rights system (see Target design).

### Backend — auth fundamentals

7. `backend/app/api/v1/endpoints/auth.py` `login()` compares passwords in plaintext: `user.user_password != login_data.user_password`. There is no hashing anywhere in the codebase (`grep`-confirmed no `bcrypt`/`passlib`/`argon2`). Fix this with `passlib[bcrypt]` (or `argon2-cffi`): hash on create/update, verify on login. Write a one-time migration in `seed.py`/a standalone script that hashes any plaintext passwords already in the DB (detect already-hashed values by their hash prefix so this is idempotent/safe to re-run).
8. `backend/app/auth/session.py` — `SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "please-change-this-secret")`. A hardcoded fallback for a signing key is a critical risk if it ever ships. Make the app fail fast at startup if `AUTH_SECRET_KEY` is unset (or equals the known default) outside of an explicit local/dev mode.
9. `backend/app/api/v1/endpoints/auth.py` `_check_system_access` only blocks `role_id == 1` (Student) from web login; per the target matrix, `role_id == 4` (Contractor) must be blocked from web login too. Also: this check relies on the client-supplied `X-Client-Type` header, which `frontendMobile/lib/core/api_client.dart` sets as a static value on every request (line ~36) — it is trivially spoofable by any HTTP client and is **not a security boundary**, just a UX gate. Keep it (extended to cover Contractor) for a decent error message, but do not treat it as the thing that actually stops a Student/Contractor from doing anything — that job belongs entirely to the new rights checks below, which must produce the same result (403 on everything except their own fault/job data) regardless of what client-type header is sent.
10. `/auth/logout` and `/auth/revoke` are currently no-ops — tokens remain valid until natural expiry after "logout". At minimum document this as a known limitation; if time allows, implement a server-side revocation list (even a simple DB table of revoked token signatures/expiries checked in `verify_session_token`) — call this out as a decision point rather than assuming an approach.

### Frontend (`frontend/`) and mobile (`frontendMobile/`)

11. `frontend/src/App.jsx`'s `ProtectedRoute` only checks that a token exists, not role. `frontend/src/pages/UsersPage.jsx` is the only page that self-checks role (calling `/auth/me` and redirecting non-admins) — every other page (Reports, Contractors, Buildings, etc.) renders for any authenticated role today, including Student/Contractor if they ever obtained a web session. Replace the one-off pattern with a reusable guard.
12. `frontendMobile/lib/models/user_session.dart` (`UserSession`) and `frontendMobile/lib/pages/home/home_page.dart` (`_getVisibleMenu()`) currently hardcode menu visibility per role via `UserRole` enum branches. This matches the target matrix today, but should be driven by the same rights list the backend now exposes, so future permission changes don't require an app rebuild.

## Target design

### Rights catalog (new rows in `Rights`)

Keep this small — one right per resource is enough for this matrix; don't split into `.view`/`.manage` pairs unless a role genuinely needs read-without-write (only `calendar` and `jobs`/`faults` need that split here):

```
users.manage            # Admin only — full CRUD on users (GET included)
assets.manage           # Admin, FK — Asset + Assettype CRUD/read
stock.manage            # Admin, FK
buildings.manage        # Admin, FK
rooms.manage            # Admin, FK
locations.manage        # Admin, FK — campuses/"terreine"
contractors.manage      # Admin, FK
quotes.manage           # Admin, FK
predictions.view        # Admin, FK
reports.view            # Admin, FK
audit.view              # Admin, FK — read-only, no "manage" right exists
calendar.manage         # Admin, FK — full CRUD
calendar.view           # Admin, FK, Contractor — read-only (Contractor's Kalender page)
faults.manage_all       # Admin, FK — see/edit/delete every fault card
faults.create_own       # Admin, FK, Student — create a fault card
faults.view_own         # Admin, FK, Student — see only fault cards you created
jobs.manage             # Admin, FK — create/delete/edit any job
jobs.view_own           # Contractor — see only jobs assigned to you
jobs.update_own_status  # Contractor — patch only job_status/job_finisheddatetime on your own jobs
```

Admin and FK should hold `faults.manage_all` (which supersedes `faults.create_own`/`faults.view_own` in the endpoint logic — same pattern `fault.py` already uses, just renamed).

### RoleRight assignments

| Right | Admin | FK | Student | Contractor |
|---|---|---|---|---|
| users.manage | ✅ | | | |
| assets.manage | ✅ | ✅ | | |
| stock.manage | ✅ | ✅ | | |
| buildings.manage | ✅ | ✅ | | |
| rooms.manage | ✅ | ✅ | | |
| locations.manage | ✅ | ✅ | | |
| contractors.manage | ✅ | ✅ | | |
| quotes.manage | ✅ | ✅ | | |
| predictions.view | ✅ | ✅ | | |
| reports.view | ✅ | ✅ | | |
| audit.view | ✅ | ✅ | | |
| calendar.manage | ✅ | ✅ | | |
| calendar.view | ✅ | ✅ | | ✅ |
| faults.manage_all | ✅ | ✅ | | |
| faults.create_own | ✅ | ✅ | ✅ | |
| faults.view_own | ✅ | ✅ | ✅ | |
| jobs.manage | ✅ | ✅ | | |
| jobs.view_own | | | | ✅ |
| jobs.update_own_status | | | | ✅ |

Seed this in `backend/app/db/seed.py` following the existing `_get_or_create_*` idempotent pattern (add `_get_or_create_right(...)` and `_get_or_create_role_right(...)`, call them from `seed_data()` after roles are created).

### Backend authorization layer

New module `backend/app/auth/permissions.py`:

- `get_current_user(request, session) -> User` — hard-fails with `HTTPException(401)` if the token is missing/invalid/expired. This becomes the default; if any endpoint has a genuine reason to allow anonymous access, it must use an explicitly-named `get_current_user_optional` instead, so "no auth" is always an opt-in, visible choice, never the silent default.
- `user_has_right(session, role_id: int, right_name: str) -> bool` — joins `RoleRight`/`Rights` for the user's role.
- `require_right(right_name: str)` — a dependency factory returning a function that depends on `get_current_user`, checks `user_has_right`, and raises `HTTPException(403)` if absent. Use like `Depends(require_right("assets.manage"))`.
- Consider a small per-request cache (e.g. `functools.lru_cache` keyed on role_id, invalidated on TTL or just re-queried — it's a cheap join) so this doesn't add a query storm; don't over-engineer it.

Do **not** embed role or rights inside the session token itself — keep resolving the user (and their rights) fresh from the DB on every request, as today. This is the right call: it means a role change or right change takes effect immediately without needing to revoke outstanding tokens. There's a stray Afrikaans comment in `session.py` (`#Moet not role add en dalk rights`) debating this — resolve it explicitly in code comments so it isn't re-litigated later.

### Apply to every endpoint

Go file by file and replace the current dependency (`get_current_user_id` used only for audit attribution, or nothing at all) with the right-gated dependency, keeping `user_id`/`user` available for audit-log attribution and ownership checks where needed:

- `user.py` → `require_right("users.manage")` on all 4 routes (GET included).
- `assettype.py`, `assets.py` → `require_right("assets.manage")`.
- `stock.py` → `require_right("stock.manage")`.
- `building.py` → `require_right("buildings.manage")`.
- `room.py` → `require_right("rooms.manage")`.
- `location.py` → `require_right("locations.manage")`.
- `contractor.py` → `require_right("contractors.manage")`.
- `quote.py` → `require_right("quotes.manage")`.
- `predictions.py` → `require_right("predictions.view")`.
- `report.py` → `require_right("reports.view")`.
- `audit.py` → `require_right("audit.view")` on the remaining GET routes only (write routes deleted per problem #5).
- `calendar.py` → `require_right("calendar.view")` on reads, `require_right("calendar.manage")` on writes.
- `fault.py` → keep existing structure, but branch on `user_has_right(session, user.role_id, "faults.manage_all")` instead of `role_id == ROLE_STUDENT`, falling back to the existing own-fault-card filtering when the user only has `faults.create_own`/`faults.view_own`.
- `job.py` → same idea: branch on `jobs.manage` vs `jobs.view_own`/`jobs.update_own_status`, keeping the existing field-allowlist logic for contractor PATCH.
- `image.py` → **investigate before implementing.** Trace whether Students need to attach a photo when creating a fault card on mobile (check `frontendMobile/lib/services/image_service.dart`, `camera_service.dart`, and `lib/pages/reporting/new_report_page.dart` / `scan_page.dart`, and whether `Faultcard`/`Asset` models reference `ImageAsset`). If Students upload their own fault photos, image upload needs to be reachable by `faults.create_own`, not just `assets.manage` — don't gate this purely on `assets.manage` without confirming that first, or you'll break fault reporting for the one role that's supposed to have it.

### `/auth/me` and frontend/mobile wiring

Extend the `/auth/me` response (a new response model, don't bloat `UserRead` which is reused for `/users`) to include a `rights: list[str]` field — the resolved list of right names for the caller's role. This becomes the single source of truth both clients read from.

**Frontend (`frontend/`):** Replace `UsersPage.jsx`'s bespoke self-check with a reusable `RightProtectedRoute` (wrapping the existing `ProtectedRoute` in `App.jsx`) that takes a required right, reads it from the same `/auth/me` rights array `useCurrentUser.js` already fetches, and redirects if absent. Apply it to every admin/FK-only route, not just `/users`. Update `Sidebar.jsx` to filter menu items off the rights array instead of the single hardcoded `isAdmin` boolean.

**Mobile (`frontendMobile/`):** Add a `List<String> rights` field to `UserSession`, populated in `initialize()` from the `/auth/me` payload. Rewrite `home_page.dart`'s `_getVisibleMenu()` to filter menu entries by right instead of the current `isStudent`/`isContractor`/`isAdmin`/`isManager` branches (keep the enum for display purposes like `roleTitle`, just stop using it for access decisions).

## Order of work

1. Add `Rights`/`RoleRight` seed data (additive, non-breaking).
2. Build the `permissions.py` authorization layer.
3. Make `get_current_user` hard-fail by default; audit every existing call site for the rename/behavior change.
4. Wire `require_right` into every endpoint file per the mapping above; delete the `audit.py` write routes and its duplicate GET.
5. Fix password hashing + migration, fix `SECRET_KEY` startup validation, extend `_check_system_access` to cover Contractor.
6. Extend `/auth/me`, wire frontend `RightProtectedRoute` + `Sidebar`.
7. Wire mobile `UserSession.rights` + `home_page.dart` menu filtering.
8. Tests (see below).

## Acceptance criteria

Write (and pass) tests covering, for each of the 4 roles and a fully anonymous caller, the expected status code on every route:

- Anonymous caller gets `401` on every non-login endpoint, with zero side effects (no DB rows created/changed) — this is the regression test for the current critical bug.
- Student gets `403` on everything except `POST/GET /faults` (own only), and `403` (or login-time rejection) on web login.
- Contractor gets `403` on everything except `GET /jobs` (own only), `PATCH /jobs/{id}` restricted to status fields on own jobs, `GET /calendar`, and `403`/rejection on web login.
- FK gets `200`/normal behavior everywhere except `403` on all `/users` routes.
- Admin gets `200`/normal behavior everywhere.
- Login with a plaintext-matching but not-yet-hashed legacy password still succeeds once, then is stored hashed (if you implement lazy migration) — or confirm the batch migration script ran and plaintext passwords no longer exist in the DB.
- App fails to start if `AUTH_SECRET_KEY` is unset and environment is not explicitly dev/test.

## Explicitly out of scope / do not do

- Don't change `role_id` numbering or the Afrikaans role names in the DB.
- Don't remove or "simplify away" the existing ownership-scoping logic in `fault.py`/`job.py` — it's correct, just re-point its conditions at rights instead of raw `role_id` comparisons.
- Don't invent new pages/menu items — this is an authorization fix, not a feature change.
- Don't treat the `X-Client-Type` header as a security control anywhere new.
- Don't silently swallow exceptions in the new permission dependency — 401/403 should be explicit `HTTPException`s, not caught-and-ignored.

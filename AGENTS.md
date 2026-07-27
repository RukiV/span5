# AGENTS.md — span5 (FBS Facility Management System)

Three-tier monorepo: FastAPI backend (Python 3.12 + SQLModel) + React frontend (CRA 5.0.1 / React 18) + Flutter mobile app (`fbs`), orchestrated by root `docker-compose.yml`.

| Part | Dir | Entrypoint |
|---|---|---|
| Backend | `backend/app/` | `app/main.py` — `uvicorn app.main:app` |
| Frontend | `frontend/` | `src/index.js` (CRA) |
| Mobile | `frontendMobile/` | Flutter `fbs` |
| DB | — | postgres:15-alpine, db `facility_db` |

## First-time setup

```sh
cp .env.example .env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
cp frontendMobile/.env.example frontendMobile/.env
```

## Commands

```sh
docker compose up --build          # full stack: web:3000, api:8000, db:5432
docker compose down --volumes      # purge old volumes (audit-logging issues)

# Standalone (outside Docker):
cd backend && uvicorn app.main:app --reload    # uses DATABASE_URL or DB_HOST etc.
cd frontend && npm start                        # requests go to REACT_APP_API_URL directly
cd frontendMobile && flutter pub get && flutter run
```

No test, lint, or typecheck scripts — `react-scripts test` exists in package.json but has no test files.

## Auth

- **Login**: POST `/api/v1/auth/login` with `{"user_email": "...", "user_password": "..."}`. Returns `{"access_token": "...", "token_type": "bearer", "user_id": N}`.
- **Token**: HMAC-SHA256 format `base64(payload).signature` (`backend/app/auth/session.py`). Payload `{user_id, exp}`. Rights are **not** in the token — resolved from DB on every request.
- **Headers**: `Authorization: Bearer <token>`, `X-Client-Type: web`.
- **Storage**: `sessionStorage['token']`.
- **401 handling**: Axios interceptor clears session and redirects to `/login`.
- **Microsoft**: MSAL (`@azure/msal-browser`) on web, `aad_oauth` on Flutter. Backend validates via Graph API at POST `/api/v1/auth/microsoft`.
- **Secrets**: `AUTH_SECRET_KEY` env var. Must be set in production (`ENVIRONMENT=production` → hard fail if unset). Development default is `"please-change-this-secret"`. Generate: `python -c "import secrets; print(secrets.token_urlsafe(48))"`.
- **Password hashing**: PBKDF2-SHA256 via `backend/app/auth/security.py` (`hash_password`/`verify_password`). `passwords.py` re-exports from there.
- **SMTP reminders**: `backend/app/services/reminder_scheduler.py` checks calendar events every `REMINDER_CHECK_INTERVAL` (default 60s). Config in `backend/.env.example`.

### Test accounts (seeded on every startup via `backend/app/db/seed.py`)

| Login | Password | Role | Location | Notes |
|---|---|---|---|---|
| `admin@example.com` | `admin123` | Admin (3) | — | Full access |
| `kobus@gmail.com` | `kobus123` | Admin (3) | — | Full access |
| `fk@example.com` | `fk123` | FK Coord (2) | Leriba-kampus (loc=1) | Auto-filtered to campus |
| `jaco@gmail.com` | `jaco123` | FK Coord (2) | Gerhardstraat-kampus (loc=2) | Same |
| `test@example.com` | `password123` | User (1) | — | 403 on web |
| `piet@gmail.com` | `piet123` | User (1) | — | 403 on web |
| `jan.botha@workfix.co.za` | `contractor123` | Contractor (4) | — | Mobile-only |
| `lindiwe.mokoena@plumbright.co.za` | `contractor123` | Contractor (4) | — | Mobile-only |

## API

All routes under `/api/v1/`. Prefixes: `/auth`, `/assets`, `/assettypes`, `/rooms`, `/location`, `/building`, `/fault`, `/job`, `/stock`, `/users`, `/contractors`, `/quotes`, `/audit`, `/predictions`, `/image`, `/calendar` (+`/calendar/events`), `/roles`, `/rights`, `/documents`. Endpoints use PATCH for updates.

- `/auth/me` returns `UserRead` fields + `rights: list[str]` and `role_id`, `location_id`.
- API client: `frontend/src/services/api.js` — Axios instance with Bearer + `X-Client-Type` interceptors.
- Backend services: `backend/app/services/` — `BaseService` provides generic CRUD + audit logging.
- Rights system: endpoints use `Depends(require_right("right.name"))` (`backend/app/auth/permissions.py`). `RIGHTS_CATALOG` / `ROLE_RIGHTS` in `rights_catalog.py` are single source of truth.

## Database

- SQLModel ORM on PostgreSQL. Tables created + ALTER TABLE migrations run every startup (`backend/app/db/database.py:19`).
- **Role IDs are hardcoded by position**: User=1, FK Coordinator=2, Admin=3, Contractor=4. Never reorder seeding.
- Seed data (`backend/app/db/seed.py`) runs on every startup — idempotent (`_get_or_create_*` pattern).
- `backend/app/db/docker-compose.yml` is a standalone PostgreSQL (creds: `admin/1234/FMS`) — not the main compose.

## FK Coordinator terrain filtering

Users with `role_id === 2` and a `location_id` get their campus pre-selected on every list page (switchable). Filter bar uses a breadcrumb-style cascade (Terrein → Gebou → Lokaal) with `IoReturnUpBack` back button.

| Page | Items | Terrein lookup | Gebou lookup |
|---|---|---|---|
| **Assets** | Assets | `asset.room_id → room.building_id → building.location_id` | `asset.room_id → room.building_id` |
| **Stock** | Stock | `stock.room_id → room.building_id → building.location_id` | `stock.room_id → room.building_id` |
| **Fault Tickets** | Faultcards | `ticket.location_id` (direct) | `ticket.building_id` (direct) |
| **Work Orders** | Jobcards | `order.location_id` (direct) | `order.building_id` (direct) |
| **Buildings** | Buildings | `building.location_id` (direct) | building self-filter |
| **Rooms** | Rooms | `room.building_id → building.location_id` | `room.building_id` (direct) |

Pages with room-level items include a room-level filter too. FK auto-filter is switchable.

Admins assign terrain via **Users** page. Only FK users get auto-filtered; `location_id` on other roles is stored but ignored.

## Key files

| What | Where |
|---|---|
| Backend entry | `backend/app/main.py` |
| API router | `backend/app/api/api.py` |
| Auth + tokens | `backend/app/auth/session.py`, `permissions.py` |
| Rights catalog | `backend/app/auth/rights_catalog.py` |
| Seed data | `backend/app/db/seed.py` |
| DB migrations | `backend/app/db/database.py` |
| User/rights hooks | `frontend/src/hooks/useCurrentUser.js` |
| API client | `frontend/src/services/api.js` |
| Route protection | `frontend/src/App.jsx` (`ProtectedRoute`, `RightProtectedRoute`) |

## Quirks

- `frontendMobile/requirements.txt` is a **reference** — real deps are in `pubspec.yaml`.
- Backend volume mount `./backend:/app` overlays the full directory for hot-reload (`--reload`). Dockerfile copies only `app/` subdir.
- In dev (`npm start`), CRA proxy is **not** configured; requests go to `REACT_APP_API_URL` (default `http://localhost:8000`) directly. In Docker, nginx proxies `/api/` → backend.
- `backend/uploads/` stores uploaded images served via FastAPI `StaticFiles`. Runtime artifacts, not committed.
- `.vscode/settings.json` sets `dart.flutterSdkPath` to `/mnt/c/Users/V/Documents/Flutter/flutterlinux`.
- `AGENTS.md` is in `.gitignore` — changes not tracked.

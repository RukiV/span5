# AGENTS.md — span5 (FBS Facility Management System)

Project root is `branch/span5/` (not repo root). All paths below are relative there.

Stack: FastAPI backend (Python 3.12 + SQLModel) + React frontend (CRA 5.0.1) + Flutter mobile (`fbs`) + PostgreSQL 15 (Docker).

## First-time setup

```sh
cp .env.example .env && cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env && cp frontendMobile/.env.example frontendMobile/.env
docker compose up --build
```

Two sets of Azure AD client IDs exist: web (`fa4d...`) in root/frontend `.env`, mobile (`ee90...`) in `frontendMobile/.env`.

## Commands

```sh
docker compose up --build                     # full stack (web:3000, api:8000, db:5432)
docker compose down --volumes                 # if old audit-log volumes cause issues
uvicorn app.main:app --reload                 # backend standalone
npm start                                     # frontend standalone
cd frontendMobile && flutter pub get && flutter run
```

No tests, no lint, no typecheck scripts. `backend/tests/` is empty.

## Auth

- **Tokens**: Custom HMAC-SHA256 (`base64(payload).signature`), not JWT. Rights are DB-resolved per-request, not in the token.
- **Login**: `POST /api/v1/auth/login` with `{user_email, user_password}` → `{access_token, token_type, user_id}`. Legacy plaintext passwords are auto-upgraded to PBKDF2-SHA256 on first login.
- **Secret**: `AUTH_SECRET_KEY` env var. Dev default: `"please-change-this-secret"`. Production (`ENVIRONMENT=production`) hard-fails if unset. Generate: `python -c "import secrets; print(secrets.token_urlsafe(48))"`.
- **Web-vs-mobile**: Roles 2 (FK Coord) and 3 (Admin) use web. Roles 1 (User) and 4 (Contractor) get 403 on web unless `X-Client-Type: mobile` header is set. This is a UX gate, not a security boundary — endpoint rights checks do the real enforcement.
- **Headers**: `Authorization: Bearer <token>` + `X-Client-Type: web` (or `mobile`).
- **Microsoft SSO**: `@azure/msal-browser` on web, `aad_oauth` on Flutter. Backend validates via Graph API at `POST /api/v1/auth/microsoft`.
- **Rights**: `backend/app/auth/rights_catalog.py` is the single source of truth (`RIGHTS_CATALOG` / `ROLE_RIGHTS`). Endpoints use `Depends(require_right("right.name"))`.

### Test accounts (seeded every startup — `backend/app/db/seed.py`)

| Login | Password | Role | Notes |
|---|---|---|---|
| `admin@example.com` | `admin123` | Admin (3) | Full access |
| `kobus@gmail.com` | `kobus123` | Admin (3) | Full access |
| `fk@example.com` | `fk123` | FK Coord (2) | Filtered to Leriba-kampus |
| `jaco@gmail.com` | `jaco123` | FK Coord (2) | Filtered to Gerhardstraat-kampus |
| `test@example.com` | `password123` | User (1) | 403 on web |
| `piet@gmail.com` | `piet123` | User (1) | 403 on web |
| `jan.botha@workfix.co.za` | `contractor123` | Contractor (4) | Mobile-only |
| `lindiwe.mokoena@plumbright.co.za` | `contractor123` | Contractor (4) | Mobile-only |

## Database

- **No migrations framework**: `backend/app/db/database.py:19` runs `SQLModel.metadata.create_all` + raw `ALTER TABLE IF NOT EXISTS` on every startup.
- **Seed runs every startup**: idempotent via `_get_or_create_*` helpers.
- **Role IDs are hardcoded by seed order**: User=1, FK Coord=2, Admin=3, Contractor=4. Never reorder.
- Standalone DB: `backend/app/db/docker-compose.yml` (PostgreSQL 16, `admin/1234/FMS`).

## Key files

| What | Where |
|---|---|
| Backend entry | `backend/app/main.py` |
| API router | `backend/app/api/api.py` (aggregates 20 routers under `/api/v1/`) |
| Auth | `backend/app/auth/session.py`, `permissions.py` |
| Rights catalog | `backend/app/auth/rights_catalog.py` |
| Seed | `backend/app/db/seed.py` |
| Backend services | `backend/app/services/` (generic `BaseService<T>` CRUD + auto audit logging) |
| API client | `frontend/src/services/api.js` (Axios, Bearer + X-Client-Type interceptors) |
| Route protection | `frontend/src/App.jsx` (`ProtectedRoute`, `RightProtectedRoute`) |

## Quirks

- `frontendMobile/requirements.txt` is a **reference** doc — real deps are in `pubspec.yaml`.
- Backend Docker volume `./backend:/app` overlays the full dir for hot-reload. Dockerfile only copies `app/`.
- CRA proxy is not configured. In dev, requests go directly to `REACT_APP_API_URL` (default `http://localhost:8000`). In Docker, nginx proxies `/api/` → backend.
- `backend/uploads/` stores uploaded images (served via FastAPI `StaticFiles`). Gitignored — runtime artifacts.
- Auth has no server-side token invalidation (stateless HMAC). Logout is client-only; token stays valid until expiry (default 2h).
- `.vscode/settings.json` points `dart.flutterSdkPath` to a Windows-local path — adjust per developer.
- This file is in `.gitignore` — changes won't be tracked.

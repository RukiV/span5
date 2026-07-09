# FBS — Fasiliteitsbestuurstelsel

'n Volstapel fasiliteitsbestuurstelsel vir **Akademia**. Die stelsel maak voorsiening vir die bestuur van bates, foute/jobkaarte, voorraad, kontrakteurs, kwotasies, en verslaggewing oor verskeie kampusse. Dit sluit 'n webkoppelvlak (React) vir administrateurs en koördineerders in, asook 'n mobiele toepassing (Flutter) vir veldverslaggewing deur studente en kontrakteurs.

---

## Kenmerke

- **Batebestuur** — Driespoorbates (projekte, stoele, ens.) per vertrek/gebou/kampus met reeksnommers, beelde en geskiedenis
- **Foutmelding** — Meld en volg foute met prioriteitsvlakke, beelde en GPS-koördinate
- **Werkkaarte (Job Cards)** — Sleep, skeduleer en bestuur instandhoudingswerk gekoppel aan foute/bates
- **Voorraadbestuur** — Hanteer verbruiksgoedere en onderdele met minimumvoorraadwaarskuwings
- **Kontrakteursbestuur** — Kontrakteursdatabasis met kontakbesonderhede en spesialisasies
- **Kwotasiebestuur** — Versoek en bestuur kwotasies van kontrakteurs
- **Ligginghiërargie** — Ligging (Kampus) > Gebou > Vertrek
- **Rolgebaseerde toegang** — Gebruiker (mobiel), FK Koördineerder, Administrateur
- **Ouditlog** — Alle CRUD-bewerkings word outomaties met voor-en-na-waardes aangeteken
- **Dashboard en ontleding** — Grafieke (Chart.js), aktiwiteitsvoer, statusopsommings
- **Microsoft 365-inteegrasie** — Microsoft-rekening (MST) aanmelding en kalenderintegrasie
- **Mobiele toepassing** — Flutter-app met GPS, kamera, QR/strepieskode skandering, biometrie

---

## Tegnologieë

| Laag | Tegnologie |
|---|---|
| **Backend** | Python 3.12, FastAPI, SQLModel, SQLAlchemy, Pydantic v2, PostgreSQL 15, Uvicorn |
| **Frontend Web** | React 18, React Router v6, Axios, Chart.js, MSAL (Azure AD), Nginx |
| **Mobiel** | Flutter 3.1+ / Dart 3.1+, Dio, flutter_map, Google Maps, mobiele scanner |
| **Infrastruktuur** | Docker Compose, GitLab |

---

## Vereistes

- [Docker](https://docs.docker.com/get-docker/) en [Docker Compose](https://docs.docker.com/compose/install/) **(aanbeveel)**
- OF:
  - Python 3.12 en `pip`
  - Node.js 18 en `npm`
  - Flutter 3.1+ / Dart 3.1+ (vir mobiele toepassing)
- PostgreSQL 15 (via Docker of plaaslik)
- Microsoft Azure AD-rekening vir MST-aanmelding (opsioneel)

---

## Opstelling

1. **Kopieer die omgewingslêers:**
   ```bash
   cp .env.example .env
   cp backend/.env.example backend/.env
   cp frontend/.env.example frontend/.env
   ```

2. **Konfigureer Microsoft Azure AD** (sien volledige gids in [MICROSOFT_LOGIN_SETUP.md](./MICROSOFT_LOGIN_SETUP.md)) vir MST-aanmelding.
3. **Vul jou `.env`-lêers** in met die korrekte waardes (Azure-databasis, geheime-sleutels, ens.).

---

## Hardloop die stelsel

### Met Docker (aanbeveel)
```bash
# Bou en begin alle dienste
docker compose up --build

# Of in die agtergrond:
docker compose up -d
```

### Handmatig (ontwikkeling)

**Backend:**
```bash
python -m uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

**Frontend Web:**
```bash
cd frontend
npm install
npm start
```

**Mobiele App:**
```bash
cd frontendMobile
flutter pub get
flutter run
```

---

## Toegang

| Dien | URL |
|---|---|
| **Frontend Web** | http://localhost:3000 |
| **API (Swagger UI)** | http://localhost:8000/docs |
| **API (ReDoc)** | http://localhost:8000/redoc |

### Toetsgeloofsbriewe

| Gebruikersnaam / E-pos | Wagwoord | Rol |
|---|---|---|
| `admin` / `admin@example.com` | `admin123` | Administrateur (volle toegang) |
| `fk` / `fk@example.com` | `fk123` | FK Koördineerder (beperkte toegang) |
| `test` / `test@example.com` | `password123` | Gebruiker (Web-aanmelding geweier, mobiel slegs) |

---

## Projekstruktuur

```
span5/
├── backend/              # Python FastAPI-bediener
│   ├── app/
│   │   ├── api/         # REST-eindpunte
│   │   ├── auth/        # Verifikasie en sessies
│   │   ├── db/          # Databasisskema en saadlading
│   │   ├── models/      # SQLModel-modelle
│   │   └── services/    # Besigheidslogika
│   └── requirements.txt  # Python-afhanklikhede
├── frontend/             # React-webtoepassing
│   ├── src/
│   │   ├── components/  # Herbruikbare komponente
│   │   ├── pages/       # Blaaie
│   │   ├── services/    # API-kliënt en MST-konfigurasie
│   │   └── styles/      # CSS-lêers
│   └── package.json
├── frontendMobile/       # Flutter-mobiele toepassing
│   ├── lib/
│   │   ├── core/        # App-kern (kleure, API-kliënt, navigasie)
│   │   ├── models/      # Datamodelle
│   │   ├── pages/       # Blaaie
│   │   ├── services/    # Besigheidsdienste
│   │   └── widgets/     # Hergebruikbare stel-komponente
│   └── pubspec.yaml
├── docker-compose.yml  # Docker-or-komposisie
└── MICROSOFT_LOGIN_SETUP.md
```

---

## Lêer

Hierdie projek is ontwikkel as deel van die NWIW370-module by Akademia.
# Alpha-vrystelling — FBS (Fasiliteitsbestuurstelsel)

**Weergawe:** v0.1.0-alpha  
**Datum:** Julie 2026  
**Status:** Alpha — slegs vir toets- en ontwikkelingsdoeleindes

---

## Oorsig

Hierdie is die eerste alpha-vrystelling van die Fasiliteitsbestuurstelsel (FBS) vir Akademia. Die stelsel bied 'n grondslag vir die bestuur van fasiliteitsverwante bedrywighede, insluitend bate-opsporing, foutmelding, werkkaarte, voorraad, en kontrakteursbestuur.

---

## Wat is ingesluit

### Kernfunksionaliteit
- Gebruikersverifikasie (e-pos/wagwoord en Microsoft-rekening via Azure AD)
- Rolgebaseerde toegang (Administrateur, FK Koördineerder, Gebruiker)
- Batebestuur met volledige geskiedenis en beeldoplaai
- Foutmelding met prioriteitsvlakke, beelde, en GPS-koördinate
- Werkkaart (Job Card) skep en bestuur
- Voorraadbestuur met minimumvoorraadwaarskuwings
- Kontrakteursdatabasis en bestuur
- Kwotasiebestuur
- Ligginghiërargie: Kampus > Gebou > Vertrek
- Outomatiese ouditlog vir alle CRUD-bewerkings
- Dashboard met grafieke en aktiwiteitsvoer
- Verslaggewing (basies)
- Microsoft 365-kalenderintegrasie

### Platforms
- **Web-toepassing** (React) — volle kenmerkstelsel vir administrateurs en koördineerders
- **Mobiele toepassing** (Flutter) — veldverslaggewing met kamera, GPS, QR-skandering, en biometrie
- **API** (FastAPI) — volle REST-koppelvlak met SwUI/ReDoc-dokumentasie

---

## Bekende probleme en beperkinge

- **Databasis:** Outomatiese migrasies nog nie ten volle geïmplementeer nie; tabelle word met `create_all()` geskep
- **Toetsdekking:** Min outomatiese toetse ingesluit; handmatige toetsing word benodig
- **Sekuriteitsoudit:** Nie formeel geoudit nie; sessies word met HMAC (nie-met standaard JWT) geïmplementeer
- **Mobiele app:** Sommige sketse (kaarte, QR-skandering) werk dalk nie op alle toestelle nie
- **Microsoft-integraasie:** Vereis handmatige Azure AD-opstelling (sien `MICROSOFT_LOGIN_SETUP.md`)
- **Stelseltaal:** Koppelvlakke is in Afrikaans, maar sommige foutboodskappe is nog in Engels
- **Saadlading:** Slegs basis-saaddata word ingesluit vir toetsdoeleindes
- **Stabiliteit:** Alpha-sagteware — dataverlies of korrupsie moontlik; rugsteun gereeld

---

## Installasie en opstelling

Sien [READ.md](./README.md) en [MICROSOFT_LOGIN_SETUP.md](./MICROSOFT_LOGIN_SETUP.md) vir volledige instruksies.

**Kort opsomming:**
```bash
cp .env.example .env
docker compose up --build
```

Toegang tot die web-toepassing: http://localhost:3000

---

## Aanbevelings vir gebruikers

- Gebruik Docker Compose vir die beste ervaring
- Deelname op die `admin`-rekening vir volle toegang tot die stelsel
- Stel gereelde databasis-rugsteune op
- Rapporteer probleme en foute vir die volgende vrystelling

---

## Volgende stappe (beoog vir v0.2.0)

- Voltooide migraties
- Verbeterde toetsdekking
- Formele sekuriteitsoud
- Verbeterde mobiele app (iOS-optimalisatie)
- Volledige verbetering van stafvertaling
- CI/CD-opstelling
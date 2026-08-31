<<<<<<< HEAD
# FBS Mobile (Flutter)

Die mobiele FBS-app. Toegang word beheer deur rolle/regte vanaf die backend
(`/auth/me` se `rights`-lys) — die menu (Fasiliteite, Foutkaartjies,
Gebruikers, ens.) word dinamies opgebou volgens die ingetekende gebruiker se
regte.

## Voorvereistes

- Flutter SDK (≥ 3.1.0) — `flutter --version`
- 'n Hardloopende backend (FastAPI) vir die app — sien die hoof-`README.md`
  in die projekwortel.

## Opstel

```sh
flutter pub get
```

- Kopieer `.env.example` na `.env` en stel jou API-konfigurasie:
  - `API_URL` — jou backend-adres, bv. `http://192.168.1.95:8000/api/v1`.
    Op die Android-emulator gebruik jy `http://10.0.2.2:8000/api/v1`.
  - Azure/OAuth-kliënt-inligting vir aanmelding.
- `frontendMobile/.env` is nie in git nie (git-ignore) — elke ontwikkelaar
  stel sy eie waardes.

## Loop die app

```sh
flutter run
```

Statiese analise:

```sh
flutter analyze
```

## Struktuur

- `lib/pages/` — skerms (bates, voorraad, terreine, foutkaartjies, gebruikers…)
- `lib/widgets/` — hergebruikbare UI (soekbare aftreklys, ligging-kaskade-kieser)
- `lib/services/` — API-dienslaag (Dio) met `ValueNotifier`s vir UI-opdaterings
- `lib/core/` — `ApiClient`, kleure, navigasie-sleutel
=======
# untitled

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
>>>>>>> a6cc9b7400a2a627147078aeed60cfe907bbb8c3

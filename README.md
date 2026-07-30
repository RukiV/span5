## Vereistes

* Docker Desktop Installed
* Vscode
* Microsoft rekening vir Microsoft-aanmelding (opsioneel)
* Moet jy 'n foon hê met USB debugging enabled.
* Flutter SDK moet installed wees.

## Opstelling:

Hardloop die volgende commands sodat die .env files geskep kan word.

```shell
cp .env.example .env
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
cp frontendmobile/.env.example frontendmobile/.env
```

of skep die .env leers self en kopieer die inhoud van die .env.example files oor.

## Hardloop die stelsel

#### Vir webblad, backend en databasis

Maak docker desktop oop.

Run "docker compose up --build" in root van folder.

Wag tot Application startup complete wys en alle seed rekords ingelaai is.

Webblad kan opgemaak word op localhost:3000.

(As probleme kry run docker compose down --volumes oor auditlogging probleme kan veroorsaak as jy ou volumes het. )

#### Vir mobile om te werk:

Moet jy 'n foon connected met usb debugging hê.

Hardloop die volgende commands in terminal in die root van die folder:

```shell
cd frontendMobile
pip install -r requirements.txt
flutter pub get
flutter run
```

Note: As probleme ervaar met requirements.txt install. Is daar 'n goeie kans jy kan net verder aangaan met die volgende command.

## Firebase (FCM-stootkennisgewings) Opstelling

Die stelsel gebruik Firebase Cloud Messaging (FCM) om stootkennisgewings na die mobiele app te stuur.
Hierdie opstelling is nodig as jy die stelsel vir 'n nuwe omgewing ontplooi (nie my oorspronklike Firebase-projek nie).

### Stap 1: Skep 'n Firebase-projek

1. Gaan na https://console.firebase.google.com/
2. Klik **"Create a project"** of **"Add project"**
3. Gee dit 'n naam (bv. "FBS-Production") en voltooi die stappe

### Stap 2: Registreer die Android-app

1. In die Firebase Console, klik die Android-ikoon om 'n Android-app by te voeg
2. **Android package name**: `com.example.fbs` (of wat ook al in `frontendMobile/android/app/build.gradle` se `applicationId` staan)
3. **App nickname**: "FBS Mobile"
4. **Debug signing certificate SHA-1**: Los oop (opsioneel)
5. Laai die `google-services.json` af en plaas dit in:
   ```
   frontendMobile/android/app/google-services.json
   ```
   (Hierdie lêer word tans deur `frontendMobile/android/app/build.gradle` ingelees)

### Stap 3: (Opsioneel) Registreer die iOS-app

1. In Firebase Console, klik die iOS-ikoon
2. **iOS bundle ID**: `com.example.fbs` (of wat in Xcode se projektelling staan)
3. Laai die `GoogleService-Info.plist` af en plaas dit in `frontendMobile/ios/Runner/`
4. **Pas op**: As jy iOS ondersteun, moet jy ook die APNs-sleutel in Firebase oplaai

### Stap 4: Skep 'n Firebase Admin SDK-rekening (vir die backend)

Die backend gebruik `firebase-admin` om FCM-berigte te stuur. Dit het 'n diensrekening-sleutel nodig.

1. In Firebase Console, gaan na **Project Settings** > **Service accounts**
2. Klik **"Generate new private key"**
3. Laai die JSON-lêer af en hernoem dit na `firebase-service-account.json`
4. Plaas dit in:
   ```
   backend/firebase-service-account.json
   ```
   (Hierdie lêer is in `.gitignore` — dit word nie in die repo gestoor nie. Gebruik `backend/firebase-service-account.json.example` as verwysing vir die formaat.)

### Stap 5: Werking

- **Mobiele app (Flutter)**: Wanneer die gebruiker aanmeld, registreer die app outomaties die FCM-toestel-token by `POST /api/v1/notifications/device-token`
- **Backend (Python)**: Wanneer `NotificationService.create_notification()` 'n kennisgewing skep, stuur dit die FCM-berig na alle geregistreerde toestelle vir daardie gebruiker (mits `push_enabled=True` in die voorkeure)
- Firewall-reël: Die backend benodig **uitgaande** internettoegang na `fcm.googleapis.com` (poort 443) om FCM-berigte te stuur
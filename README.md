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
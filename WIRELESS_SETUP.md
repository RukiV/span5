# Wireless Setup Guide (MacBook M4 + Samsung S22 Ultra)

Set up wireless app building for the Flutter mobile app (`frontendMobile`) on a Samsung Galaxy S22 Ultra from a MacBook M4, no USB cable needed after pairing.

## Prerequisites

- Flutter SDK installed
- Android SDK platform-tools (adb) installed
- Samsung S22 Ultra on Android 11+ (One UI)
- Phone and MacBook on the same Wi-Fi network

## Phone Configuration

### 1. Enable Developer Options

1. Go to **Settings** → **About phone** → **Software information**
2. Tap **Build number** 7 times until "Developer mode has been enabled" appears

### 2. Enable Debugging

1. Go to **Settings** → **Developer options**
2. Enable **USB debugging**
3. Enable **Wireless debugging**
4. Tap **Wireless debugging** to open its screen — leave it open

## Mac Configuration

Add the Android platform-tools to your shell PATH:

```bash
echo 'export PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"' >> ~/.zshrc
source ~/.zshrc
adb version
```

You should see the adb version output (e.g. `Android Debug Bridge version 1.0.41`).

## Pairing & Connecting

### 1. Pair the Device

1. On the phone's **Wireless debugging** screen, tap **Pair device with pairing code**
2. Note the **IP address and port** and the **6-digit pairing code** shown
3. On the Mac:

```bash
adb pair <phone-ip>:<pair-port>
```

When prompted, enter the 6-digit pairing code shown on the phone.

### 2. Connect

```bash
adb connect <phone-ip>:<wireless-port>
adb devices
```

The S22 should appear with status `device` (not `offline` or `unauthorized`).

> The IP and both ports are shown on the phone's Wireless debugging screen. The pairing port and connect port are different — make sure you use the right one for each command.

## Building & Running the App

```bash
cd frontendMobile
flutter devices
flutter run -d <device-id>
```

The S22 Ultra should be listed as a device. `flutter run` builds the app and installs it wirelessly. Rebuilds/hot reload (`r`) also work over the wireless connection.

### Fast path: both devices at once

Backend (postgres + backend, no web frontend) + launch on **all** connected devices:

```bash
./scripts/dev-mobile.sh
```

Equivalent manual steps:

```bash
docker compose up -d postgres backend          # backend up in seconds, no --build
cd frontendMobile
flutter run -d all --dart-define=API_URL=http://<mac-ip>:8000/api/v1
```

- `-d all` launches on the S22 and any other connected device (e.g. iPhone) simultaneously; hot reload (`r`) hits both.
- `API_URL` via `--dart-define` overrides `.env`, so no file edits when your Mac's IP changes.
- Rebuild Docker images only when `backend/requirements.txt` changes: `docker compose build backend`.

## Troubleshooting

**"adb: no devices/emulators found"**
- Verify phone and Mac are on the same Wi-Fi network
- Make sure the Wireless debugging screen is still open on the phone
- Re-connect with: `adb connect <phone-ip>:<wireless-port>`

**"device unauthorized"**
- Check the phone screen and accept the RSA fingerprint prompt

**Connection drops during long builds / phone locks**
- Samsung aggressively kills the adb process in the background. To prevent disconnects:
  - Keep the screen awake while building
  - Disable battery optimization for **Wireless debugging** (Settings → Apps → show system apps → Wireless debugging → Battery → Unrestricted)
  - Reconnect with `adb connect <phone-ip>:<wireless-port>` (no re-pairing needed)

**Ports changed**
- The wireless debugging ports change on re-pair. Re-check the phone's Wireless debugging screen and re-run `adb connect` with the current port.

**"adb not found"**
- Run `source ~/.zshrc` or open a new terminal so the PATH change takes effect
- Verify the SDK path exists: `~/Library/Android/sdk/platform-tools/adb`

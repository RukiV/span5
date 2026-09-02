#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Optional override: ./dev-mobile.sh <mac-lan-ip> [extra flutter args...]
IP="${1:-}"
EXTRA_ARGS=("${@:2}")

echo "==> Starting mobile-only stack (postgres + backend, no web frontend)..."
docker compose -f "$ROOT/docker-compose.yml" up -d postgres backend

echo "==> Waiting for backend on :8000..."
for _ in $(seq 1 60); do
  if curl -sf http://127.0.0.1:8000/ >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -sf http://127.0.0.1:8000/ >/dev/null 2>&1; then
  echo "ERROR: backend did not become healthy on :8000 after 60s. Check: docker compose logs backend"
  exit 1
fi

if [ -z "$IP" ]; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [ -z "$IP" ]; then
  echo "ERROR: could not detect Mac LAN IP. Pass it as the first argument."
  exit 1
fi
echo "==> API URL for phones: http://$IP:8000/api/v1"

cd "$ROOT/frontendMobile"

DEVICES="$(flutter devices 2>/dev/null | grep -cE '^  ' || true)"

if [ "$DEVICES" -ge 1 ]; then
  echo "==> Launching app on all connected devices ($DEVICES found)..."
  flutter run -d all --dart-define=API_URL="http://$IP:8000/api/v1" "${EXTRA_ARGS[@]}"
else
  echo "==> No devices connected. Backend is up; run once devices are available:"
  echo "    cd frontendMobile && flutter run -d all --dart-define=API_URL=http://$IP:8000/api/v1"
fi

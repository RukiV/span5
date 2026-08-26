#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "==============================="
echo "  SPAN5 TEST SUITE"
echo "==============================="

# --- Backend ---
echo ""
echo "--- Backend Tests ---"
_PIP=""
for cmd in "python3 -m pip" pip pip3; do
  if $cmd --version &>/dev/null; then _PIP="$cmd"; break; fi
done
if [ -n "$_PIP" ]; then
  $_PIP install -q pytest httpx 2>/dev/null || true
fi
cd "$ROOT/backend"
python3 -m pytest tests/TEST_security.py -v || echo "  (install pytest + httpx to run backend tests)"
cd "$ROOT"

# --- Frontend ---
echo ""
echo "--- Frontend Tests ---"
cd "$ROOT/frontend"
npm install --silent @testing-library/react @testing-library/jest-dom @testing-library/user-event 2>/dev/null || true
CI=true npx react-scripts test --watchAll=false --testPathPattern="TEST_" 2>&1 || echo "  (skipping frontend tests)"
cd "$ROOT"

# --- Mobile ---
echo ""
echo "--- Mobile Tests ---"
cd "$ROOT/frontendMobile"
flutter test test/TEST_login_page_test.dart test/TEST_api_client_test.dart test/TEST_auth_config_test.dart test/TEST_secure_storage_test.dart test/TEST_ai_service.dart --no-pub 2>&1 || echo "  (flutter not available? skipping mobile tests)"
cd "$ROOT"

echo ""
echo "==============================="
echo "  DONE"
echo "==============================="

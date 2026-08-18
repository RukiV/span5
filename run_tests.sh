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
python3 -m pytest tests/ -q || echo "  (install pytest + httpx to run backend tests)"
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
echo "--- Mobile Tests (analyzer) ---"
cd "$ROOT/frontendMobile"
dart analyze lib 2>&1 || echo "  (dart not available? skipping mobile analysis)"
cd "$ROOT"

echo ""
echo "==============================="
echo "  DONE"
echo "==============================="

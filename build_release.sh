#!/usr/bin/env bash
# GreenGains — Release build script
# Usage: ./build_release.sh [android|ios|both]
#
# Required env vars (set once in your shell profile or pass inline):
#   BACKEND_API_KEY  — your backend API key (never commit this)
#   BACKEND_URL      — defaults to https://greengains.onrender.com

set -euo pipefail

TARGET="${1:-android}"

# ── Validate env vars ──────────────────────────────────────────────────────────
if [[ -z "${BACKEND_API_KEY:-}" ]]; then
  echo "ERROR: BACKEND_API_KEY is not set."
  echo "  Export it:  export BACKEND_API_KEY='your-key-here'"
  exit 1
fi

BACKEND_URL="${BACKEND_URL:-https://greengains.onrender.com}"

# ── Generate dart_defines.json ────────────────────────────────────────────────
DEFINES_FILE="dart_defines.json"
cat > "$DEFINES_FILE" <<EOF
{
  "BACKEND_API_KEY": "$BACKEND_API_KEY",
  "BACKEND_URL": "$BACKEND_URL"
}
EOF
echo "✓ dart_defines.json written"

# ── Build ─────────────────────────────────────────────────────────────────────
FLUTTER="${FLUTTER_BIN:-flutter}"

build_android() {
  echo "→ Building Android App Bundle..."
  "$FLUTTER" build appbundle \
    --release \
    --dart-define-from-file="$DEFINES_FILE"
  echo "✓ Android: build/app/outputs/bundle/release/app-release.aab"
}

build_ios() {
  echo "→ Building iOS archive..."
  "$FLUTTER" build ipa \
    --release \
    --dart-define-from-file="$DEFINES_FILE"
  echo "✓ iOS: build/ios/ipa/"
}

case "$TARGET" in
  android) build_android ;;
  ios)     build_ios ;;
  both)    build_android && build_ios ;;
  *)
    echo "ERROR: Unknown target '$TARGET'. Use: android | ios | both"
    exit 1
    ;;
esac

# ── Cleanup ───────────────────────────────────────────────────────────────────
rm -f "$DEFINES_FILE"
echo "✓ dart_defines.json removed"
echo ""
echo "Build complete."

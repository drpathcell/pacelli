#!/usr/bin/env bash
# Pacelli — build + upload to TestFlight via App Store Connect API key.
# Usage: ./scripts/upload_testflight.sh
#
# Prereqs (one-time):
#   ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 exists
#   API_KEY_ID and API_ISSUER_ID set below
#
# Bumps build number, builds release IPA, uploads. No Xcode, no Transporter GUI.

set -euo pipefail

API_KEY_ID="MMWTC97VR7"
API_ISSUER_ID="bd761522-6b87-4462-a82e-fedf7aff7f73"
PROJECT_DIR="$HOME/Developer/pacelli"
IPA_PATH="$PROJECT_DIR/build/ios/ipa/Pacelli.ipa"
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"
ITMS="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"

cd "$PROJECT_DIR"

# Sanity checks
[[ -f "$KEY_PATH" ]] || { echo "ERROR: API key missing at $KEY_PATH"; exit 1; }
[[ -x "$ITMS" ]]    || { echo "ERROR: iTMSTransporter missing — install Transporter from Mac App Store"; exit 1; }

# Bump build number (the +N part of "1.0.0+N" in pubspec.yaml)
current=$(grep -E '^version:' pubspec.yaml | sed -E 's/.*\+([0-9]+).*/\1/')
next=$((current + 1))
sed -i '' -E "s/^(version: [0-9.]+)\+${current}/\1+${next}/" pubspec.yaml
echo "==> Bumped build number $current → $next"

# Build
echo "==> Cleaning + building IPA (this takes 5–10 min)..."
flutter clean >/dev/null
flutter pub get >/dev/null
flutter build ipa --release

[[ -f "$IPA_PATH" ]] || { echo "ERROR: IPA not produced at $IPA_PATH"; exit 1; }
echo "==> IPA built: $(du -h "$IPA_PATH" | cut -f1)"

# Pre-flight network check
echo "==> Checking Apple CDN reachability..."
if ! nc -zv -w 5 contentdelivery02.itunes.apple.com 443 >/dev/null 2>&1; then
  echo "WARNING: contentdelivery02.itunes.apple.com:443 unreachable."
  echo "         Try iPhone hotspot or check Apple System Status."
  echo "         Continuing anyway — iTMSTransporter has internal retries."
fi

# Upload — limit concurrent parts and raise timeouts for flaky networks
echo "==> Uploading to App Store Connect..."
"$ITMS" -m upload \
  -assetFile "$IPA_PATH" \
  -apiKey "$API_KEY_ID" \
  -apiIssuer "$API_ISSUER_ID" \
  -t Signiant \
  -k 100000

echo ""
echo "==> Done. Build will appear in TestFlight in ~15–30 min."
echo "    https://appstoreconnect.apple.com/apps"

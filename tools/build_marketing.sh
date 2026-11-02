#!/usr/bin/env bash
# Builds the 30-day demo APK handed to a marketer.
#   tools/build_marketing.sh "اسم المسوّق" [days]
# The end date is fixed here at build time. There is deliberately no
# GEMINI_API_KEY define: the AI features switch themselves off, so no secret
# ships inside a copy that leaves your hands.
set -euo pipefail
cd "$(dirname "$0")/.."

HOLDER="${1:?usage: build_marketing.sh \"marketer name\" [days]}"
DAYS="${2:-30}"
EXPIRY="$(date -v+"${DAYS}"d +%Y-%m-%d)"

flutter build apk --release --obfuscate --split-debug-info=build/marketing-symbols \
  --dart-define=MARKETING_EXPIRY="$EXPIRY" \
  --dart-define="MARKETING_HOLDER=$HOLDER"

OUT="build/ayadati-demo-$EXPIRY.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
echo "Built $OUT (valid until $EXPIRY, for: $HOLDER)"

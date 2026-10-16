#!/bin/sh
# Build the Flutter Android APK for production, pointing to the live backend.
#
# The API base URL is a compile-time value configured via String.fromEnvironment.
# This script ensures the production URL from .env.production is baked in.

set -e

echo "▶ Building Android APK with API_BASE_URL from .env.production"
grep API_BASE_URL .env.production || {
  echo "✗ .env.production is missing API_BASE_URL — aborting."; exit 1;
}
echo ""

flutter build apk --release --dart-define-from-file=.env.production "$@"

echo ""
echo "✓ Done. The release APK is located at: build/app/outputs/flutter-apk/app-release.apk"

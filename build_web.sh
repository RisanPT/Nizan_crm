#!/bin/sh
# Build the Flutter WEB app for production, pointing it at the live backend.
#
# Why this script exists: the API base URL is a COMPILE-TIME value
# (String.fromEnvironment in lib/providers/dio_provider.dart). If you run a
# plain `flutter build web`, it falls back to http://localhost:5001/api and the
# deployed site can't reach the backend from any device — the app just hangs on
# the loading screen. This bakes in the production URL from .env.production
# (API_BASE_URL=https://api.teamnmakeovers.com/api).
#
# Usage:
#   ./build_web.sh                 # production build → build/web
#   ./build_web.sh --profile       # extra flutter args are passed through
#
# Then upload the ENTIRE build/web folder to Netlify.

set -e

echo "▶ Building web with API_BASE_URL from .env.production"
grep API_BASE_URL .env.production || {
  echo "✗ .env.production is missing API_BASE_URL — aborting."; exit 1;
}
echo ""

flutter build web --release --dart-define-from-file=.env.production "$@"

echo ""
echo "✓ Done. Upload the build/web folder to Netlify."
echo "  Tip: after deploying, test in a PRIVATE/incognito window (or hard-refresh"
echo "  with Ctrl/Cmd+Shift+R) — Flutter's service worker caches the old build."

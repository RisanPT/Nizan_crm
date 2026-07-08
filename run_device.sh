#!/bin/sh
# Run the app on a connected device/emulator, pointing it at the backend on
# this Mac's current Wi-Fi IP. Auto-detects the IP so it survives DHCP changes.
#
# Usage:
#   ./run_device.sh                 # detect IP, run on the default device
#   ./run_device.sh -d <deviceId>   # extra flutter args are passed through
#   PORT=5001 ./run_device.sh       # override backend port (default 5001)

PORT="${PORT:-5001}"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"

if [ -z "$IP" ]; then
  echo "Could not detect a Wi-Fi IP (are you on Wi-Fi?). Falling back to localhost."
  IP="localhost"
fi

API="http://$IP:$PORT/api"
echo "▶ Backend: $API"
echo "▶ Make sure the backend is running and the phone is on the same Wi-Fi."
echo ""

exec flutter run --dart-define=API_BASE_URL="$API" "$@"

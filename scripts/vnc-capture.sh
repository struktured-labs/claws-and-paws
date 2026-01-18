#!/bin/bash
# Capture screenshot from Windows VNC server

VNC_HOST="${1:-192.168.1.157}"
VNC_PORT="${2:-5900}"
VNC_PASSWORD="${3:-winmage}"
OUTPUT_FILE="${4:-/tmp/studio-screenshot.png}"

# Activate venv with vncdotool
source /tmp/vnc-tools/bin/activate

# Capture screenshot
echo "📸 Capturing screenshot from ${VNC_HOST}:${VNC_PORT}..."

# Create password file
echo "$VNC_PASSWORD" > /tmp/vnc-passwd.tmp

# Use vncdo to capture
vncdo -s "${VNC_HOST}::${VNC_PORT}" --password "$VNC_PASSWORD" capture "$OUTPUT_FILE" 2>&1

# Clean up password file
rm -f /tmp/vnc-passwd.tmp

if [ -f "$OUTPUT_FILE" ]; then
    echo "✅ Screenshot saved to: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "❌ Failed to capture screenshot"
    exit 1
fi

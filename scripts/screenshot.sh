#!/bin/bash
# Take screenshot from Windows PC and view it

SSH_KEY=~/.ssh/winmage_key
WIN_HOST="struk@192.168.1.200"
WIN_SCREENSHOT="C:\\temp\\screen.png"
LOCAL_SCREENSHOT="/tmp/winmage-screen.png"

# Trigger screenshot via scheduled task (runs in user session)
ssh -i $SSH_KEY $WIN_HOST "schtasks /run /tn 'Screenshot'" 2>/dev/null

# Wait for capture
sleep 1

# Download
scp -i $SSH_KEY $WIN_HOST:"C:/temp/screen.png" $LOCAL_SCREENSHOT 2>/dev/null

# Report
if [ -f "$LOCAL_SCREENSHOT" ]; then
    SIZE=$(ls -lh $LOCAL_SCREENSHOT | awk '{print $5}')
    echo "Screenshot saved: $LOCAL_SCREENSHOT ($SIZE)"
else
    echo "Failed to capture screenshot"
fi

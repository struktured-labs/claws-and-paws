#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "vncdotool>=1.0.0",
#   "twisted>=23.0.0",
# ]
# ///
"""
VNC Remote Control for Roblox Studio on winmage

Usage:
    uv run scripts/vnc-control.py screenshot ./tmp/screen.png
    uv run scripts/vnc-control.py click 352 50
    uv run scripts/vnc-control.py type "Hello"
    uv run scripts/vnc-control.py key enter
    uv run scripts/vnc-control.py move 960 540
"""

from vncdotool import api
import time
import sys

VNC_HOST = '192.168.1.200'
VNC_PORT = 5900
VNC_PASSWORD = 'winmage'

def vnc_command(command, *args):
    """Execute VNC command on winmage"""
    client = api.connect(f'{VNC_HOST}::{VNC_PORT}', password=VNC_PASSWORD)
    time.sleep(1)
    
    if command == 'screenshot':
        output = args[0] if args else './tmp/vnc-screen.png'
        client.captureScreen(output)
        print(f"📸 Screenshot saved to {output}")
        
    elif command == 'click':
        x, y = int(args[0]), int(args[1])
        client.mouseMove(x, y)
        time.sleep(0.2)
        client.mousePress(1)
        time.sleep(0.1)
        client.mouseRelease(1)
        print(f"🖱️  Clicked at ({x}, {y})")
        
    elif command == 'type':
        text = args[0]
        client.keyPress(text)
        print(f"⌨️  Typed: {text}")
        
    elif command == 'key':
        key = args[0]
        client.keyPress(key)
        print(f"⌨️  Pressed: {key}")
        
    elif command == 'move':
        x, y = int(args[0]), int(args[1])
        client.mouseMove(x, y)
        print(f"🖱️  Moved to ({x}, {y})")
        
    else:
        print(f"❌ Unknown command: {command}")
        print(__doc__)
        sys.exit(1)
        
    client.disconnect()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    vnc_command(*sys.argv[1:])

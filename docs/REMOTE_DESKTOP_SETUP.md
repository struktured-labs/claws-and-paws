## Remote Desktop Setup: Linux → Windows Mini PC

This guide sets up remote desktop access so Claude can see Roblox Studio directly.

---

## Quick Setup (Recommended: TightVNC)

### On Windows Mini PC (KAMRUI):

1. **Download TightVNC Server:**
   ```
   https://www.tightvnc.com/download.php
   ```
   Download the 64-bit installer

2. **Install TightVNC Server:**
   - Run the installer
   - Select "TightVNC Server" (not viewer)
   - Set a password when prompted (e.g., "clawspaws123")
   - Allow through Windows Firewall when prompted

3. **Configure TightVNC:**
   - Open TightVNC Server settings (system tray icon)
   - Server tab:
     - Enable "Accept RFB connections"
     - Port: 5900 (default)
   - Access Control:
     - IP addresses: 192.168.1.0/24 (allow local network)
   - Click "Apply"

4. **Test it's running:**
   - Open Task Manager
   - Look for "tvnserver.exe"

### On Linux (Your Main PC):

1. **Install VNC Viewer:**
   ```bash
   sudo apt install remmina remmina-plugin-vnc
   # or
   sudo apt install tigervnc-viewer
   ```

2. **Connect to Windows PC:**
   ```bash
   # Option 1: Remmina (GUI, recommended)
   remmina &
   # Then: New connection → VNC → 192.168.1.157:5900

   # Option 2: TigerVNC (command line)
   vncviewer 192.168.1.157:5900
   ```

3. **Enter password:** Use the password you set in step 2

---

## Alternative: Windows RDP (If TightVNC doesn't work)

### On Windows Mini PC:

1. **Enable RDP:**
   - Settings → System → Remote Desktop
   - Enable "Remote Desktop"
   - Click "Confirm"

2. **Note your username:**
   - Settings → Accounts → Your info
   - Username (e.g., "struktured" or "KAMRUI\struktured")

### On Linux:

1. **Install Remmina with RDP plugin:**
   ```bash
   sudo apt install remmina remmina-plugin-rdp
   ```

2. **Connect:**
   ```bash
   remmina &
   # New connection → RDP → 192.168.1.157:3389
   # Username: your Windows username
   # Password: your Windows password
   ```

---

## For Claude (Automated Access)

Once set up, I can request screenshots via a script:

### Option 1: VNC Screenshot Script

```bash
#!/bin/bash
# scripts/capture-studio.sh

vncsnapshot 192.168.1.157:5900 /tmp/studio-screenshot.png --password-file ~/.vnc/passwd
```

Then I can read the screenshot using the Read tool.

### Option 2: Headless Browser Automation

Since Roblox Studio is a Windows app, we can't use headless browsers. But we could:

1. **Use PowerShell remoting:**
   ```bash
   # From Linux
   ssh struktured@192.168.1.157 "powershell.exe -Command 'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait(\"%{F12}\")'"
   ```
   This could trigger Studio actions remotely.

2. **Use AutoHotkey scripts:**
   - Install AutoHotkey on Windows
   - Create scripts to click buttons, run game, capture screenshots
   - Trigger via SSH

---

## Network Setup

### Ensure SSH is enabled on Windows (for scripting):

1. **Install OpenSSH Server:**
   - Settings → Apps → Optional Features
   - Add "OpenSSH Server"
   - Start service:
     ```powershell
     Start-Service sshd
     Set-Service -Name sshd -StartupType 'Automatic'
     ```

2. **Connect from Linux:**
   ```bash
   ssh struktured@192.168.1.157
   ```

3. **Copy SSH key (optional but recommended):**
   ```bash
   ssh-copy-id struktured@192.168.1.157
   ```

---

## Recommended Workflow

1. **VNC for visual debugging:**
   - Open Remmina connection to Windows PC
   - Leave it open in a workspace
   - Check it when debugging visual issues

2. **SSH for automation:**
   - Restart Studio via SSH
   - Trigger game launches
   - Copy log files

3. **Combined script:**
   ```bash
   #!/bin/bash
   # scripts/test-and-capture.sh

   # Restart Studio via SSH
   ssh struktured@192.168.1.157 "taskkill /f /im RobloxStudioBeta.exe"
   ssh struktured@192.168.1.157 "start robloxstudio://placeId=0"

   # Wait for load
   sleep 10

   # Capture screenshot via VNC
   vncsnapshot 192.168.1.157:5900 /tmp/studio-test.png

   # Analyze logs
   ./scripts/analyze-logs.sh
   ```

---

## Security Notes

- VNC password is NOT encrypted over the network by default
- Use SSH tunnel for security:
  ```bash
  ssh -L 5900:localhost:5900 struktured@192.168.1.157 -N &
  vncviewer localhost:5900
  ```
  This encrypts VNC traffic through SSH

- RDP is more secure but requires Windows Pro (Home edition doesn't support it)

---

## Troubleshooting

### Can't connect to VNC:
```bash
# Check if port is open
nmap -p 5900 192.168.1.157

# Check Windows firewall
# On Windows: Windows Defender Firewall → Allow an app → TightVNC
```

### VNC is slow:
- Lower color depth in TightVNC settings
- Reduce resolution
- Use SSH tunnel (adds compression)

### RDP greyed out:
- Windows Home doesn't support RDP server
- Use TightVNC instead
- Or upgrade to Windows Pro

---

## Next Steps After Setup

1. **Test connection:**
   ```bash
   vncviewer 192.168.1.157:5900
   ```

2. **Verify I can see Studio:**
   - Open Roblox Studio on Windows
   - Check if visible in VNC viewer

3. **Create automation scripts:**
   - Screenshot capture
   - Game launch via SSH
   - Log analysis + screenshot correlation

4. **Integrate with testing workflow:**
   - Make change → Push → Auto-restart Studio → Capture screenshot → Analyze

This gives me full visual + log-based debugging without requiring you to manually test!

# Claws & Paws - Development Setup

## Architecture: Linux Dev + Windows Studio

This project uses a **split development environment** for optimal workflow:

```
┌─────────────────────────┐         ┌──────────────────────────┐
│   Linux (Development)   │         │  Windows Mini PC         │
│                         │         │                          │
│  • Code editing         │ Network │  • Roblox Studio only    │
│  • Git/GitHub           │◄───────►│  • Rojo plugin           │
│  • Rojo server          │         │  • Live preview/testing  │
│  • All tooling          │         │  • Publishing builds     │
└─────────────────────────┘         └──────────────────────────┘
```

**Key Insight:** You edit code on Linux, Rojo syncs it to Studio on Windows in real-time. Studio becomes a "live preview window."

---

## Hardware Requirements

### Windows Mini PC Options

#### Budget Option: **Beelink S12 Pro** (~$200-250)
- Intel N100 (4-core, 3.4GHz)
- 16GB DDR4 RAM / 500GB NVMe SSD
- Intel UHD Graphics
- 4.25" x 4.01" x 1.54" (tiny!)
- **Perfect for Claws & Paws** - builds in 3-5 seconds
- Purchase:
  - [Amazon - 16GB/500GB - $189](https://www.amazon.com/Beelink-Intel-N100-Computer-Desktop-Display/dp/B0BVFS94J5)
  - [Amazon - 16GB/1TB - $229](https://www.amazon.com/Beelink-Intel-N100-Desktop-Computer-Support/dp/B0DFH2WVFP)
  - [Newegg - 16GB/500GB - $199](https://www.newegg.com/p/3C6-00X4-001G7)

#### Performance Option: **Minisforum UM690 Pro** (~$349-520)
- AMD Ryzen 9 6900HX (8-core, up to 4.9GHz)
- 32GB DDR5 RAM / 1TB PCIe 4.0 SSD
- AMD Radeon 680M (better 3D viewport)
- USB4, WiFi 6E, 8K support
- **Overkill but future-proof** - builds in 2-3 seconds
- Purchase:
  - [Minisforum Official - Barebones $349](https://www.minisforum.com/products/minisforum-um690-slim)
  - [Newegg - 32GB/1TB - $499](https://www.newegg.com/minisforum-barebone-systems-mini-pc-amd-ryzen-9-6900hx/p/2SW-002G-00082)
  - [Amazon - UM690L 32GB/1TB - $520](https://www.amazon.com/MINISFORUM-UM690-6900HX-Threads-Bluetooth5-2/dp/B0BRN8ND1S)

**Recommendation:** Budget option is sufficient unless you plan to work on asset-heavy Roblox games in the future.

---

## Setup Instructions

### One-Time Setup

#### On Linux Host:
```bash
cd /home/struktured/projects/claws-and-paws
./scripts/dev.sh serve
```

This starts Rojo on port 34872. Find your Linux IP:
```bash
ip addr show | grep "inet 192"
# Example output: 192.168.1.100
```

#### On Windows Mini PC:
1. Install Roblox Studio from [roblox.com/create](https://www.roblox.com/create)
2. Download Rojo plugin: [GitHub Release](https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/Rojo.rbxm)
3. Install plugin: Copy `Rojo.rbxm` to `%LOCALAPPDATA%\Roblox\Plugins\`
4. Open Studio → Plugins tab → Rojo → Connect
5. Enter: `<linux-ip>:34872` (e.g., `192.168.1.100:34872`)

**Done.** Leave Studio open on Windows box.

---

## Daily Workflow

### On Linux (Your Main Workstation):

```bash
# Start Rojo (if not already running)
cd ~/projects/claws-and-paws
./scripts/dev.sh serve

# Edit code with your favorite editor
nvim src/shared/ChessEngine.lua
# or
code src/shared/ChessEngine.lua
```

**Changes sync to Studio instantly.** Just look at your Windows monitor to see updates.

### On Windows Mini PC:

**Do nothing.** Studio auto-updates as you edit on Linux.

Only interact with Windows for:
- Testing gameplay
- Using Studio's 3D viewport
- Publishing to Roblox
- Installing plugin updates

---

## Project Structure

```
claws-and-paws/
├── src/
│   ├── client/          # Client-side code (UI, rendering)
│   ├── server/          # Server-side code (matchmaking, auth)
│   └── shared/          # Shared game logic (chess engine, AI)
├── scripts/
│   ├── dev.sh           # Rojo server management
│   └── setup-vm.sh      # (Deprecated - use mini PC instead)
└── docs/
    ├── GAME_DESIGN.md   # Full game design document
    └── LINUX_SETUP.md   # Linux-specific setup (Vinegar - not recommended)
```

**All code lives on Linux.** Windows PC only runs Studio.

---

## Network Configuration

### Firewall Rules (Linux):
```bash
# Allow Rojo port
sudo ufw allow 34872/tcp
```

### Static IP (Recommended):
Set your Linux box to a static IP (e.g., `192.168.1.100`) in your router settings so the connection doesn't break when DHCP renews.

---

## Troubleshooting

### Rojo Won't Connect in Studio
1. Check Rojo is running on Linux: `curl http://localhost:34872`
2. Check firewall allows port 34872
3. Verify IP address hasn't changed
4. Try connecting to `localhost:34872` if Windows is on same machine (via WSL)

### Changes Not Syncing
1. Check Rojo terminal for errors
2. Ensure files are saved on Linux
3. Restart Rojo: `Ctrl+C` then `./scripts/dev.sh serve`

### Studio Crashes
- Windows mini PC issue, not your problem
- Reboot Windows box
- Your code on Linux is safe

---

## Why Not VirtualBox?

| VirtualBox VM | Dedicated Mini PC |
|---------------|-------------------|
| Shares resources | Independent hardware |
| Clunky UI | Native Windows experience |
| Network flakiness | Stable LAN connection |
| Can't suspend Linux | Both run independently |
| Slow filesystem | Native NVMe speeds |

**Verdict:** $200 mini PC > free VirtualBox for sanity preservation.

---

## Alternative: Windows Laptop

If you already have a Windows laptop, skip buying hardware:
1. Connect laptop to same network as Linux box
2. Follow same setup (Rojo on Linux, Studio on laptop)
3. Use laptop as dedicated Studio machine

---

## Git Workflow

**All Git operations happen on Linux:**
```bash
# On Linux only
git add src/
git commit -m "Add pawn promotion logic"
git push origin main
```

Windows mini PC never touches Git. Studio doesn't even know Git exists.

---

## Deployment

### Building for Roblox:
```bash
# On Linux
./scripts/dev.sh build
# Creates: build/ClawsAndPaws.rbxl
```

### Publishing:
1. Open `build/ClawsAndPaws.rbxl` in Studio (on Windows)
2. File → Publish to Roblox
3. Done

Or publish directly from Studio after syncing with Rojo.

---

## Cost Breakdown

| Component | Cost | Notes |
|-----------|------|-------|
| Windows Mini PC | $200-500 | One-time purchase |
| Monitor (if needed) | $100-150 | Reuse existing or buy cheap 1080p |
| Network cable | $10 | Faster than WiFi |
| **Total** | **~$250** | Budget setup |

**Compare to:**
- Buying Windows license for VM: $139
- Dealing with VirtualBox jank: Priceless (in a bad way)

---

## Notes for Claude

**CRITICAL: Claude IS the Roblox developer.** The user is NOT a Roblox developer and will never be one. Claude must:
- Own all Roblox/Luau development decisions
- Debug and fix issues autonomously
- Never ask the user to perform Roblox-specific tasks manually
- Use automation for ALL testing and verification

### Environment
- Linux workstation (blackmage) with RTX 3090, 3-monitor setup
- Windows mini PC (winmage at 192.168.1.200) runs Roblox Studio only
- SSH access to winmage for remote control
- Rojo syncs code from Linux to Studio in real-time

### Development Philosophy
- **Automation first**: Never ask user to click buttons or check things manually
- **Self-verification**: Use logs, screenshots, and remote commands to verify state
- **Proactive debugging**: Check logs automatically after each change
- **Iterate autonomously**: Fix issues without waiting for user feedback

## Automation Infrastructure

### MCP Tools Available
- `rojo` MCP server: Start/stop/restart Rojo server programmatically (see .mcp.json)

### SSH Remote Control (winmage)
```bash
# Screenshot capture
ssh -i ~/.ssh/winmage_key struk@192.168.1.200 "schtasks /run /tn 'CaptureScreen'"
scp -i ~/.ssh/winmage_key struk@192.168.1.200:C:/Screenshots/screen.png ./tmp/

# Game control
ssh ... "schtasks /run /tn 'StopPlay'"   # Stop game (Shift+F5)
ssh ... "schtasks /run /tn 'PressF5'"    # Start game (F5)

# Check Roblox logs
ssh ... "type C:\\Users\\struk\\AppData\\Local\\Roblox\\logs\\*.log"
```

### Log Locations
- **Roblox Studio logs**: `C:\Users\struk\AppData\Local\Roblox\logs\` (on winmage)
- **Rojo server log**: `/tmp/rojo.log` (on blackmage)
- **Game debug output**: Look for `🐱` prefix in Roblox logs

### Rojo Server Management
- Must listen on `0.0.0.0` (not localhost) for Windows to connect
- After restarting Rojo, Studio plugin needs to reconnect **manually**
  - User must click Plugins → Rojo → Connect in Studio
  - Cannot be automated via SSH (requires GUI interaction)
  - Alternative: Don't restart Rojo unnecessarily - touch files to trigger sync instead
- Check connection: `curl http://localhost:34872/api/rojo`
- Check if Studio is connected: Look for HTTP activity in `/tmp/rojo.log`

## Automation Permissions

Claude can run the following commands without prompting:
- Rojo commands: `rojo serve` (with any flags), `rojo build`, `pkill rojo`
- SSH commands to winmage for screenshots and Studio control
- Scheduled task execution: StopPlay, PressF5, CaptureScreen
- Game restart cycles for testing
- Log file reading and analysis
- Process management (pgrep, pkill for rojo)

## Known Issues & Solutions

### WaitForChild Timeouts
- **Problem**: `WaitForChild("RemoteName", 5)` returns nil if server hasn't created remotes yet
- **Solution**: Remove timeout parameter to wait indefinitely: `WaitForChild("RemoteName")`
- **Symptom**: 5-second gaps between "Got X" debug messages, then nil errors

### Rojo Not Syncing
- **Symptom**: Code changes not reflected in Studio
- **Causes**:
  1. Rojo listening on localhost only (use `--address 0.0.0.0`)
  2. Studio plugin disconnected after server restart
  3. Wrong session ID after restart
- **Fix**: Restart Rojo with correct address, reconnect in Studio

### Camera Not Working
- **Symptom**: Default Roblox camera overrides scripted camera
- **Solution**: Set StarterPlayer properties in default.project.json:
  ```json
  "StarterPlayer": {
    "$properties": {
      "CameraMaxZoomDistance": 100,
      "CameraMinZoomDistance": 50,
      "DevCameraOcclusionMode": "Invisicam"
    }
  }
  ```

## Debug Workflow

1. Make code change
2. Verify Rojo is syncing (check /tmp/rojo.log for activity)
3. Restart game via SSH: `StopPlay` then `PressF5`
4. Wait 8-10 seconds for game to load
5. Check Roblox logs for errors: `grep "🐱\|Error:" <logfile>`
6. If needed, capture screenshot to verify visual state
7. Iterate until fixed

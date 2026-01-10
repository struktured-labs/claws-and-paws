# Claws & Paws - Quick Start Guide (Jan 15th)

Your KAMRUI Hyper H1 arrives! Here's the 15-minute setup to get coding.

---

## Pre-flight Check

**On Linux (before touching Windows box):**

```bash
cd ~/projects/claws-and-paws
./scripts/dev.sh status

# Should show:
# ✓ Rojo installed
# ✓ Project structure ready
```

Find your Linux IP address:
```bash
ip addr show | grep "inet 192"
# Example: 192.168.1.100
```

---

## KAMRUI Setup (10 minutes)

### 1. Boot Windows
- Connect KAMRUI to monitor, keyboard, mouse, ethernet
- Power on
- Follow Windows 11 setup (use local account if possible)

### 2. Install Roblox Studio
- Open browser: https://www.roblox.com/create
- Click "Start Creating"
- Download and install Roblox Studio
- **Sign in to your Roblox account**

### 3. Install Rojo Plugin
Download plugin:
```
https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/Rojo.rbxm
```

Install:
1. Open File Explorer
2. Paste in address bar: `%LOCALAPPDATA%\Roblox\Plugins`
3. Copy `Rojo.rbxm` there
4. Restart Studio if open

---

## Connect the Pieces (5 minutes)

### On Linux:
```bash
cd ~/projects/claws-and-paws
./scripts/dev.sh serve
```

You'll see:
```
Server running on http://localhost:34872
```

### On Windows (in Studio):
1. Open Roblox Studio
2. Create new Baseplate project (or any project)
3. Click **Plugins** tab
4. Click **Rojo**
5. In Rojo panel: **Connect**
6. Enter: `<your-linux-ip>:34872`
   - Example: `192.168.1.100:34872`
7. Click **Connect**

**You should see:**
```
✓ Connected to Rojo
✓ Syncing project...
✓ ReplicatedStorage > Shared (loaded)
✓ ServerScriptService > Server (loaded)
✓ StarterPlayerScripts > Client (loaded)
```

---

## Test It Works

### On Linux:
Edit `src/shared/Constants.lua`:
```lua
-- Add this line at the bottom
print("Hello from Linux! Time:", os.time())
```

**Save the file.**

### On Windows (Studio):
Look at the **Output** window in Studio. You should see the print statement immediately.

**If you see it:** 🎉 **You're done!** Your workflow is live.

---

## Daily Workflow

### Every Day:
```bash
# On Linux (one terminal, leave running):
./scripts/dev.sh serve

# Edit files on Linux with your editor:
nvim src/shared/ChessEngine.lua
# or
code src/shared/ChessEngine.lua

# Studio on Windows auto-updates
# Just look at Windows monitor to see changes
```

### Only Touch Windows For:
- Testing gameplay in Studio
- Using 3D viewport
- Publishing to Roblox
- That's it

---

## Troubleshooting

### Rojo Won't Connect
1. **Check firewall** (Linux):
   ```bash
   sudo ufw allow 34872/tcp
   ```

2. **Verify Rojo is running:**
   ```bash
   curl http://localhost:34872
   # Should return JSON
   ```

3. **Ping test** (from Windows):
   ```cmd
   ping <linux-ip>
   # Should respond
   ```

4. **Try localhost** if both on same network segment:
   ```
   Connect to: localhost:34872
   ```

### Changes Not Syncing
- Check Rojo terminal for errors
- Restart Rojo: `Ctrl+C` then `./scripts/dev.sh serve`
- In Studio: Rojo panel → Disconnect → Connect

### Studio Crashes
- Reboot Windows box
- Your Linux code is always safe

---

## Next Steps After Setup

Once connected and syncing:

1. **Read the Game Design:**
   ```bash
   cat docs/GAME_DESIGN.md
   ```

2. **Explore the chess engine:**
   ```bash
   cat src/shared/ChessEngine.lua
   ```

3. **Test AI personalities:**
   ```bash
   cat src/shared/ChessAI.lua
   ```

4. **Start coding!**

---

## Project Structure Reminder

```
Your code (Linux):                Windows sees:
├── src/shared/                   ReplicatedStorage/Shared/
│   ├── ChessEngine.lua      →        ├── ChessEngine
│   ├── ChessAI.lua          →        ├── ChessAI
│   └── Constants.lua        →        └── Constants
├── src/server/                   ServerScriptService/Server/
│   └── init.server.lua      →        └── init
└── src/client/                   StarterPlayerScripts/Client/
    └── init.client.lua      →        └── init
```

Edit on Linux → Syncs to Studio → Test in Studio → Repeat

---

## What We're Building

**Claws & Paws** - Cat-themed 6x6 chess on Roblox:
- Lion King, Persian Queen, Caracal Knight, etc.
- Fischer Random starting positions
- Cute battle animations when cats fight
- AI opponents with personalities
- Multiplayer with ranked matchmaking

All the game logic is already written. We just need to:
1. Test it in Studio
2. Add 3D cat models
3. Implement UI
4. Add animations
5. Polish & publish

---

## Resources

- Full docs: `docs/GAME_DESIGN.md`
- Linux setup: `docs/LINUX_SETUP.md`
- Architecture: `CLAUDE.md`
- Dev commands: `./scripts/dev.sh help`

---

## Ready to Code?

```bash
# Start Rojo
./scripts/dev.sh serve

# Open your editor
code .

# Make something awesome
```

See you on Jan 15th! 🐱♟️

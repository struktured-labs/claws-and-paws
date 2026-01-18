# Automated Debugging Setup

## Overview

I've set up automated logging so I can debug issues without requiring you to copy-paste console output.

## How It Works

### 1. Client Logs → Server → Rojo Output → Log File

```
Studio Console
      ↓
Logger.lua (client)
      ↓
RemoteEvent
      ↓
LogCollector.lua (server)
      ↓
Rojo Output
      ↓
logs/rojo-TIMESTAMP.log (Linux)
      ↓
analyze-logs.sh (automatic analysis)
```

### 2. What's Logged

**Automatically logged:**
- Piece selections (which piece, coordinates, type)
- Valid move calculations (how many moves found)
- Click events (what square, is it valid)
- Move submissions (from → to coordinates)
- All errors and warnings
- Connection events

**Log Levels:**
- 🔴 **ERROR** - Critical failures
- ⚠️ **WARN** - Warnings
- ℹ️ **INFO** - Important events (piece selected, move made)
- 🔍 **DEBUG** - Detailed debug info (valid moves found, clicks)

## Usage

### For Me (Claude):

**Analyze recent logs:**
```bash
./scripts/analyze-logs.sh
```

**Watch logs live:**
```bash
./scripts/dev-with-logs.sh logs live
```

**Restart Rojo with logging:**
```bash
./scripts/dev-with-logs.sh serve
```

### For You (User):

**Just play the game normally!**

Everything is logged automatically. When you report "movement is buggy," I can run:

```bash
./scripts/analyze-logs.sh
```

And see exactly what happened:
- Which pieces you clicked
- What valid moves were calculated
- Whether moves were sent to the server
- Any errors that occurred

## Current Status

✅ Logging infrastructure set up
✅ Rojo running with log capture
✅ All client actions logged
⏳ Waiting for you to test the game
⏳ Will analyze logs after your test

## Remote Desktop Option

You mentioned offering remote desktop access to the Windows PC. If the logs aren't sufficient, we can set up:

**Option A: VNC/RDP**
- Install TightVNC or Windows RDP on the mini PC
- SSH tunnel from Linux: `ssh -L 5900:localhost:5900 user@192.168.1.157`
- Connect with VNC client from Linux
- I could theoretically see Studio directly (but can't interact via this interface)

**Option B: Log Streaming**
- Set up a simple web server on Windows that streams Studio output
- I fetch it via HTTP from Linux
- More lightweight than full remote desktop

**Current approach: Log file analysis should be sufficient**

## Example Log Output

When you play, I'll see logs like:

```
ℹ️  [INFO] [2026-01-17 19:23:45] struktured: Selected piece at [2,1], type: 1
🔍 [DEBUG] [2026-01-17 19:23:45] struktured: Found 2 valid moves
🔍 [DEBUG] [2026-01-17 19:23:47] struktured: Clicked square [3,1], Valid move: true
ℹ️  [INFO] [2026-01-17 19:23:47] struktured: Sending move: [2,1] → [3,1]
```

Or errors like:

```
❌ [ERROR] [2026-01-17 19:23:50] struktured: Error in onSquareClicked: attempt to index nil value
```

## Next Steps

1. You test the game in Studio
2. I run `./scripts/analyze-logs.sh` to see what happened
3. I fix bugs based on log analysis
4. Repeat until movement works perfectly

No more "can you check the console?" - I'll just read the logs!

# Claws & Paws - Linux Development Setup

Running Roblox Studio on Linux via Vinegar (Wine-based solution).

## Prerequisites

- Flatpak (usually pre-installed on most distros)
- Rust/Cargo (for Rojo)

## Quick Start

```bash
# 1. Install Vinegar
flatpak install flathub org.vinegarhq.Vinegar

# 2. Install Rojo
cargo install rojo

# 3. Run setup (downloads Studio and installs Rojo plugin)
./scripts/dev.sh setup

# 4. Start development
./scripts/dev.sh both
```

## Manual Setup

### 1. Install Vinegar

```bash
flatpak install flathub org.vinegarhq.Vinegar
```

### 2. First Run - Install Studio

```bash
flatpak run org.vinegarhq.Vinegar
```

This will:
- Download and install Roblox Studio (~500MB)
- Set up Wine prefix
- Configure necessary dependencies

### 3. Configure Vinegar

Configuration file: `~/.var/app/org.vinegarhq.Vinegar/config/vinegar/config.toml`

```toml
[studio]
# Enable virtual desktop to fix panel docking issues
virtual_desktop = true
virtual_desktop_res = "1920x1080"

# Enable Discord Rich Presence
discord_rpc = true

[studio.env]
# Mesa/GPU optimizations
MESA_GL_VERSION_OVERRIDE = "4.6"
MESA_GLSL_VERSION_OVERRIDE = "460"
```

### 4. Install Rojo

```bash
cargo install rojo
```

### 5. Install Rojo Plugin in Studio

Download the plugin:
```bash
curl -fsSL -o ~/Rojo.rbxm \
  "https://github.com/rojo-rbx/rojo/releases/download/v7.4.4/Rojo.rbxm"
```

Copy to Studio plugins folder:
```bash
cp ~/Rojo.rbxm ~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/drive_c/users/$USER/AppData/Local/Roblox/Plugins/
```

## Development Workflow

### Terminal 1: Start Rojo Server
```bash
cd /path/to/claws-and-paws
rojo serve
```

### Terminal 2: Launch Studio
```bash
flatpak run org.vinegarhq.Vinegar
```

### In Studio:
1. Open the Rojo plugin (Plugins tab > Rojo)
2. Click "Connect" to connect to localhost:34872
3. Changes sync automatically!

## Troubleshooting

### Studio Crashes on Start
- Try disabling virtual desktop in config
- Check GPU drivers are up to date
- View logs: `~/.var/app/org.vinegarhq.Vinegar/cache/vinegar/logs/`

### Panels Won't Dock
- Enable virtual desktop in config (see above)

### Rojo Can't Connect
- Ensure Rojo server is running (`rojo serve`)
- Check firewall isn't blocking port 34872
- Restart Studio

### Performance Issues
- Enable Vulkan: Set `FFlagDebugGraphicsPreferVulkan = true` in fflags
- Reduce virtual desktop resolution
- Close other GPU-intensive apps

### Studio Shows "Unresponsive"
This is often a false positive on Wine. If Studio is still working, ignore it.

## File Locations

| Component | Path |
|-----------|------|
| Vinegar config | `~/.var/app/org.vinegarhq.Vinegar/config/vinegar/config.toml` |
| Vinegar logs | `~/.var/app/org.vinegarhq.Vinegar/cache/vinegar/logs/` |
| Studio install | `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/versions/` |
| Wine prefix | `~/.var/app/org.vinegarhq.Vinegar/data/vinegar/prefixes/studio/` |
| Studio plugins | `.../prefixes/studio/drive_c/users/$USER/AppData/Local/Roblox/Plugins/` |

## Useful Commands

```bash
# Launch Studio
flatpak run org.vinegarhq.Vinegar

# Update Vinegar
flatpak update org.vinegarhq.Vinegar

# Reinstall Studio (if corrupted)
flatpak run org.vinegarhq.Vinegar --reinstall

# View Vinegar help
flatpak run org.vinegarhq.Vinegar --help

# Start Rojo server
rojo serve default.project.json

# Build Roblox file without syncing
rojo build default.project.json -o game.rbxl
```

## Resources

- [Vinegar Documentation](https://vinegarhq.org/)
- [Rojo Documentation](https://rojo.space/)
- [DevForum Linux Guide](https://devforum.roblox.com/t/the-ultimate-guide-on-how-to-run-roblox-on-linux-studio-player/3171920)

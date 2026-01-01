#!/bin/bash
# Claws & Paws Development Script
# Manages Roblox Studio via Vinegar on Linux

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TMP_DIR="$PROJECT_DIR/tmp"

# Ensure cargo bin is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Vinegar paths
VINEGAR_CONFIG_DIR="$HOME/.var/app/org.vinegarhq.Vinegar/config/vinegar"
VINEGAR_DATA_DIR="$HOME/.var/app/org.vinegarhq.Vinegar/data/vinegar"
STUDIO_PLUGINS_DIR="$VINEGAR_DATA_DIR/prefixes/studio/drive_c/users/$USER/AppData/Local/Roblox/Plugins"

ROJO_VERSION="7.4.4"
ROJO_PLUGIN_URL="https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/Rojo.rbxm"

show_banner() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${GREEN}  Claws & Paws Development Environment${NC} ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}        Linux / Vinegar / Rojo${NC}          ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if Vinegar is installed
check_vinegar() {
    if ! flatpak list 2>/dev/null | grep -q "org.vinegarhq.Vinegar"; then
        return 1
    fi
    return 0
}

# Check if Rojo is installed
check_rojo() {
    if ! command -v rojo &> /dev/null; then
        return 1
    fi
    return 0
}

# Check if Rojo plugin is installed
check_rojo_plugin() {
    if [ -f "$STUDIO_PLUGINS_DIR/Rojo.rbxm" ]; then
        return 0
    fi
    return 1
}

# Install Vinegar
install_vinegar() {
    echo -e "${YELLOW}Installing Vinegar via Flatpak...${NC}"
    flatpak install -y flathub org.vinegarhq.Vinegar
}

# Install Rojo
install_rojo() {
    echo -e "${YELLOW}Installing Rojo via Cargo...${NC}"
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}Cargo not found. Install Rust first: https://rustup.rs/${NC}"
        exit 1
    fi
    cargo install rojo --version "$ROJO_VERSION"
}

# Install Rojo plugin
install_rojo_plugin() {
    echo -e "${YELLOW}Installing Rojo plugin for Studio...${NC}"
    mkdir -p "$TMP_DIR" "$STUDIO_PLUGINS_DIR"

    echo -e "${CYAN}Downloading Rojo.rbxm...${NC}"
    curl -fsSL -o "$TMP_DIR/Rojo.rbxm" "$ROJO_PLUGIN_URL"

    cp "$TMP_DIR/Rojo.rbxm" "$STUDIO_PLUGINS_DIR/Rojo.rbxm"
    echo -e "${GREEN}Rojo plugin installed!${NC}"
}

# Configure Vinegar
configure_vinegar() {
    echo -e "${YELLOW}Configuring Vinegar for optimal Studio experience...${NC}"
    mkdir -p "$VINEGAR_CONFIG_DIR"

    cat > "$VINEGAR_CONFIG_DIR/config.toml" << 'EOF'
# Vinegar Configuration for Claws & Paws Development

[studio]
virtual_desktop = true
virtual_desktop_res = "1920x1080"
discord_rpc = true
theme = "Dark"

[studio.env]
MESA_GL_VERSION_OVERRIDE = "4.6"
MESA_GLSL_VERSION_OVERRIDE = "460"
WINEDLLOVERRIDES = "dxdiagn=d"

[studio.fflags]
FFlagDebugGraphicsPreferVulkan = false
DFIntTaskSchedulerTargetFps = 60
FFlagHandleAltEnterFullscreenManually = false
FFlagEnableQuickGameLaunch = false
EOF

    echo -e "${GREEN}Vinegar configured!${NC}"
}

# Full setup
do_setup() {
    show_banner
    echo -e "${CYAN}Running full development environment setup...${NC}"
    echo ""

    # Step 1: Vinegar
    echo -e "${BLUE}[1/4]${NC} Checking Vinegar..."
    if check_vinegar; then
        echo -e "${GREEN}  ✓ Vinegar already installed${NC}"
    else
        install_vinegar
    fi

    # Step 2: Configure Vinegar
    echo -e "${BLUE}[2/4]${NC} Configuring Vinegar..."
    configure_vinegar

    # Step 3: Rojo
    echo -e "${BLUE}[3/4]${NC} Checking Rojo..."
    if check_rojo; then
        echo -e "${GREEN}  ✓ Rojo already installed ($(rojo --version))${NC}"
    else
        install_rojo
    fi

    # Step 4: Rojo plugin
    echo -e "${BLUE}[4/4]${NC} Checking Rojo Studio plugin..."
    if check_rojo_plugin; then
        echo -e "${GREEN}  ✓ Rojo plugin already installed${NC}"
    else
        install_rojo_plugin
    fi

    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Setup complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Run ${CYAN}./scripts/dev.sh studio${NC} to launch Studio"
    echo -e "  2. Run ${CYAN}./scripts/dev.sh serve${NC} in another terminal"
    echo -e "  3. In Studio: Plugins > Rojo > Connect"
    echo ""
}

# Check all dependencies
check_deps() {
    local missing=0

    if ! check_vinegar; then
        echo -e "${RED}✗ Vinegar not installed${NC}"
        missing=1
    fi

    if ! check_rojo; then
        echo -e "${RED}✗ Rojo not installed${NC}"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}Run './scripts/dev.sh setup' to install missing dependencies${NC}"
        exit 1
    fi
}

# Start Rojo server
start_rojo() {
    echo -e "${GREEN}Starting Rojo server...${NC}"
    cd "$PROJECT_DIR"
    echo -e "${CYAN}Project: $PROJECT_DIR/default.project.json${NC}"
    echo -e "${GREEN}Server running on http://localhost:34872${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    rojo serve default.project.json
}

# Launch Studio via Vinegar
launch_studio() {
    echo -e "${GREEN}Launching Roblox Studio via Vinegar...${NC}"
    echo -e "${YELLOW}(This may take a moment on first run)${NC}"
    flatpak run org.vinegarhq.Vinegar &
    disown
}

# Build .rbxl file
build_game() {
    echo -e "${GREEN}Building game file...${NC}"
    cd "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR/build"
    rojo build default.project.json -o "$PROJECT_DIR/build/ClawsAndPaws.rbxl"
    echo -e "${GREEN}Built: build/ClawsAndPaws.rbxl${NC}"
}

# Show status
show_status() {
    show_banner
    echo -e "${CYAN}Environment Status:${NC}"
    echo ""

    echo -n "  Vinegar:      "
    if check_vinegar; then
        echo -e "${GREEN}✓ Installed${NC}"
    else
        echo -e "${RED}✗ Not installed${NC}"
    fi

    echo -n "  Rojo:         "
    if check_rojo; then
        echo -e "${GREEN}✓ $(rojo --version)${NC}"
    else
        echo -e "${RED}✗ Not installed${NC}"
    fi

    echo -n "  Rojo Plugin:  "
    if check_rojo_plugin; then
        echo -e "${GREEN}✓ Installed${NC}"
    else
        echo -e "${YELLOW}○ Not installed${NC}"
    fi

    echo ""
}

# Main
case "${1:-help}" in
    setup)
        do_setup
        ;;
    serve)
        show_banner
        check_deps
        start_rojo
        ;;
    studio)
        show_banner
        check_deps
        launch_studio
        ;;
    both)
        show_banner
        check_deps
        start_rojo &
        ROJO_PID=$!
        sleep 2
        launch_studio
        wait $ROJO_PID
        ;;
    build)
        show_banner
        check_deps
        build_game
        ;;
    status)
        show_status
        ;;
    help|*)
        show_banner
        echo "Usage: $0 <command>"
        echo ""
        echo -e "${CYAN}Commands:${NC}"
        echo "  setup   - Install all dependencies (Vinegar, Rojo, plugins)"
        echo "  serve   - Start Rojo sync server"
        echo "  studio  - Launch Roblox Studio"
        echo "  both    - Start Rojo server and launch Studio"
        echo "  build   - Build .rbxl game file"
        echo "  status  - Show environment status"
        echo "  help    - Show this help"
        echo ""
        echo -e "${CYAN}Typical workflow:${NC}"
        echo "  1. ./scripts/dev.sh setup    # First time only"
        echo "  2. ./scripts/dev.sh serve    # Terminal 1"
        echo "  3. ./scripts/dev.sh studio   # Terminal 2"
        echo "  4. In Studio: Plugins > Rojo > Connect"
        echo ""
        ;;
esac

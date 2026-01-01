#!/bin/bash
# Claws & Paws - VirtualBox Windows VM Setup
# Creates a Windows VM optimized for Roblox Studio development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# VM Configuration
VM_NAME="ClawsAndPaws-Studio"
VM_RAM=8192          # 8GB RAM
VM_CPUS=4            # 4 CPUs
VM_VRAM=256          # 256MB VRAM (max for VirtualBox)
VM_DISK_SIZE=80000   # 80GB disk

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC} ${GREEN}  Claws & Paws - VM Setup${NC}              ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check for Windows ISO
find_iso() {
    # Common locations
    local iso_paths=(
        "$HOME/Downloads"
        "$HOME"
        "/tmp"
        "$PROJECT_DIR/tmp"
    )

    for path in "${iso_paths[@]}"; do
        local found=$(find "$path" -maxdepth 1 -name "*.iso" -size +3G 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            echo "$found"
            return 0
        fi
    done
    return 1
}

# Check if VM exists
if VBoxManage showvminfo "$VM_NAME" &>/dev/null; then
    echo -e "${YELLOW}VM '$VM_NAME' already exists.${NC}"
    echo -e "Options:"
    echo -e "  1. Start existing VM: ${CYAN}VBoxManage startvm \"$VM_NAME\"${NC}"
    echo -e "  2. Delete and recreate: ${CYAN}VBoxManage unregistervm \"$VM_NAME\" --delete${NC}"
    exit 0
fi

# Find Windows ISO
echo -e "${CYAN}Looking for Windows ISO...${NC}"
WINDOWS_ISO=$(find_iso)

if [ -z "$WINDOWS_ISO" ]; then
    echo -e "${YELLOW}No Windows ISO found.${NC}"
    echo ""
    echo -e "Download Windows 11 from Microsoft:"
    echo -e "  ${CYAN}https://www.microsoft.com/software-download/windows11${NC}"
    echo ""
    echo -e "Or use this direct link for the ISO:"
    echo -e "  ${CYAN}https://www.microsoft.com/en-us/software-download/windows11${NC}"
    echo ""
    echo -e "After downloading, place the ISO in ${CYAN}~/Downloads${NC} and re-run this script."
    echo ""
    read -p "Enter path to Windows ISO (or press Enter to exit): " WINDOWS_ISO

    if [ -z "$WINDOWS_ISO" ] || [ ! -f "$WINDOWS_ISO" ]; then
        echo -e "${RED}No valid ISO provided. Exiting.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Found ISO: $WINDOWS_ISO${NC}"
echo ""

# Create VM
echo -e "${CYAN}[1/6] Creating VM...${NC}"
VBoxManage createvm --name "$VM_NAME" --ostype "Windows11_64" --register

# Configure VM
echo -e "${CYAN}[2/6] Configuring VM (${VM_RAM}MB RAM, ${VM_CPUS} CPUs)...${NC}"
VBoxManage modifyvm "$VM_NAME" \
    --memory $VM_RAM \
    --cpus $VM_CPUS \
    --vram $VM_VRAM \
    --graphicscontroller vboxsvga \
    --accelerate3d on \
    --clipboard-mode bidirectional \
    --draganddrop bidirectional \
    --audio-driver pulse \
    --audio-out on \
    --usb-xhci on \
    --boot1 dvd \
    --boot2 disk \
    --firmware efi \
    --tpm-type 2.0

# Create virtual disk
echo -e "${CYAN}[3/6] Creating ${VM_DISK_SIZE}MB virtual disk...${NC}"
VM_DISK="$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
VBoxManage createmedium disk --filename "$VM_DISK" --size $VM_DISK_SIZE --format VDI

# Add storage controllers
echo -e "${CYAN}[4/6] Attaching storage...${NC}"
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$VM_DISK"
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium "$WINDOWS_ISO"

# Add shared folder for project
echo -e "${CYAN}[5/6] Setting up shared folder...${NC}"
VBoxManage sharedfolder add "$VM_NAME" --name "claws-and-paws" --hostpath "$PROJECT_DIR" --automount --auto-mount-point "Z:"

# Network configuration
echo -e "${CYAN}[6/6] Configuring network...${NC}"
VBoxManage modifyvm "$VM_NAME" --nic1 nat
VBoxManage modifyvm "$VM_NAME" --natpf1 "rojo,tcp,,34872,,34872"

echo ""
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo -e "${GREEN}  VM '$VM_NAME' created successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Start VM: ${YELLOW}VBoxManage startvm \"$VM_NAME\"${NC}"
echo -e "  2. Install Windows (follow installer)"
echo -e "  3. Install VirtualBox Guest Additions (Devices menu)"
echo -e "  4. Download Roblox Studio from roblox.com/create"
echo -e "  5. Install Rojo plugin in Studio"
echo -e ""
echo -e "${CYAN}Shared folder:${NC}"
echo -e "  Host: $PROJECT_DIR"
echo -e "  VM:   Z:\\ (auto-mounted)"
echo ""
echo -e "${CYAN}Rojo connection:${NC}"
echo -e "  Run on host: ${YELLOW}./scripts/dev.sh serve${NC}"
echo -e "  In Studio:   Connect to ${YELLOW}localhost:34872${NC}"
echo ""
echo -e "Start the VM now? [Y/n] "
read -r response
if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
    VBoxManage startvm "$VM_NAME"
fi

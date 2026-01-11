#!/bin/bash
# MOTD Scripts Installer
# Quick install script for Message of the Day scripts

set -e

REPO_URL="https://raw.githubusercontent.com/StafLoker/linux-utils/main/motd"
INSTALL_DIR="/etc/update-motd.d"
SCRIPTS=(
    "10-header"
    "20-system"
    "30-resources"
    "40-network"
    "50-storage"
    "60-services"
    "70-users"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MOTD Scripts Installer ===${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Detect download tool
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -fsSL"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -qO-"
else
    echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
    exit 1
fi

# Create backup directory
BACKUP_DIR="/etc/update-motd.d.backup.$(date +%Y%m%d_%H%M%S)"
if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR 2>/dev/null)" ]; then
    echo -e "${YELLOW}Creating backup of existing MOTD scripts...${NC}"
    mkdir -p "$BACKUP_DIR"
    cp -r "$INSTALL_DIR"/* "$BACKUP_DIR/" 2>/dev/null || true
    echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}\n"
fi

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Interactive selection
echo "Select scripts to install (press Enter to install all):"
echo ""
for i in "${!SCRIPTS[@]}"; do
    echo "  $((i+1)). ${SCRIPTS[$i]}"
done
echo "  a. Install all scripts"
echo "  q. Quit"
echo ""
read -p "Enter your choice [a]: " choice
choice=${choice:-a}

SELECTED_SCRIPTS=()

case "$choice" in
    a|A|"")
        SELECTED_SCRIPTS=("${SCRIPTS[@]}")
        ;;
    q|Q)
        echo "Installation cancelled."
        exit 0
        ;;
    *)
        # Parse individual selections (comma-separated)
        IFS=',' read -ra CHOICES <<< "$choice"
        for c in "${CHOICES[@]}"; do
            c=$(echo "$c" | xargs) # trim whitespace
            if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#SCRIPTS[@]}" ]; then
                SELECTED_SCRIPTS+=("${SCRIPTS[$((c-1))]}")
            else
                echo -e "${YELLOW}Warning: Invalid selection '$c' ignored${NC}"
            fi
        done
        ;;
esac

if [ ${#SELECTED_SCRIPTS[@]} -eq 0 ]; then
    echo -e "${RED}No scripts selected. Exiting.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Installing selected scripts...${NC}\n"

# Download and install selected scripts
for script in "${SELECTED_SCRIPTS[@]}"; do
    echo -n "Installing $script... "
    if $DOWNLOAD_CMD "$REPO_URL/$script" > "$INSTALL_DIR/$script"; then
        chmod +x "$INSTALL_DIR/$script"
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
    fi
done

echo -e "\n${GREEN}Installation complete!${NC}"
echo ""
echo "To test the MOTD output, run:"
echo "  run-parts /etc/update-motd.d/"
echo ""
echo "The MOTD will be displayed automatically on your next login."

# Optionally display the MOTD now
read -p "Display MOTD now? [y/N]: " show_motd
if [[ "$show_motd" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}=== MOTD Preview ===${NC}"
    run-parts /etc/update-motd.d/
fi

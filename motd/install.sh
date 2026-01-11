#!/bin/bash
# MOTD Scripts Installer & Updater
# Quick install/update script for Message of the Day scripts

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
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track installed scripts in this session
declare -A INSTALLED

echo -e "${GREEN}=== MOTD Scripts Installer & Updater ===${NC}\n"

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

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Function to check if script exists
script_exists() {
    [ -f "$INSTALL_DIR/$1" ]
}

# Function to download and install a script
install_script() {
    local script=$1
    echo -e "${CYAN}Downloading $script...${NC}"

    if $DOWNLOAD_CMD "$REPO_URL/$script" > "$INSTALL_DIR/$script"; then
        chmod +x "$INSTALL_DIR/$script"
        INSTALLED[$script]=1
        echo -e "${GREEN}✓ $script installed successfully${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed to download $script${NC}\n"
        return 1
    fi
}

# Function to customize banner
customize_banner() {
    echo -e "\n${CYAN}Installing figlet...${NC}"
    if apt install -y -qq figlet > /dev/null 2>&1; then
        echo -e "${GREEN}✓ figlet installed${NC}"
    else
        echo -e "${RED}✗ Failed to install figlet${NC}"
        echo -e "${YELLOW}Customize manually: https://github.com/xero/figlet-fonts${NC}"
        sleep 2
        return 1
    fi

    echo -e "${CYAN}Downloading Graceful font...${NC}"
    if wget -q https://raw.githubusercontent.com/xero/figlet-fonts/master/Graceful.flf -O /tmp/Graceful.flf; then
        mv /tmp/Graceful.flf /usr/share/figlet/
        echo -e "${GREEN}✓ Graceful font installed${NC}\n"
    else
        echo -e "${RED}✗ Failed to download font${NC}"
        echo -e "${YELLOW}Using default font${NC}\n"
        FONT="standard"
    fi

    FONT=${FONT:-"Graceful"}

    read -p "Banner text [Server]: " banner_text
    banner_text=${banner_text:-"Server"}

    # Generate the banner with figlet
    BANNER_OUTPUT=$(figlet -f $FONT "$banner_text")

    # Create a temporary file with the new banner
    TMP_BANNER=$(mktemp)
    echo "$BANNER_OUTPUT" > "$TMP_BANNER"

    # Replace the content between 'cat << 'BANNER'' and 'BANNER' with the new banner
    # First, extract everything before the banner
    sed -n "1,/cat << 'BANNER'/p" "$INSTALL_DIR/10-header" > "$INSTALL_DIR/10-header.tmp"

    # Add the new banner content
    cat "$TMP_BANNER" >> "$INSTALL_DIR/10-header.tmp"

    # Add the closing BANNER tag and everything after
    echo "BANNER" >> "$INSTALL_DIR/10-header.tmp"
    sed -n "/^BANNER$/,\$p" "$INSTALL_DIR/10-header" | tail -n +2 >> "$INSTALL_DIR/10-header.tmp"

    # Replace the original file
    mv "$INSTALL_DIR/10-header.tmp" "$INSTALL_DIR/10-header"
    rm -f "$TMP_BANNER"

    echo -e "\n${GREEN}✓ Banner configured${NC}"
    echo -e "${YELLOW}Preview:${NC}"
    echo "$BANNER_OUTPUT"

    echo -e "\n${CYAN}More fonts: https://github.com/xero/figlet-fonts${NC}"
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read
}

# Main menu loop
while true; do
    clear
    echo -e "${GREEN}=== MOTD Scripts Installer & Updater ===${NC}\n"
    echo -e "Select a script to install/update:\n"

    # Display menu with status
    for i in "${!SCRIPTS[@]}"; do
        script="${SCRIPTS[$i]}"
        status=""

        if [ "${INSTALLED[$script]}" = "1" ]; then
            status="${GREEN}[✓ Installed]${NC}"
        elif script_exists "$script"; then
            status="${YELLOW}[Installed - can update]${NC}"
        else
            status="${BLUE}[Not installed]${NC}"
        fi

        echo -e "  $((i+1)). ${script} $status"
    done

    echo -e "\n  ${GREEN}a${NC}. Install/update all scripts"
    echo -e "  ${CYAN}t${NC}. Test MOTD output"
    echo -e "  ${RED}q${NC}. Quit"
    echo ""

    read -p "Enter your choice: " choice

    case "$choice" in
        [1-7])
            idx=$((choice-1))
            script="${SCRIPTS[$idx]}"

            if [ "${INSTALLED[$script]}" = "1" ]; then
                echo -e "\n${YELLOW}$script already installed in this session${NC}"
                sleep 1
            else
                if install_script "$script"; then
                    # Special handling for 10-header
                    if [ "$script" = "10-header" ]; then
                        read -p "Customize banner now? [y/N]: " customize
                        if [[ "$customize" =~ ^[Yy]$ ]]; then
                            customize_banner
                        else
                            echo -e "\n${CYAN}Customize later:${NC}"
                            echo -e "  ${YELLOW}Online tool: https://patorjk.com/software/taag${NC}"
                            echo -e "  ${GREEN}Recommended: Graceful font${NC}\n"
                            sleep 3
                        fi
                    else
                        sleep 1
                    fi
                fi
            fi
            ;;
        a|A)
            echo ""
            for script in "${SCRIPTS[@]}"; do
                if [ "${INSTALLED[$script]}" != "1" ]; then
                    install_script "$script"

                    # Special handling for 10-header
                    if [ "$script" = "10-header" ]; then
                        read -p "Customize banner now? [y/N]: " customize
                        if [[ "$customize" =~ ^[Yy]$ ]]; then
                            customize_banner
                        else
                            echo -e "\n${CYAN}Customize later:${NC}"
                            echo -e "  ${YELLOW}Online tool: https://patorjk.com/software/taag${NC}"
                            echo -e "  ${YELLOW}Fonts: https://github.com/xero/figlet-fonts${NC}"
                            echo -e "  ${GREEN}Recommended: Graceful font${NC}\n"
                            sleep 3
                        fi
                    fi
                fi
            done
            echo -e "${GREEN}All scripts processed!${NC}"
            sleep 2
            ;;
        t|T)
            echo -e "\n${YELLOW}=== MOTD Preview ===${NC}\n"
            run-parts "$INSTALL_DIR/"
            echo -e "\n${CYAN}Press Enter to continue...${NC}"
            read
            ;;
        q|Q)
            echo -e "\n${GREEN}Installation complete!${NC}"

            if [ ${#INSTALLED[@]} -gt 0 ]; then
                echo -e "\n${CYAN}Installed/Updated scripts:${NC}"
                for script in "${!INSTALLED[@]}"; do
                    echo -e "  ${GREEN}✓${NC} $script"
                done
            fi

            echo -e "\n${YELLOW}The MOTD will be displayed automatically on your next login.${NC}"
            echo -e "\nTo test now, run: ${CYAN}run-parts /etc/update-motd.d/${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice. Please try again.${NC}"
            sleep 1
            ;;
    esac
done

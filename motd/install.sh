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
DOWNLOAD_CMD=""

#
# Functions
#

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Run as root"
        exit 1
    fi
}

detect_download_tool() {
    if command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl -fsSL"
    elif command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget -qO-"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        exit 1
    fi
}

create_install_directory() {
    mkdir -p "$INSTALL_DIR"
}

script_exists() {
    [ -f "$INSTALL_DIR/$1" ]
}

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

install_figlet() {
    echo -e "\n${CYAN}Installing figlet...${NC}"
    if apt install -y -qq figlet > /dev/null 2>&1; then
        echo -e "${GREEN}✓ figlet installed${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to install figlet${NC}"
        echo -e "${YELLOW}Customize manually: https://github.com/xero/figlet-fonts${NC}"
        sleep 2
        return 1
    fi
}

download_figlet_font() {
    local font_name="$1"
    local font_url="https://raw.githubusercontent.com/xero/figlet-fonts/master/${font_name}.flf"

    echo -e "${CYAN}Downloading ${font_name} font...${NC}"
    if wget -q "$font_url" -O "/tmp/${font_name}.flf"; then
        mv "/tmp/${font_name}.flf" /usr/share/figlet/
        echo -e "${GREEN}✓ ${font_name} font installed${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed to download font${NC}"
        echo -e "${YELLOW}Using default font${NC}\n"
        return 1
    fi
}

generate_banner() {
    local banner_text="$1"
    local font="$2"

    figlet -f "$font" "$banner_text"
}

update_header_banner() {
    local banner_output="$1"
    local header_file="$INSTALL_DIR/10-header"

    # Replace banner content preserving permissions
    {
        sed -n "1,/cat << 'BANNER'/p" "$header_file"
        echo "$banner_output"
        echo "BANNER"
        sed -n "/^BANNER$/,\$p" "$header_file" | tail -n +2
    } > "${header_file}.tmp"

    # Preserve permissions and replace file
    chmod --reference="$header_file" "${header_file}.tmp"
    mv "${header_file}.tmp" "$header_file"
}

customize_banner() {
    if ! install_figlet; then
        return 1
    fi

    local font="Graceful"
    if ! download_figlet_font "$font"; then
        font="standard"
    fi

    read -p "Banner text [Server]: " banner_text
    banner_text=${banner_text:-"Server"}

    # Generate the banner
    local banner_output=$(generate_banner "$banner_text" "$font")

    # Update header file
    update_header_banner "$banner_output"

    echo -e "\n${GREEN}✓ Banner configured${NC}"
    echo -e "${YELLOW}Preview:${NC}"
    echo "$banner_output"

    echo -e "\n${CYAN}More fonts: https://github.com/xero/figlet-fonts${NC}"
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read
}

show_banner_customization_info() {
    echo -e "\n${CYAN}Customize later:${NC}"
    echo -e "  ${YELLOW}Online tool: https://patorjk.com/software/taag${NC}"
    echo -e "  ${YELLOW}Fonts: https://github.com/xero/figlet-fonts${NC}"
    echo -e "  ${GREEN}Recommended: Graceful font${NC}\n"
    sleep 3
}

prompt_banner_customization() {
    read -p "Customize banner now? [y/N]: " customize
    if [[ "$customize" =~ ^[Yy]$ ]]; then
        customize_banner
    else
        show_banner_customization_info
    fi
}

handle_header_installation() {
    if [ "$1" = "10-header" ]; then
        prompt_banner_customization
    fi
}

install_single_script() {
    local script="$1"

    if [ "${INSTALLED[$script]}" = "1" ]; then
        echo -e "\n${YELLOW}$script already installed in this session${NC}"
        sleep 1
        return
    fi

    if install_script "$script"; then
        handle_header_installation "$script"
    else
        sleep 1
    fi
}

install_all_scripts() {
    echo ""
    for script in "${SCRIPTS[@]}"; do
        if [ "${INSTALLED[$script]}" != "1" ]; then
            install_script "$script"
            handle_header_installation "$script"
        fi
    done
    echo -e "${GREEN}All scripts processed!${NC}"
    sleep 2
}

test_motd() {
    echo -e "\n${YELLOW}=== MOTD Preview ===${NC}\n"
    run-parts "$INSTALL_DIR/"
    echo -e "\n${CYAN}Press Enter to continue...${NC}"
    read
}

show_installed_scripts() {
    if [ ${#INSTALLED[@]} -eq 0 ]; then
        return
    fi

    echo -e "\n${CYAN}Installed/Updated scripts:${NC}"
    for script in "${!INSTALLED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $script"
    done
}

show_menu() {
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
}

process_menu_choice() {
    local choice="$1"

    case "$choice" in
        [1-7])
            idx=$((choice-1))
            script="${SCRIPTS[$idx]}"
            install_single_script "$script"
            ;;
        a|A)
            install_all_scripts
            ;;
        t|T)
            test_motd
            ;;
        q|Q)
            echo -e "\n${GREEN}Installation complete!${NC}"
            show_installed_scripts
            exit 0
            ;;
        *)
            echo -e "\n${RED}Invalid choice. Please try again.${NC}"
            sleep 1
            ;;
    esac
}

main() {
    check_root
    detect_download_tool
    create_install_directory

    while true; do
        show_menu
        read -p "Enter your choice: " choice
        process_menu_choice "$choice"
    done
}

main

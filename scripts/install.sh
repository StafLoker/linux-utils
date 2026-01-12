#!/bin/bash
# Scripts Installer & Updater
# Installation and update script for management scripts

set -e

REPO_URL="https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts"
INSTALL_DIR="/usr/local/bin"
NGINX_INSTALL_SCRIPT="https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh"

SCRIPTS=(
    "nginxh.sh"
    "dnsr.sh"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
declare -A INSTALLED
USER_DOMAIN=""
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

script_exists() {
    local script="$1"
    local install_name="${script%.sh}"
    [ -f "$INSTALL_DIR/$install_name" ]
}

prompt_domain() {
    echo -e "${BLUE}Domain Configuration${NC}"
    echo ""
    read -p "Enter your domain (e.g., example.com): " USER_DOMAIN

    if [ -z "$USER_DOMAIN" ]; then
        echo -e "${RED}Error: Domain cannot be empty${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}Domain set to: $USER_DOMAIN${NC}"
    echo ""
}

update_domain_in_script() {
    local script_path="$1"
    local domain="$2"

    # Replace DOMAIN="domain.tld" with the user's domain
    sed -i "s/DOMAIN=\"domain.tld\"/DOMAIN=\"$domain\"/" "$script_path"
}

install_script() {
    local script="$1"
    local install_name="${script%.sh}"
    local temp_file="/tmp/$script"

    echo -e "${CYAN}Processing $script...${NC}"

    echo -n "  Downloading... "
    if $DOWNLOAD_CMD "$REPO_URL/$script" > "$temp_file"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Failed${NC}"
        return 1
    fi

    echo -n "  Configuring domain... "
    update_domain_in_script "$temp_file" "$USER_DOMAIN"
    echo -e "${GREEN}✓${NC}"

    echo -n "  Installing to $INSTALL_DIR/$install_name... "
    mv "$temp_file" "$INSTALL_DIR/$install_name"
    chmod +x "$INSTALL_DIR/$install_name"
    echo -e "${GREEN}✓${NC}"

    INSTALLED[$script]=1
    echo -e "${GREEN}✓ $script installed successfully${NC}\n"
    return 0
}

check_nginx_templates_snippets_needed() {
    for script in "${!INSTALLED[@]}"; do
        if [[ "$script" == "nginxh.sh" ]]; then
            return 0
        fi
    done
    return 1
}

run_nginx_templates_snippets_installer() {
    echo -e "${BLUE}Nginx templates and snippets are required for nginxh.${NC}"
    echo ""
    read -p "Run installer for add templates and snippets now? [Y/n]: " run_nginx
    run_nginx=${run_nginx:-Y}

    if [[ ! "$run_nginx" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Skipped installation of templates and snippets.${NC}"
        echo "You can install it manually later with:"
        echo "  curl -fsSL $NGINX_INSTALL_SCRIPT | sudo bash"
        echo ""
        return
    fi

    echo ""
    echo -e "${YELLOW}Running templates and snippets installer...${NC}"
    echo ""

    # Use bash -c "$(...)" to keep stdin available for user input
    if bash -c "$($DOWNLOAD_CMD "$NGINX_INSTALL_SCRIPT")"; then
        echo ""
        echo -e "${GREEN}✓ Templates and snippets installation completed${NC}"
    else
        echo ""
        echo -e "${RED}✗ Templates and snippets installation failed${NC}"
        echo "You can try manually with:"
        echo "  sudo bash -c \"\$(curl -fsSL $NGINX_INSTALL_SCRIPT)\""
    fi
    echo ""
}

show_installed_scripts() {
    if [ ${#INSTALLED[@]} -eq 0 ]; then
        return
    fi

    echo -e "${GREEN}Installation complete!${NC}\n"
    echo -e "${CYAN}Installed/Updated scripts:${NC}"
    for script in "${!INSTALLED[@]}"; do
        install_name="${script%.sh}"
        echo -e "  ${GREEN}✓${NC} $install_name"
    done
    echo ""
}

show_usage_info() {
    if [ ${#INSTALLED[@]} -eq 0 ]; then
        return
    fi

    echo "Usage:"
    echo ""

    for script in "${!INSTALLED[@]}"; do
        install_name="${script%.sh}"
        case "$script" in
            "nginxh.sh")
                echo "  # Manage nginx sites"
                echo "  sudo $install_name"
                echo ""
                ;;
            "dnsr.sh")
                echo "  # Manage DNS records (dnsmasq)"
                echo "  sudo $install_name"
                echo ""
                ;;
        esac
    done

    echo -e "${YELLOW}Note: All scripts are configured for domain: $USER_DOMAIN${NC}"
    echo ""
    echo "For more information, see: https://github.com/StafLoker/linux-utils/tree/main/scripts"
}

main() {
    check_root
    detect_download_tool

    prompt_domain

    while true; do
        clear
        echo -e "${GREEN}=== Scripts Installer & Updater ===${NC}\n"
        echo -e "Select a script to install/update:\n"

        # Display menu with status
        for i in "${!SCRIPTS[@]}"; do
            script="${SCRIPTS[$i]}"
            install_name="${script%.sh}"
            status=""

            if [ "${INSTALLED[$script]}" = "1" ]; then
                status="${GREEN}[✓ Installed]${NC}"
            elif script_exists "$script"; then
                status="${YELLOW}[Installed - can update]${NC}"
            else
                status="${BLUE}[Not installed]${NC}"
            fi

            echo -e "  $((i+1)). ${install_name} $status"
        done

        echo -e "\n  ${GREEN}a${NC}. Install/update all scripts"
        echo -e "  ${RED}q${NC}. Quit"
        echo ""

        read -p "Enter your choice: " choice

        case "$choice" in
            [1-2])
                idx=$((choice-1))
                script="${SCRIPTS[$idx]}"

                if [ "${INSTALLED[$script]}" = "1" ]; then
                    echo -e "\n${YELLOW}$script already processed in this session${NC}"
                    sleep 1
                else
                    install_script "$script"
                    sleep 1
                fi
                ;;
            a|A)
                echo ""
                for script in "${SCRIPTS[@]}"; do
                    if [ "${INSTALLED[$script]}" != "1" ]; then
                        install_script "$script"
                    fi
                done
                sleep 1
                ;;
            q|Q)
                echo ""
                show_installed_scripts

                if check_nginx_templates_snippets_needed; then
                    run_nginx_templates_snippets_installer
                fi

                show_usage_info
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main

#!/bin/bash
# Nginx Templates & Snippets Installer & Updater
# Installation and update script for nginx configuration templates and snippets

set -e

REPO_URL="https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx"
TEMPLATES_DIR="/etc/nginx/templates"
SNIPPETS_DIR="/etc/nginx/snippets"

TEMPLATES=(
    "template-http.conf"
    "template-https.conf"
)

SNIPPETS=(
    "snippets/options-ssl.conf"
    "snippets/proxy.conf"
    "snippets/websocket.conf"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track installed files in this session
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

check_nginx() {
    if ! command -v nginx &> /dev/null; then
        echo -e "${YELLOW}Warning: nginx is not installed${NC}"
        read -p "Continue anyway? [y/N]: " continue_install
        if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

check_certbot() {
    local certbot_installed=true
    local nginx_plugin_installed=true
    local porkbun_plugin_installed=true

    # Check certbot
    if ! command -v certbot &> /dev/null; then
        certbot_installed=false
    fi

    # Check plugins (only if certbot exists)
    if [ "$certbot_installed" = true ]; then
        local plugins_output
        plugins_output=$(certbot plugins 2>/dev/null)
        if ! echo "$plugins_output" | grep -q "nginx"; then
            nginx_plugin_installed=false
        fi
        if ! echo "$plugins_output" | grep -q "dns-porkbun"; then
            porkbun_plugin_installed=false
        fi
    else
        nginx_plugin_installed=false
        porkbun_plugin_installed=false
    fi

    # Show current status
    echo ""
    echo -e "${YELLOW}=== Certbot / SSL dependencies ===${NC}"
    if [ "$certbot_installed" = true ]; then
        echo -e "  ${GREEN}✓${NC} certbot"
    else
        echo -e "  ${RED}✗${NC} certbot"
    fi
    if [ "$nginx_plugin_installed" = true ]; then
        echo -e "  ${GREEN}✓${NC} certbot nginx plugin  (HTTP-01 challenge)"
    else
        echo -e "  ${RED}✗${NC} certbot nginx plugin  (HTTP-01 challenge)"
    fi
    if [ "$porkbun_plugin_installed" = true ]; then
        echo -e "  ${GREEN}✓${NC} certbot-dns-porkbun   (DNS-01 challenge)"
    else
        echo -e "  ${RED}✗${NC} certbot-dns-porkbun   (DNS-01 challenge)"
    fi

    # If everything is installed, nothing to do
    if [ "$certbot_installed" = true ] && [ "$nginx_plugin_installed" = true ] && [ "$porkbun_plugin_installed" = true ]; then
        echo ""
        return 0
    fi

    echo ""
    echo -e "${YELLOW}Which certbot plugin(s) do you want to install?${NC}"
    echo "  1) HTTP validation only  (nginx plugin)"
    echo "  2) DNS challenge only    (Porkbun)"
    echo "  3) Both plugins"
    echo "  s) Skip"
    echo ""
    read -p "Select [1/2/3/s]: " plugin_choice
    plugin_choice=${plugin_choice:-s}

    local install_nginx_plugin=false
    local install_porkbun_plugin=false

    case "$plugin_choice" in
        1) install_nginx_plugin=true ;;
        2) install_porkbun_plugin=true ;;
        3) install_nginx_plugin=true; install_porkbun_plugin=true ;;
        s|S)
            echo -e "${YELLOW}Skipped certbot installation.${NC}"
            echo ""
            return 1
            ;;
        *)
            echo -e "${YELLOW}Invalid choice — skipping certbot installation.${NC}"
            echo ""
            return 1
            ;;
    esac

    echo ""
    echo -e "${CYAN}Installing certbot dependencies...${NC}"
    echo ""

    if ! apt update; then
        echo -e "${RED}Failed to update package list${NC}"
        return 1
    fi

    # Install base certbot if missing
    if [ "$certbot_installed" = false ]; then
        echo -e "${CYAN}Installing certbot...${NC}"
        if apt install -y certbot python3-pip; then
            echo -e "${GREEN}✓ certbot installed${NC}"
        else
            echo -e "${RED}✗ Failed to install certbot${NC}"
            return 1
        fi
    fi

    # Install nginx plugin if requested and missing
    if [ "$install_nginx_plugin" = true ] && [ "$nginx_plugin_installed" = false ]; then
        echo -e "${CYAN}Installing certbot nginx plugin...${NC}"
        if apt install -y python3-certbot-nginx; then
            echo -e "${GREEN}✓ certbot nginx plugin installed${NC}"
        else
            echo -e "${RED}✗ Failed to install certbot nginx plugin${NC}"
            return 1
        fi
    fi

    # Install porkbun DNS plugin if requested and missing
    if [ "$install_porkbun_plugin" = true ] && [ "$porkbun_plugin_installed" = false ]; then
        echo -e "${CYAN}Installing certbot-dns-porkbun...${NC}"
        if pip3 install certbot_dns_porkbun --break-system-packages; then
            echo -e "${GREEN}✓ certbot-dns-porkbun installed${NC}"
        else
            echo -e "${RED}✗ Failed to install certbot-dns-porkbun${NC}"
            echo -e "  Try manually: ${YELLOW}sudo pip3 install certbot_dns_porkbun --break-system-packages${NC}"
            return 1
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ Certbot dependencies installed successfully${NC}"
    echo ""
    return 0
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

create_directories() {
    mkdir -p "$TEMPLATES_DIR"
    mkdir -p "$SNIPPETS_DIR"
}

file_exists() {
    local file="$1"
    [ -f "$file" ]
}

install_template() {
    local template="$1"
    local target_path="$TEMPLATES_DIR/$template"

    echo -e "${CYAN}Processing $template...${NC}"
    echo -n "  Downloading... "
    if $DOWNLOAD_CMD "$REPO_URL/$template" > "$target_path"; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED[$template]=1
        echo -e "${GREEN}✓ $template installed successfully${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}\n"
        return 1
    fi
}

install_snippet() {
    local snippet="$1"
    local filename=$(basename "$snippet")
    local target_path="$SNIPPETS_DIR/$filename"

    echo -e "${CYAN}Processing $filename...${NC}"
    echo -n "  Downloading... "
    if $DOWNLOAD_CMD "$REPO_URL/$snippet" > "$target_path"; then
        echo -e "${GREEN}✓${NC}"
        INSTALLED[$filename]=1
        echo -e "${GREEN}✓ $filename installed successfully${NC}\n"
        return 0
    else
        echo -e "${RED}✗ Failed${NC}\n"
        return 1
    fi
}


show_installed_files() {
    if [ ${#INSTALLED[@]} -eq 0 ]; then
        return
    fi

    echo -e "${GREEN}Installation complete!${NC}\n"
    echo -e "${CYAN}Installed/Updated files:${NC}"
    for file in "${!INSTALLED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $file"
    done
    echo ""
}

main() {
    check_root
    check_nginx
    detect_download_tool
    create_directories

    # Check and optionally install certbot for HTTPS support
    check_certbot

    while true; do
        clear
        echo -e "${GREEN}=== Nginx Templates & Snippets Installer & Updater ===${NC}\n"
        echo -e "Select files to install/update:\n"

        echo -e "${YELLOW}Templates:${NC}"
        for i in "${!TEMPLATES[@]}"; do
            template="${TEMPLATES[$i]}"
            status=""

            if [ "${INSTALLED[$template]}" = "1" ]; then
                status="${GREEN}[✓ Installed]${NC}"
            elif file_exists "$TEMPLATES_DIR/$template"; then
                status="${YELLOW}[Installed - can update]${NC}"
            else
                status="${BLUE}[Not installed]${NC}"
            fi

            echo -e "  $((i+1)). ${template} $status"
        done

        echo -e "\n${YELLOW}Snippets:${NC}"
        local snippet_offset=${#TEMPLATES[@]}
        for i in "${!SNIPPETS[@]}"; do
            snippet="${SNIPPETS[$i]}"
            filename=$(basename "$snippet")
            status=""

            if [ "${INSTALLED[$filename]}" = "1" ]; then
                status="${GREEN}[✓ Installed]${NC}"
            elif file_exists "$SNIPPETS_DIR/$filename"; then
                status="${YELLOW}[Installed - can update]${NC}"
            else
                status="${BLUE}[Not installed]${NC}"
            fi

            echo -e "  $((i+snippet_offset+1)). ${filename} $status"
        done

        echo -e "\n  ${GREEN}a${NC}. Install/update all files"
        echo -e "  ${RED}q${NC}. Quit"
        echo ""

        read -p "Enter your choice: " choice

        case "$choice" in
            [1-2])
                # Template selection
                idx=$((choice-1))
                if [ "$idx" -lt "${#TEMPLATES[@]}" ]; then
                    template="${TEMPLATES[$idx]}"
                    if [ "${INSTALLED[$template]}" = "1" ]; then
                        echo -e "\n${YELLOW}$template already processed in this session${NC}"
                        sleep 1
                    else
                        install_template "$template"
                        sleep 1
                    fi
                fi
                ;;
            [3-6])
                # Snippet selection
                idx=$((choice-snippet_offset-1))
                if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SNIPPETS[@]}" ]; then
                    snippet="${SNIPPETS[$idx]}"
                    filename=$(basename "$snippet")
                    if [ "${INSTALLED[$filename]}" = "1" ]; then
                        echo -e "\n${YELLOW}$filename already processed in this session${NC}"
                        sleep 1
                    else
                        install_snippet "$snippet"
                        sleep 1
                    fi
                fi
                ;;
            a|A)
                echo ""
                # Install all templates
                for template in "${TEMPLATES[@]}"; do
                    if [ "${INSTALLED[$template]}" != "1" ]; then
                        install_template "$template"
                    fi
                done

                # Install all snippets
                for snippet in "${SNIPPETS[@]}"; do
                    filename=$(basename "$snippet")
                    if [ "${INSTALLED[$filename]}" != "1" ]; then
                        install_snippet "$snippet"
                    fi
                done
                sleep 1
                ;;
            q|Q)
                echo ""
                show_installed_files
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

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
    "snippets/acl-ip.conf"
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

    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        certbot_installed=false
    fi

    # Check if nginx plugin is available
    if [ "$certbot_installed" = true ]; then
        if ! certbot plugins 2>/dev/null | grep -q "nginx"; then
            nginx_plugin_installed=false
        fi
    fi

    # Both are installed
    if [ "$certbot_installed" = true ] && [ "$nginx_plugin_installed" = true ]; then
        return 0
    fi

    # Show what's missing
    echo ""
    echo -e "${YELLOW}Missing dependencies for HTTPS support:${NC}"
    if [ "$certbot_installed" = false ]; then
        echo -e "  ${RED}✗${NC} certbot is not installed"
    else
        echo -e "  ${GREEN}✓${NC} certbot is installed"
    fi

    if [ "$certbot_installed" = true ] && [ "$nginx_plugin_installed" = false ]; then
        echo -e "  ${RED}✗${NC} certbot nginx plugin is not installed"
    elif [ "$certbot_installed" = true ]; then
        echo -e "  ${GREEN}✓${NC} certbot nginx plugin is installed"
    fi

    echo ""
    read -p "Install missing dependencies now? [Y/n]: " install_deps
    install_deps=${install_deps:-Y}

    if [[ ! "$install_deps" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Skipped dependency installation.${NC}"
        echo "You can install them manually with:"
        echo "  sudo apt update"
        echo "  sudo apt install certbot python3-certbot-nginx"
        echo ""
        return 1
    fi

    # Install dependencies
    echo ""
    echo -e "${CYAN}Installing dependencies...${NC}"
    echo ""

    if ! apt update; then
        echo -e "${RED}Failed to update package list${NC}"
        return 1
    fi

    if [ "$certbot_installed" = false ]; then
        echo -e "${CYAN}Installing certbot...${NC}"
        if apt install -y certbot python3-certbot-nginx; then
            echo -e "${GREEN}✓ certbot and nginx plugin installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install certbot${NC}"
            return 1
        fi
    elif [ "$nginx_plugin_installed" = false ]; then
        echo -e "${CYAN}Installing certbot nginx plugin...${NC}"
        if apt install -y python3-certbot-nginx; then
            echo -e "${GREEN}✓ certbot nginx plugin installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install nginx plugin${NC}"
            return 1
        fi
    fi

    echo ""
    echo -e "${GREEN}✓ All dependencies installed successfully${NC}"
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

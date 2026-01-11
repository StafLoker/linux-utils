#!/bin/bash
# Nginx Templates & Snippets Installer
# Quick install script for nginx configuration templates and snippets

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
    "snippets/proxy.conf"
    "snippets/websocket.conf"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nginx Templates & Snippets Installer ===${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}Warning: nginx is not installed${NC}"
    read -p "Continue anyway? [y/N]: " continue_install
    if [[ ! "$continue_install" =~ ^[Yy]$ ]]; then
        exit 0
    fi
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

# Create directories
mkdir -p "$TEMPLATES_DIR"
mkdir -p "$SNIPPETS_DIR"

# Interactive selection
echo "What would you like to install?"
echo ""
echo "  1. Templates only"
echo "  2. Snippets only"
echo "  3. Both templates and snippets"
echo "  4. Custom selection"
echo "  q. Quit"
echo ""
read -p "Enter your choice [3]: " choice
choice=${choice:-3}

INSTALL_TEMPLATES=()
INSTALL_SNIPPETS=()

case "$choice" in
    1)
        INSTALL_TEMPLATES=("${TEMPLATES[@]}")
        ;;
    2)
        INSTALL_SNIPPETS=("${SNIPPETS[@]}")
        ;;
    3|"")
        INSTALL_TEMPLATES=("${TEMPLATES[@]}")
        INSTALL_SNIPPETS=("${SNIPPETS[@]}")
        ;;
    4)
        # Templates selection
        echo -e "\n${BLUE}Select templates to install:${NC}"
        for i in "${!TEMPLATES[@]}"; do
            echo "  $((i+1)). ${TEMPLATES[$i]}"
        done
        echo "  a. All templates"
        read -p "Enter your choice (comma-separated numbers or 'a') [a]: " tmpl_choice
        tmpl_choice=${tmpl_choice:-a}

        if [[ "$tmpl_choice" =~ ^[aA]$ ]]; then
            INSTALL_TEMPLATES=("${TEMPLATES[@]}")
        else
            IFS=',' read -ra CHOICES <<< "$tmpl_choice"
            for c in "${CHOICES[@]}"; do
                c=$(echo "$c" | xargs)
                if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#TEMPLATES[@]}" ]; then
                    INSTALL_TEMPLATES+=("${TEMPLATES[$((c-1))]}")
                fi
            done
        fi

        # Snippets selection
        echo -e "\n${BLUE}Select snippets to install:${NC}"
        for i in "${!SNIPPETS[@]}"; do
            echo "  $((i+1)). ${SNIPPETS[$i]}"
        done
        echo "  a. All snippets"
        read -p "Enter your choice (comma-separated numbers or 'a') [a]: " snip_choice
        snip_choice=${snip_choice:-a}

        if [[ "$snip_choice" =~ ^[aA]$ ]]; then
            INSTALL_SNIPPETS=("${SNIPPETS[@]}")
        else
            IFS=',' read -ra CHOICES <<< "$snip_choice"
            for c in "${CHOICES[@]}"; do
                c=$(echo "$c" | xargs)
                if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#SNIPPETS[@]}" ]; then
                    INSTALL_SNIPPETS+=("${SNIPPETS[$((c-1))]}")
                fi
            done
        fi
        ;;
    q|Q)
        echo "Installation cancelled."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Exiting.${NC}"
        exit 1
        ;;
esac

if [ ${#INSTALL_TEMPLATES[@]} -eq 0 ] && [ ${#INSTALL_SNIPPETS[@]} -eq 0 ]; then
    echo -e "${RED}Nothing selected. Exiting.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Installing files...${NC}\n"

# Install templates
if [ ${#INSTALL_TEMPLATES[@]} -gt 0 ]; then
    echo -e "${BLUE}Templates:${NC}"
    for template in "${INSTALL_TEMPLATES[@]}"; do
        echo -n "  Installing $template... "
        if $DOWNLOAD_CMD "$REPO_URL/$template" > "$TEMPLATES_DIR/$template"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done
fi

# Install snippets
if [ ${#INSTALL_SNIPPETS[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Snippets:${NC}"
    for snippet in "${INSTALL_SNIPPETS[@]}"; do
        filename=$(basename "$snippet")
        echo -n "  Installing $filename... "
        if $DOWNLOAD_CMD "$REPO_URL/$snippet" > "$SNIPPETS_DIR/$filename"; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    done
fi

echo -e "\n${GREEN}Installation complete!${NC}\n"

# Show installed files
if [ ${#INSTALL_TEMPLATES[@]} -gt 0 ]; then
    echo "Templates installed in: $TEMPLATES_DIR"
    ls -lh "$TEMPLATES_DIR"
    echo ""
fi

if [ ${#INSTALL_SNIPPETS[@]} -gt 0 ]; then
    echo "Snippets installed in: $SNIPPETS_DIR"
    ls -lh "$SNIPPETS_DIR"
    echo ""
fi

echo "Usage examples:"
echo ""
echo "  # Copy a template to create a new site"
echo "  cp $TEMPLATES_DIR/template-http.conf /etc/nginx/sites-available/mysite.conf"
echo ""
echo "  # Include a snippet in your nginx configuration"
echo "  include $SNIPPETS_DIR/proxy.conf;"
echo ""
echo "For more information, see: https://github.com/StafLoker/linux-utils/tree/main/nginx"

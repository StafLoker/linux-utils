#!/bin/bash

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
TEMPLATES_DIR="/etc/nginx/templates"
DOMAIN="domain.tld"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Run as root"
        exit 1
    fi
}

check_certbot() {
    if ! command -v certbot &> /dev/null; then
        echo "Error: certbot is not installed"
        echo "Install it with: sudo apt install certbot python3-certbot-nginx"
        return 1
    fi

    # Check if nginx plugin is available
    if ! certbot plugins 2>/dev/null | grep -q "nginx"; then
        echo "Error: certbot nginx plugin is not installed"
        echo "Install it with: sudo apt install python3-certbot-nginx"
        return 1
    fi

    return 0
}

# Convert subdomain to FQDN (@ means root domain)
get_fqdn() {
    local subdomain="$1"
    if [ "$subdomain" = "@" ]; then
        echo "$DOMAIN"
    else
        echo "${subdomain}.${DOMAIN}"
    fi
}

# Extract service name from existing config
get_service_from_config() {
    local config_file="$1"
    grep "upstream" "$config_file" | head -1 | awk '{print $2}'
}

# Extract port from existing config
get_port_from_config() {
    local config_file="$1"
    grep "server 127.0.0.1:" "$config_file" | head -1 | sed 's/.*:\([0-9]*\);/\1/'
}

# Add ACL snippet to config based on type (http/https)
# We add it after server_name in the main server block
# For HTTPS: only in the 443 block, not in the redirect block
add_acl_snippet() {
    local config_file="$1"
    local is_https="$2"

    if [ "$is_https" = "true" ]; then
        # For HTTPS: add in the 443 server block only
        sed -i '/listen 443/,/location \// { /server_name/a\    include snippets/acl-ip.conf;\n' "$config_file"
    else
        # For HTTP: add after server_name
        sed -i '/server_name/a\    include snippets/acl-ip.conf;\n' "$config_file"
    fi
}

# Add WebSocket snippet to config
# Always added inside location / block after proxy.conf
add_websocket_snippet() {
    local config_file="$1"
    sed -i '/include snippets\/proxy.conf;/a\        include snippets/websocket.conf;' "$config_file"
}

# Apply snippets to config based on user choices
apply_snippets() {
    local config_file="$1"
    local ws_choice="$2"
    local acl_choice="$3"
    local is_https="$4"

    if [ "$acl_choice" = "y" ] || [ "$acl_choice" = "Y" ]; then
        add_acl_snippet "$config_file" "$is_https"
    fi

    if [ "$ws_choice" = "y" ] || [ "$ws_choice" = "Y" ]; then
        add_websocket_snippet "$config_file"
    fi
}

# Test and reload nginx
test_and_reload_nginx() {
    echo ""
    echo "Testing nginx configuration..."
    nginx -t

    if [ $? -eq 0 ]; then
        echo "Reloading nginx..."
        systemctl reload nginx
        return 0
    else
        echo "Error: Nginx configuration test failed"
        return 1
    fi
}

show_sites() {
    echo -e "\n=== Current Nginx Sites ==="
    if [ -d "$SITES_ENABLED" ] && [ "$(ls -A "$SITES_ENABLED" 2>/dev/null)" ]; then
        for site in "$SITES_ENABLED"/*; do
            [ -e "$site" ] || continue
            fqdn=$(basename "$site")

            if [ -L "$site" ]; then
                target=$(readlink "$site")
                if grep -q "ssl_certificate" "$target" 2>/dev/null; then
                    echo "→ $fqdn : HTTPS"
                else
                    echo "→ $fqdn : HTTP"
                fi
            fi
        done
    else
        echo "(empty)"
    fi
    echo ""
}

add_site() {
    read -p "Subdomain (@ for root domain): " subdomain
    domain=$(get_fqdn "$subdomain")

    read -p "Service name (upstream): " service
    read -p "Backend port: " port

    echo ""
    echo "1) HTTP only"
    echo "2) HTTPS (with SSL certificate)"
    read -p "Select type [1-2]: " ssl_choice

    read -p "Enable WebSocket support? [y/N]: " ws_choice
    read -p "Enable IP ACL restrictions? [y/N]: " acl_choice

    # Check if templates exist
    if [ ! -f "$TEMPLATES_DIR/template-http.conf" ]; then
        echo "Error: HTTP template not found at $TEMPLATES_DIR/template-http.conf"
        return 1
    fi

    if [ "$ssl_choice" = "2" ]; then
        if [ ! -f "$TEMPLATES_DIR/template-https.conf" ]; then
            echo "Error: HTTPS template not found at $TEMPLATES_DIR/template-https.conf"
            return 1
        fi

        # Check certbot installation
        if ! check_certbot; then
            return 1
        fi

        use_ssl=true
    else
        use_ssl=false
    fi

    config_file="$SITES_AVAILABLE/${domain}"

    if [ "$use_ssl" = true ]; then
        # For HTTPS: First create HTTP config to get certificate
        echo ""
        echo "Step 1/3: Creating temporary HTTP configuration..."
        sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"

        # Enable site temporarily
        ln -sf "$config_file" "$SITES_ENABLED/${domain}"

        # Test and reload
        if ! test_and_reload_nginx; then
            echo "Error: Failed to apply temporary HTTP configuration"
            rm -f "$config_file"
            rm -f "$SITES_ENABLED/${domain}"
            return 1
        fi

        # Step 2: Obtain SSL certificate
        echo ""
        echo "Step 2/3: Obtaining SSL certificate with certbot..."
        certbot certonly --nginx -d "$domain"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to obtain SSL certificate"
            echo "Cleaning up temporary configuration..."
            rm -f "$SITES_ENABLED/${domain}"
            rm -f "$config_file"
            systemctl reload nginx
            return 1
        fi

        # Step 3: Apply HTTPS template
        echo ""
        echo "Step 3/3: Applying HTTPS configuration..."
        sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g" "$TEMPLATES_DIR/template-https.conf" > "$config_file"

        # Apply snippets
        apply_snippets "$config_file" "$ws_choice" "$acl_choice" "true"

        # Test and reload with HTTPS config
        if ! test_and_reload_nginx; then
            echo "Error: Failed to apply HTTPS configuration"
            return 1
        fi

        echo "✓ Site added with HTTPS: $domain"
    else
        # For HTTP: Simple one-step process
        echo ""
        echo "Creating HTTP configuration..."
        sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"

        # Apply snippets
        apply_snippets "$config_file" "$ws_choice" "$acl_choice" "false"

        # Enable site
        ln -sf "$config_file" "$SITES_ENABLED/${domain}"

        # Test and reload
        if test_and_reload_nginx; then
            echo "✓ Site added: $domain"
        else
            rm -f "$SITES_ENABLED/${domain}"
            return 1
        fi
    fi
}

delete_site() {
    read -p "Subdomain to delete (@ for root domain): " subdomain
    domain=$(get_fqdn "$subdomain")

    config_file="$SITES_AVAILABLE/${domain}"
    enabled_link="$SITES_ENABLED/${domain}"

    if [ ! -f "$config_file" ]; then
        echo "Error: Site $domain not found"
        return 1
    fi

    read -p "Delete SSL certificate too? [y/N]: " delete_cert

    # Remove symlink and config
    rm -f "$enabled_link"
    rm -f "$config_file"

    # Delete SSL certificate if requested
    if [ "$delete_cert" = "y" ] || [ "$delete_cert" = "Y" ]; then
        if [ -d "/etc/letsencrypt/live/$domain" ]; then
            certbot delete --cert-name "$domain"
        fi
    fi

    # Test and reload
    nginx -t && systemctl reload nginx

    echo "✓ Deleted: $domain"
}

modify_site() {
    read -p "Subdomain to modify (@ for root domain): " subdomain
    domain=$(get_fqdn "$subdomain")

    config_file="$SITES_AVAILABLE/${domain}"

    if [ ! -f "$config_file" ]; then
        echo "Error: Site $domain not found"
        return 1
    fi

    # Detect current type
    if grep -q "ssl_certificate" "$config_file"; then
        current_type="HTTPS"
        echo "Current configuration: HTTPS"
        echo "1) Convert to HTTP only"
        echo "2) Keep HTTPS (modify other options)"
    else
        current_type="HTTP"
        echo "Current configuration: HTTP"
        echo "1) Convert to HTTPS"
        echo "2) Keep HTTP (modify other options)"
    fi
    echo "3) Cancel"

    read -p "Select option [1-3]: " mod_choice

    case $mod_choice in
        1)
            # Convert between HTTP and HTTPS
            service=$(get_service_from_config "$config_file")
            port=$(get_port_from_config "$config_file")

            read -p "Enable WebSocket support? [y/N]: " ws_choice
            read -p "Enable IP ACL restrictions? [y/N]: " acl_choice

            if [ "$current_type" = "HTTPS" ]; then
                # Convert HTTPS to HTTP
                echo ""
                echo "Converting to HTTP..."
                sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"
                apply_snippets "$config_file" "$ws_choice" "$acl_choice" "false"
                echo "✓ Converted to HTTP"
            else
                # Convert HTTP to HTTPS
                # Check certbot installation
                if ! check_certbot; then
                    return 1
                fi

                echo ""
                echo "Step 1/2: Obtaining SSL certificate with certbot..."
                echo "(Using existing HTTP configuration for verification)"
                certbot certonly --nginx -d "$domain"

                if [ $? -ne 0 ]; then
                    echo "Error: Failed to obtain SSL certificate"
                    return 1
                fi

                # Step 2: Apply HTTPS template
                echo ""
                echo "Step 2/2: Applying HTTPS configuration..."
                sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g" "$TEMPLATES_DIR/template-https.conf" > "$config_file"
                apply_snippets "$config_file" "$ws_choice" "$acl_choice" "true"
                echo "✓ Converted to HTTPS"
            fi
            ;;
        2)
            # Modify snippets only (keep HTTP/HTTPS as is)
            read -p "Enable WebSocket support? [y/N]: " ws_choice
            read -p "Enable IP ACL restrictions? [y/N]: " acl_choice

            # Remove existing snippets
            sed -i '/snippets\/websocket.conf/d' "$config_file"
            sed -i '/snippets\/acl-ip.conf/d' "$config_file"

            # Apply snippets based on choices
            is_https_flag="false"
            [ "$current_type" = "HTTPS" ] && is_https_flag="true"
            apply_snippets "$config_file" "$ws_choice" "$acl_choice" "$is_https_flag"

            echo "Updated configuration options"
            ;;
        3)
            echo "Cancelled"
            return 0
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac

    # Test and reload
    if test_and_reload_nginx; then
        echo "✓ Site modified: $domain"
    else
        return 1
    fi
}

main_menu() {
    while true; do
        clear
        show_sites
        echo "1) Add site"
        echo "2) Delete site"
        echo "3) Modify site"
        echo "4) Exit"
        read -p "> " choice

        case $choice in
            1) add_site ;;
            2) delete_site ;;
            3) modify_site ;;
            4) echo "Bye"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac

        # Pause before clearing screen
        [ "$choice" != "4" ] && read -p "Press Enter to continue..."
    done
}

check_root
main_menu

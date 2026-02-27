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
    return 0
}

# Detect available certbot plugins
detect_certbot_plugins() {
    local plugins_output=$(certbot plugins 2>/dev/null)
    local has_nginx=0
    local has_dns_porkbun=0

    if echo "$plugins_output" | grep -q "nginx"; then
        has_nginx=1
    fi

    if echo "$plugins_output" | grep -q "dns-porkbun"; then
        has_dns_porkbun=1
    fi

    echo "$has_nginx:$has_dns_porkbun"
}

# Configure DNS credentials for Porkbun
setup_porkbun_credentials() {
    local creds_file="/etc/letsencrypt/porkbun.ini"

    if [ -f "$creds_file" ]; then
        echo "Porkbun credentials already configured at $creds_file"
        return 0
    fi

    echo ""
    echo "=== Porkbun DNS Configuration ==="
    echo "You need API credentials from Porkbun dashboard"
    echo ""
    read -p "Porkbun API Key: " api_key
    read -p "Porkbun API Secret: " api_secret

    if [ -z "$api_key" ] || [ -z "$api_secret" ]; then
        echo "Error: API credentials cannot be empty"
        return 1
    fi

    # Create letsencrypt directory if it doesn't exist
    mkdir -p /etc/letsencrypt

    # Write credentials file
    cat > "$creds_file" <<EOF
dns_porkbun_key=$api_key
dns_porkbun_secret=$api_secret
EOF

    # Set secure permissions
    chmod 600 "$creds_file"

    echo "✓ Credentials saved to $creds_file"
    return 0
}

# Ask user which SSL method to use
choose_ssl_method() {
    local plugins_info=$(detect_certbot_plugins)
    local has_nginx=$(echo "$plugins_info" | cut -d: -f1)
    local has_dns_porkbun=$(echo "$plugins_info" | cut -d: -f2)

    echo "" >&2
    echo "=== SSL Certificate Method ===" >&2

    local method_count=0
    local nginx_option=""
    local dns_option=""

    if [ "$has_nginx" = "1" ]; then
        method_count=$((method_count + 1))
        nginx_option="$method_count"
        echo "$method_count) HTTP validation (nginx plugin)" >&2
    fi

    if [ "$has_dns_porkbun" = "1" ]; then
        method_count=$((method_count + 1))
        dns_option="$method_count"
        echo "$method_count) DNS challenge (Porkbun)" >&2
    fi

    if [ $method_count -eq 0 ]; then
        echo "Error: No certbot plugins available" >&2
        echo "" >&2
        echo "Install one of:" >&2
        echo "  - HTTP: sudo apt install python3-certbot-nginx" >&2
        echo "  - DNS:  sudo pip3 install certbot_dns_porkbun" >&2
        return 1
    fi

    if [ $method_count -eq 1 ]; then
        # Only one method available, use it automatically
        if [ "$has_nginx" = "1" ]; then
            echo "Using HTTP validation (nginx plugin)" >&2
            echo "nginx"
        else
            echo "Using DNS challenge (Porkbun)" >&2
            echo "dns"
        fi
        return 0
    fi

    # Multiple methods available, ask user
    read -p "Select method [1-$method_count]: " choice

    if [ "$choice" = "$nginx_option" ]; then
        echo "nginx"
    elif [ "$choice" = "$dns_option" ]; then
        echo "dns"
    else
        echo "Error: Invalid choice" >&2
        return 1
    fi
}

# Obtain SSL certificate using selected method
obtain_ssl_certificate() {
    local domain="$1"
    local method="$2"

    case "$method" in
        nginx)
            certbot certonly --nginx -d "$domain"
            return $?
            ;;
        dns)
            if ! setup_porkbun_credentials; then
                return 1
            fi

            certbot certonly \
                --preferred-challenges dns \
                --authenticator dns-porkbun \
                --dns-porkbun-credentials /etc/letsencrypt/porkbun.ini \
                --dns-porkbun-propagation-seconds 60 \
                -d "$domain"
            return $?
            ;;
        *)
            echo "Error: Unknown SSL method: $method"
            return 1
            ;;
    esac
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

# Extract HTTP listen port from existing config
get_http_port_from_config() {
    local config_file="$1"
    grep "listen" "$config_file" | grep -v "ssl" | grep -v "\[::\]" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g'
}

# Extract HTTPS listen port from existing config
get_https_port_from_config() {
    local config_file="$1"
    grep "listen.*ssl" "$config_file" | grep -v "\[::\]" | head -1 | awk '{print $2}' | sed 's/[^0-9]//g'
}

# Ask user for HTTP listen port
ask_http_port() {
    local http_port
    echo "" >&2
    echo "HTTP listen port (default 80, use a different port if needed):" >&2
    read -p "HTTP port [80]: " http_port
    if [ -z "$http_port" ]; then
        http_port="80"
    fi
    echo "$http_port"
}

# Ask user for HTTPS listen port
ask_https_port() {
    local https_port
    echo "" >&2
    echo "HTTPS listen port (default 443, use e.g. 8443 if nginx-stream already uses 443):" >&2
    read -p "HTTPS port [443]: " https_port
    if [ -z "$https_port" ]; then
        https_port="443"
    fi
    echo "$https_port"
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

        # Choose SSL method
        ssl_method=$(choose_ssl_method)
        if [ $? -ne 0 ] || [ -z "$ssl_method" ]; then
            return 1
        fi

        http_port=$(ask_http_port)
        https_port=$(ask_https_port)

        use_ssl=true
    else
        http_port=$(ask_http_port)
        use_ssl=false
    fi

    config_file="$SITES_AVAILABLE/${domain}"

    if [ "$use_ssl" = true ]; then
        # For HTTPS with nginx plugin: create temporary HTTP config
        # For DNS challenge: skip temp config (no HTTP validation needed)
        if [ "$ssl_method" = "nginx" ]; then
            echo ""
            echo "Step 1/3: Creating temporary HTTP configuration..."
            sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g; s/<http_port>/$http_port/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"

            # Enable site temporarily
            ln -sf "$config_file" "$SITES_ENABLED/${domain}"

            # Test and reload
            if ! test_and_reload_nginx; then
                echo "Error: Failed to apply temporary HTTP configuration"
                rm -f "$config_file"
                rm -f "$SITES_ENABLED/${domain}"
                return 1
            fi
        fi

        # Step 2: Obtain SSL certificate
        echo ""
        if [ "$ssl_method" = "nginx" ]; then
            echo "Step 2/3: Obtaining SSL certificate with certbot..."
        else
            echo "Step 1/2: Obtaining SSL certificate with DNS challenge..."
        fi

        if ! obtain_ssl_certificate "$domain" "$ssl_method"; then
            echo "Error: Failed to obtain SSL certificate"
            if [ "$ssl_method" = "nginx" ]; then
                echo "Cleaning up temporary configuration..."
                rm -f "$SITES_ENABLED/${domain}"
                rm -f "$config_file"
                systemctl reload nginx
            fi
            return 1
        fi

        # Step 3: Apply HTTPS template
        echo ""
        if [ "$ssl_method" = "nginx" ]; then
            echo "Step 3/3: Applying HTTPS configuration..."
        else
            echo "Step 2/2: Applying HTTPS configuration..."
        fi
        sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g; s/<http_port>/$http_port/g; s/<https_port>/$https_port/g" "$TEMPLATES_DIR/template-https.conf" > "$config_file"

        # Apply snippets
        apply_snippets "$config_file" "$ws_choice"

        # Enable site
        ln -sf "$config_file" "$SITES_ENABLED/${domain}"

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
        sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g; s/<http_port>/$http_port/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"

        # Apply snippets
        apply_snippets "$config_file" "$ws_choice"

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

view_site() {
    read -p "Subdomain to view (@ for root domain): " subdomain
    domain=$(get_fqdn "$subdomain")

    config_file="$SITES_AVAILABLE/${domain}"

    if [ ! -f "$config_file" ]; then
        echo "Error: Site $domain not found"
        return 1
    fi

    echo ""
    echo "=== Configuration: $domain ==="
    echo ""
    cat "$config_file"
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

            if [ "$current_type" = "HTTPS" ]; then
                # Convert HTTPS to HTTP
                http_port=$(ask_http_port)
                echo ""
                echo "Converting to HTTP..."
                sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g; s/<http_port>/$http_port/g" "$TEMPLATES_DIR/template-http.conf" > "$config_file"
                apply_snippets "$config_file" "$ws_choice"
                echo "✓ Converted to HTTP"
            else
                # Convert HTTP to HTTPS
                # Check certbot installation
                if ! check_certbot; then
                    return 1
                fi

                # Choose SSL method
                ssl_method=$(choose_ssl_method)
                if [ $? -ne 0 ] || [ -z "$ssl_method" ]; then
                    return 1
                fi

                http_port=$(ask_http_port)
                https_port=$(ask_https_port)

                echo ""
                echo "Step 1/2: Obtaining SSL certificate..."
                if [ "$ssl_method" = "nginx" ]; then
                    echo "(Using existing HTTP configuration for verification)"
                fi

                if ! obtain_ssl_certificate "$domain" "$ssl_method"; then
                    echo "Error: Failed to obtain SSL certificate"
                    return 1
                fi

                # Step 2: Apply HTTPS template
                echo ""
                echo "Step 2/2: Applying HTTPS configuration..."
                sed "s/<service>/$service/g; s/<port>/$port/g; s/<domain>/$domain/g; s/<http_port>/$http_port/g; s/<https_port>/$https_port/g" "$TEMPLATES_DIR/template-https.conf" > "$config_file"
                apply_snippets "$config_file" "$ws_choice"
                echo "✓ Converted to HTTPS"
            fi
            ;;
        2)
            # Modify snippets only (keep HTTP/HTTPS as is)
            read -p "Enable WebSocket support? [y/N]: " ws_choice

            # Remove existing snippets
            sed -i '/snippets\/websocket.conf/d' "$config_file"

            # Apply snippets based on choices
            apply_snippets "$config_file" "$ws_choice"

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
        echo "4) View site config"
        echo "5) Exit"
        read -p "> " choice

        case $choice in
            1) add_site ;;
            2) delete_site ;;
            3) modify_site ;;
            4) view_site ;;
            5) echo "Bye"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac

        # Pause before clearing screen
        [ "$choice" != "5" ] && read -p "Press Enter to continue..."
    done
}

check_root
main_menu

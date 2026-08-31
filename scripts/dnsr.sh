#!/bin/bash

HOSTS_FILE="/etc/dnsmasq.hosts"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Run as root"
        exit 1
    fi
}

# List known base domains found in the hosts file.
# ponytail: registrable domain = last two labels; good enough for homelab,
# multi-label TLDs (co.uk) would need a public-suffix list.
list_domains() {
    [ -f "$HOSTS_FILE" ] && [ -s "$HOSTS_FILE" ] || return 0
    awk '{print $2}' "$HOSTS_FILE" | sort -u | while read -r fqdn; do
        echo "$fqdn" | awk -F. '{if (NF>=2) print $(NF-1)"."$NF}'
    done | sort -u
}

# Convert subdomain + base domain to FQDN (@ means root domain).
build_fqdn() {
    local subdomain="$1"
    local domain="$2"
    if [ -z "$subdomain" ] || [ "$subdomain" = "@" ]; then
        echo "$domain"
    else
        echo "${subdomain}.${domain}"
    fi
}

# Match an exact FQDN in the hosts file by field, not by substring.
# Handles both "IP fqdn hostname" and "IP fqdn" line formats.
grep_fqdn() {
    local fqdn="$1"
    awk -v want="$fqdn" '$2 == want' "$HOSTS_FILE"
}

# Prompt the user to pick an existing base domain or type a new one.
# Echoes the chosen domain on stdout.
pick_domain() {
    local domains=()
    while IFS= read -r d; do
        [ -n "$d" ] && domains+=("$d")
    done < <(list_domains)

    echo "" >&2
    echo "=== Select domain ===" >&2
    local i
    for i in "${!domains[@]}"; do
        echo "$((i + 1))) ${domains[$i]}" >&2
    done
    echo "n) New domain" >&2

    local choice
    read -p "> " choice

    if [ "$choice" = "n" ] || [ "$choice" = "N" ]; then
        local new_domain
        read -p "New base domain (e.g. example.com): " new_domain
        if [ -z "$new_domain" ]; then
            echo "Error: domain cannot be empty" >&2
            return 1
        fi
        echo "$new_domain"
        return 0
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#domains[@]}" ]; then
        echo "${domains[$((choice - 1))]}"
        return 0
    fi

    echo "Error: invalid choice" >&2
    return 1
}

show_records() {
    echo -e "\n=== Current DNS Records ==="
    if [ -f "$HOSTS_FILE" ] && [ -s "$HOSTS_FILE" ]; then
        local domains=()
        while IFS= read -r d; do
            [ -n "$d" ] && domains+=("$d")
        done < <(list_domains)

        local d
        for d in "${domains[@]}"; do
            echo "[$d]"
            awk '{print $2}' "$HOSTS_FILE" | sort -u | grep -E "(^|\.)${d//./\\.}$" | sed 's/^/  → /'
        done
    else
        echo "(empty)"
    fi
    echo ""
}

add_record() {
    local domain
    domain=$(pick_domain) || return 1

    read -p "Subdomain (@ for root domain): " subdomain

    local fqdn entry
    fqdn=$(build_fqdn "$subdomain" "$domain")

    if [ -f "$HOSTS_FILE" ] && [ -n "$(grep_fqdn "$fqdn")" ]; then
        echo "Error: $fqdn already exists (delete it first to change its IPs)"
        return 1
    fi

    read -p "IPv4: " ipv4
    read -p "IPv6: " ipv6

    if [ -z "$ipv4" ] && [ -z "$ipv6" ]; then
        echo "Error: at least one IP address is required"
        return 1
    fi

    # Short hostname alias only makes sense for subdomains, never for the root
    if [ -z "$subdomain" ] || [ "$subdomain" = "@" ]; then
        entry="$fqdn"
    else
        entry="$fqdn $subdomain"
    fi

    [ -n "$ipv4" ] && echo "$ipv4 $entry" >> "$HOSTS_FILE"
    [ -n "$ipv6" ] && echo "$ipv6 $entry" >> "$HOSTS_FILE"

    echo "✓ Added: $fqdn"
}

delete_record() {
    local domain
    domain=$(pick_domain) || return 1

    read -p "Subdomain to delete (@ for root domain): " subdomain

    local fqdn
    fqdn=$(build_fqdn "$subdomain" "$domain")

    if [ ! -f "$HOSTS_FILE" ] || [ -z "$(grep_fqdn "$fqdn")" ]; then
        echo "Error: $fqdn not found"
        return 1
    fi

    # Drop lines whose second field is exactly this FQDN
    local tmp
    tmp=$(mktemp)
    awk -v want="$fqdn" '$2 != want' "$HOSTS_FILE" > "$tmp" && cat "$tmp" > "$HOSTS_FILE"
    rm -f "$tmp"

    echo "✓ Deleted: $fqdn"
}

view_record() {
    local domain
    domain=$(pick_domain) || return 1

    read -p "Subdomain to view (@ for root domain): " subdomain

    local fqdn matches
    fqdn=$(build_fqdn "$subdomain" "$domain")

    echo -e "\n=== Details for $fqdn ==="

    matches=$([ -f "$HOSTS_FILE" ] && grep_fqdn "$fqdn")

    if [ -n "$matches" ]; then
        ipv4=$(echo "$matches" | grep -v ':' | awk '{print $1}' | head -1)
        ipv6=$(echo "$matches" | grep ':' | awk '{print $1}' | head -1)

        if [ -n "$ipv4" ]; then
            echo "  → IPv4: $ipv4"
        else
            echo "  → IPv4: (not set)"
        fi

        if [ -n "$ipv6" ]; then
            echo "  → IPv6: $ipv6"
        else
            echo "  → IPv6: (not set)"
        fi
    else
        echo "  Record not found"
    fi
    echo ""
}

main() {
    check_root

    while true; do
        clear
        show_records
        echo "1) Add record"
        echo "2) Delete record"
        echo "3) View record details"
        echo "4) Exit"
        read -p "> " choice

        case $choice in
            1) add_record ;;
            2) delete_record ;;
            3) view_record ;;
            4) echo "Restarting dnsmasq..."; systemctl restart dnsmasq 2>/dev/null; echo "Bye"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac

        # Pause before clearing screen
        [ "$choice" != "4" ] && read -p "Press Enter to continue..."
    done
}

main

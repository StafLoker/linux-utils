#!/bin/bash

HOSTS_FILE="/etc/dnsmasq.hosts"
DOMAIN="domain.tld"

check_root() {
    [ "$EUID" -ne 0 ] && echo "Run as root" && exit 1
}

show_records() {
    echo -e "\n=== Current DNS Records ==="
    if [ -f "$HOSTS_FILE" ] && [ -s "$HOSTS_FILE" ]; then
        awk '{print $2}' "$HOSTS_FILE" | sort -u | grep "$DOMAIN" | sed 's/^/→ /'
    else
        echo "(empty)"
    fi
    echo ""
}

add_record() {
    read -p "Subdomain (@ for root domain): " subdomain
    read -p "IPv4: " ipv4
    read -p "IPv6: " ipv6

    # Si es @, usar el dominio raíz
    if [ "$subdomain" = "@" ]; then
        fqdn="$DOMAIN"
        hostname="@"
    else
        fqdn="${subdomain}.${DOMAIN}"
        hostname="$subdomain"
    fi

    echo "$ipv4 $fqdn $hostname" >> "$HOSTS_FILE"
    echo "$ipv6 $fqdn $hostname" >> "$HOSTS_FILE"

    echo "✓ Added: $hostname"
}

delete_record() {
    read -p "Subdomain to delete (@ for root domain): " subdomain

    if [ "$subdomain" = "@" ]; then
        fqdn="$DOMAIN"
    else
        fqdn="${subdomain}.${DOMAIN}"
    fi

    sed -i "/$fqdn/d" "$HOSTS_FILE"

    echo "✓ Deleted: $subdomain"
}

view_record() {
    read -p "Subdomain to view (@ for root domain): " subdomain

    if [ "$subdomain" = "@" ]; then
        fqdn="$DOMAIN"
    else
        fqdn="${subdomain}.${DOMAIN}"
    fi

    echo -e "\n=== Details for $fqdn ==="

    if [ -f "$HOSTS_FILE" ] && grep -q "$fqdn" "$HOSTS_FILE"; then
        # IPv4
        ipv4=$(grep "$fqdn" "$HOSTS_FILE" | grep -v ':' | awk '{print $1}' | head -1)
        # IPv6
        ipv6=$(grep "$fqdn" "$HOSTS_FILE" | grep ':' | awk '{print $1}' | head -1)

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

main_menu() {
    while true; do
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
    done
}

check_root
main_menu

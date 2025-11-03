#!/bin/bash

HOSTS_FILE="/etc/dnsmasq.hosts"
DOMAIN="domain.tld"

check_root() {
    [ "$EUID" -ne 0 ] && echo "Run as root" && exit 1
}

show_records() {
    echo -e "\n=== Current DNS Records ==="
    if [ -f "$HOSTS_FILE" ] && [ -s "$HOSTS_FILE" ]; then
        awk '{print $2}' "$HOSTS_FILE" | sort -u | grep ".$DOMAIN$" | sed "s/\.$DOMAIN$//"
    else
        echo "(empty)"
    fi
    echo ""
}

add_record() {
    read -p "Hostname: " hostname
    read -p "IPv4: " ipv4
    read -p "IPv6: " ipv6
    
    fqdn="${hostname}.${DOMAIN}"
    echo "$ipv4 $fqdn $hostname" >> "$HOSTS_FILE"
    echo "$ipv6 $fqdn $hostname" >> "$HOSTS_FILE"
    
    echo "✓ Added: $hostname"
}

delete_record() {
    read -p "Hostname to delete: " hostname
    
    fqdn="${hostname}.${DOMAIN}"
    sed -i "/$fqdn/d" "$HOSTS_FILE"
    
    echo "✓ Deleted: $hostname"
}

main_menu() {
    while true; do
        show_records
        echo "1) Add record"
        echo "2) Delete record"
        echo "3) Exit"
        read -p "> " choice
        
        case $choice in
            1) add_record ;;
            2) delete_record ;;
            3) echo "Restarting dnsmasq..."; systemctl restart dnsmasq 2>/dev/null; echo "Bye"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

check_root
main_menu

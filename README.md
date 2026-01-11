# Linux utils repo

Util scripts, alias and other more for Linux administration

## Directory Structure

### [motd/](motd/)
Message of the Day (MOTD) scripts that display system information on login. These scripts are numbered to control execution order:
- **10-header**: Displays a custom ASCII art banner
- **20-system**: Shows hostname, OS version, kernel, and uptime
- **30-resources**: System resource information
- **40-network**: Network configuration details
- **50-storage**: Disk and storage usage
- **60-services**: Running services status
- **70-users**: Active user sessions

### [os/](os/)
Operating system configuration files:
- **aliases.sh**: Common shell aliases for Linux administration including shortcuts for `ls`, file operations, systemctl, journalctl, and Docker commands

### [nginx/](nginx/)
Nginx configuration templates and snippets:
- **template-http.conf**: HTTP-only virtual host template
- **template-https.conf**: HTTPS virtual host template with SSL/TLS and automatic HTTP-to-HTTPS redirect
- **snippets/**: Reusable configuration snippets
  - **acl-ip.conf**: IP-based access control lists
  - **proxy.conf**: Standard reverse proxy headers and settings
  - **websocket.conf**: WebSocket support configuration

### [scripts/](scripts/)
Utility scripts for system administration:
- **dnsr.sh**: DNS record management tool for dnsmasq. Interactive menu to add/delete/view DNS records with IPv4/IPv6 support.
- **nginxh.sh**: Nginx virtual host manager. Interactive tool to create, modify, and delete nginx sites with support for:
  - HTTP and HTTPS configurations
  - Automatic SSL certificate generation via certbot
  - Easy conversion between HTTP and HTTPS

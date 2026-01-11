# System Administration Scripts

Interactive utility scripts for common system administration tasks.

## Quick Install & Upgrade

Download scripts to your home directory:

```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/dnsr.sh -o ~/dnsr.sh
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/nginxh.sh -o ~/nginxh.sh
chmod +x ~/dnsr.sh ~/nginxh.sh
```

Or using wget:

```bash
# Using wget
wget -q https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/dnsr.sh -O ~/dnsr.sh
wget -q https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/nginxh.sh -O ~/nginxh.sh
chmod +x ~/dnsr.sh ~/nginxh.sh
```

Add to PATH (optional):

```bash
mkdir -p ~/scripts
mv ~/dnsr.sh ~/nginxh.sh ~/scripts/
echo 'export PATH="$HOME/scripts:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Scripts

### dnsr.sh

DNS record management tool for dnsmasq.

**Features:**
- Add/delete DNS records with IPv4 and IPv6 support
- View detailed record information
- Subdomain notation with `@` for root domain
- Automatic dnsmasq restart on exit

**Usage:**
```bash
sudo ./dnsr.sh
```

**Configuration:**
Edit `DOMAIN` variable in the script to set your base domain.

---

### nginxh.sh

Nginx virtual host manager for reverse proxy configurations.

**Features:**
- Create HTTP or HTTPS sites from templates
- Automatic SSL certificate generation via certbot
- WebSocket support toggle
- IP ACL restrictions toggle
- Convert between HTTP and HTTPS
- Subdomain notation with `@` for root domain
- Automatic nginx syntax validation

**Usage:**
```bash
sudo ./nginxh.sh
```

**Configuration:**
- Edit `DOMAIN` variable for your base domain
- Edit `TEMPLATES_DIR` if templates are in a different location

**Requirements:**
- nginx
- certbot (for HTTPS sites)
- Templates from [../nginx/](../nginx/)

## General Notes

- Both scripts require root privileges
- Use `@` to reference the root domain (e.g., `domain.tld` instead of `sub.domain.tld`)
- Interactive menus guide you through operations

# System Administration Scripts

Interactive utility scripts for common system administration tasks.

## Quick Install

**Recommended:** Use the installer script (automatically configures domain and installs to `/usr/local/bin`):

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/install.sh)"
```

Or with wget:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/install.sh)"
```

**What the installer does:**
- Prompts for your domain configuration
- Lets you choose which scripts to install (nginxh, dnsr, or both)
- Automatically updates the `DOMAIN` variable in each script
- Installs scripts to `/usr/local/bin` (removes `.sh` extension)
- Optionally runs the nginx templates installer if you select nginxh

### Manual Installation

If you prefer manual installation:

```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/dnsr.sh -o ~/dnsr.sh
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/nginxh.sh -o ~/nginxh.sh
chmod +x ~/dnsr.sh ~/nginxh.sh

# Edit DOMAIN variable in each script
sed -i 's/DOMAIN="domain.tld"/DOMAIN="yourdomain.com"/' ~/dnsr.sh
sed -i 's/DOMAIN="domain.tld"/DOMAIN="yourdomain.com"/' ~/nginxh.sh

# Move to system location
sudo mv ~/dnsr.sh /usr/local/bin/dnsr
sudo mv ~/nginxh.sh /usr/local/bin/nginxh
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
# If installed with installer
sudo dnsr

# If manual installation
sudo ./dnsr.sh
```

**Configuration:**
The installer automatically configures your domain. For manual installation, edit `DOMAIN` variable in the script.

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
# If installed with installer
sudo nginxh

# If manual installation
sudo ./nginxh.sh
```

**Configuration:**
- The installer automatically configures your domain
- For manual installation, edit `DOMAIN` variable in the script
- Edit `TEMPLATES_DIR` if templates are in a different location

**Requirements:**
- nginx
- certbot and python3-certbot-nginx plugin (for HTTPS sites)
  ```bash
  sudo apt install certbot python3-certbot-nginx
  ```
- Templates from [../nginx/](../nginx/) (installer can set this up automatically)

**HTTPS Setup Process:**
When creating an HTTPS site, nginxh follows this secure process:
1. Creates temporary HTTP configuration
2. Obtains SSL certificate from Let's Encrypt using certbot
3. Applies HTTPS configuration with the obtained certificate

This ensures proper domain verification and prevents configuration errors.

## General Notes

- Both scripts require root privileges
- Use `@` to reference the root domain (e.g., `domain.tld` instead of `sub.domain.tld`)
- Interactive menus guide you through operations

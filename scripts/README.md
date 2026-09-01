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
- Lets you choose which scripts to install (nginxh, dnsr, or both)
- Installs scripts to `/usr/local/bin` (removes `.sh` extension)
- Optionally runs the nginx templates installer if you select nginxh

Both scripts are multi-domain. They auto-detect existing base domains from
your current config (`/etc/dnsmasq.hosts` for `dnsr`, `/etc/nginx/sites-available/`
for `nginxh`) and let you pick one from a menu or type a new domain. No `DOMAIN`
variable to configure.

### Manual Installation

If you prefer manual installation:

```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/dnsr.sh -o ~/dnsr.sh
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/nginxh.sh -o ~/nginxh.sh
chmod +x ~/dnsr.sh ~/nginxh.sh

# Move to system location (no domain config needed)
sudo mv ~/dnsr.sh /usr/local/bin/dnsr
sudo mv ~/nginxh.sh /usr/local/bin/nginxh
```

## Scripts

### setup-vps.sh

Automated configuration script for a fresh Debian VPS: security hardening, user
management, SSH/firewall/fail2ban setup, and optional software (Docker, Remnanode).

**Quick setup** (run directly, no install needed):

```bash
apt install curl -y && bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/setup-vps.sh)"
```

**Features:**
- Full setup mode (all steps in sequence) or interactive mode (pick individual steps)
- System update, hostname change, root password change
- Create users with sudo group and SSH key setup
- Configure SSH (custom port, disable root login and password auth)
- Firewall: UFW or iptables (with iptables-persistent)
- fail2ban with SSH jail and IP whitelist
- Custom MOTD (pulls from the [motd/](../motd/) installer)
- Optional: Docker, Remnanode

**Usage:**
```bash
# Run as root
sudo bash setup-vps.sh
```

**Requirements:** Debian, root privileges, `curl`.

---

### dnsr.sh

DNS record management tool for dnsmasq.

**Features:**
- Multi-domain: pick an existing base domain or add a new one at record creation
- Auto-detects known domains from `/etc/dnsmasq.hosts`
- Add/delete DNS records with IPv4 and IPv6 support
- Rejects duplicate records and requires at least one IP
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

**New domains:** choose `n) New domain` in the picker, type the base domain,
then set the first record (`@` or a subdomain). It shows up as a known domain
on the next run.

---

### nginxh.sh

Nginx virtual host manager for reverse proxy configurations.

**Features:**
- Multi-domain: pick an existing base domain or add a new one per site
- Auto-detects known domains from `/etc/nginx/sites-available/` filenames
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
- No domain config needed; the site picker lists detected domains and offers "New domain"
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

- All scripts require root privileges
- Interactive menus guide you through operations

### Domain tools (`dnsr`, `nginxh`)

- Multi-domain: a "Select domain" menu appears before each operation, listing
  detected base domains plus `n) New domain`
- Base domain detection uses the last two labels of a name; multi-label TLDs
  (e.g. `co.uk`) are not split correctly
- Use `@` to reference the root domain (e.g., `domain.tld` instead of `sub.domain.tld`)

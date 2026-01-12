# Nginx Configuration

Templates and snippets for nginx reverse proxy configurations.

## Quick Install & Update

**Recommended:** Use the installer script with interactive menu for installation and updates:

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh)"
```

Or using wget:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh)"
```

**What the installer does:**
- Checks and optionally installs certbot and python3-certbot-nginx for HTTPS support
- Interactive menu showing installation status of each file
- Install or update templates and snippets individually or all at once
- Visual status indicators:
  - `[✓ Installed]` - Installed in current session
  - `[Installed - can update]` - Already exists, can be updated
  - `[Not installed]` - Not yet installed
- Installs files to `/etc/nginx/templates` and `/etc/nginx/snippets`

## Templates

### template-http.conf
HTTP-only virtual host template for reverse proxy configurations.

### template-https.conf
HTTPS virtual host with SSL/TLS support and automatic HTTP-to-HTTPS redirect.

**Requirements:**
- SSL certificate from Let's Encrypt (use certbot)
- Diffie-Hellman parameters file: `/etc/letsencrypt/ssl-dhparams.pem`
  - Generate manually: `sudo openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 2048`
  - For more security (slower): use 4096 instead of 2048

## Snippets

Reusable configuration blocks that can be included in your nginx configurations:

- **acl-ip.conf** - IP-based access control lists
  - Restrict access to specific IP addresses
  - Edit to add your allowed IPs

- **options-ssl.conf** - SSL/TLS security settings
  - Modern SSL configuration with strong ciphers
  - TLS 1.2 and 1.3 support
  - HSTS enabled

- **proxy.conf** - Standard reverse proxy headers and settings
  - Essential headers for proxying (Host, X-Real-IP, X-Forwarded-For, etc.)
  - WebSocket upgrade headers
  - Connection settings

- **websocket.conf** - WebSocket support configuration
  - Additional headers for WebSocket connections
  - Include after proxy.conf in location blocks

## Usage

**Recommended:** Use with the [nginxh.sh](../scripts/nginxh.sh) script for automated site management.

The nginxh script provides:
- Automatic template application
- SSL certificate generation with certbot
- Snippet management (WebSocket, ACL)
- Site conversion between HTTP and HTTPS
- Domain validation and nginx configuration testing

### Manual Usage

If you prefer to manage configurations manually:

```bash
# Copy template
sudo cp template-http.conf /etc/nginx/sites-available/example.com.conf

# Replace placeholders
sudo sed -i 's/<service>/myapp/g; s/<port>/3000/g; s/<domain>/example.com/g' \
  /etc/nginx/sites-available/example.com.conf

# Enable site
sudo ln -s /etc/nginx/sites-available/example.com.conf /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

## Placeholders

Templates use these placeholders:
- `<service>` - Upstream service name
- `<port>` - Backend port number
- `<domain>` - Domain name

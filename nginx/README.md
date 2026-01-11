# Nginx Configuration

Templates and snippets for nginx reverse proxy configurations.

## Quick Install & Upgrade

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh)"
```

Or using wget:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh)"
```

## Templates

### template-http.conf
HTTP-only virtual host template for reverse proxy configurations.

### template-https.conf
HTTPS virtual host with SSL/TLS support and automatic HTTP-to-HTTPS redirect.

## Snippets

Reusable configuration blocks:

- **acl-ip.conf** - IP-based access control lists
- **proxy.conf** - Standard reverse proxy headers and settings
- **websocket.conf** - WebSocket support configuration

## Usage

Use with the [nginxh.sh](../scripts/nginxh.sh) script for automated site management, or manually:

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

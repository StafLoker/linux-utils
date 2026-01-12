# Linux Utils

Utility scripts, configuration files, and templates for Linux system administration.

## Quick Start

Each component includes an interactive installer with update functionality:

```bash
# Install/update MOTD scripts
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/motd/install.sh | sudo bash

# Install/update Nginx templates & snippets
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/nginx/install.sh | sudo bash

# Install/update management scripts (nginxh, dnsr)
curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/scripts/install.sh | sudo bash
```

## Contents

- **[motd/](motd/)** - Message of the Day scripts for system information display
  - Dynamic system information banners
  - Interactive installer with update functionality
  - Shows CPU, memory, disk, network, services, and Docker stats

- **[nginx/](nginx/)** - Nginx configuration templates and snippets
  - HTTP and HTTPS reverse proxy templates
  - Reusable configuration snippets (SSL, proxy headers, WebSocket, ACL)
  - Interactive installer with update functionality

- **[scripts/](scripts/)** - System administration utility scripts
  - **nginxh** - Nginx site management (add/delete/modify sites with SSL)
  - **dnsr** - DNS records management for dnsmasq
  - Interactive installer with domain configuration
  - Automatic certbot verification for HTTPS sites

- **[os/](os/)** - Operating system configuration files

## Features

All installers include:
- ✅ Interactive menus with visual status indicators
- ✅ Individual or bulk installation/updates
- ✅ Non-destructive updates (preserves customizations where applicable)
- ✅ Automatic dependency checking
- ✅ Clear error messages and rollback on failure

See individual directories for detailed documentation.

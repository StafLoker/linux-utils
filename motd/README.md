# MOTD Scripts

Message of the Day scripts that display system information on login.

## Quick Install & Upgrade

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StafLoker/linux-utils/main/motd/install.sh)"
```

Or using wget:

```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/StafLoker/linux-utils/main/motd/install.sh)"
```

## Manual Installation

Copy scripts to `/etc/update-motd.d/`:
```bash
sudo cp * /etc/update-motd.d/
sudo chmod +x /etc/update-motd.d/*
```

## Scripts

Scripts are numbered to control execution order:

- **10-header** - Custom ASCII art banner
- **20-system** - Hostname, OS version, kernel, uptime
- **30-resources** - CPU, memory, load average
- **40-network** - Network interfaces and IP addresses
- **50-storage** - Disk usage and mount points
- **60-services** - Failed systemd services status
- **70-users** - Active user sessions

## Customization

Edit individual scripts to modify colors, format, or displayed information.

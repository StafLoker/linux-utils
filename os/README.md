# OS Configuration Files

Operating system configuration files and shell customizations.

## Files

### aliases.sh

Common shell aliases for Linux administration.

**Installation:**
```bash
# Add to your shell profile
echo "source $(pwd)/aliases.sh" >> ~/.bashrc
source ~/.bashrc
```

**Included aliases:**
- `ls` shortcuts (ll, la, l)
- File operations (cp, mv, rm with verbose/interactive flags)
- systemctl shortcuts (start, stop, restart, status, enable, disable)
- journalctl shortcuts (logs, logsf, logse)
- Docker shortcuts (dps, dimg, dex, dlogs)
- Navigation helpers

## Customization

Edit `aliases.sh` to add your own aliases or modify existing ones.

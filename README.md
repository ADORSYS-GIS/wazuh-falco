# Wazuh Falco Integration

This project provides scripts to install and uninstall Falco on various Linux distributions following the [official Falco documentation](https://falco.org/docs/setup/packages/).

## Installation

To install Falco, run the following command:

```bash
curl -sL 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-falco/main/scripts/install.sh' | sudo bash
```

The script supports:
- Debian/Ubuntu
- RHEL/CentOS/Fedora/Amazon Linux
- macOS (via Homebrew)

## Uninstallation

To uninstall Falco and remove the configured repositories, run:

```bash
curl -sL 'https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-falco/main/scripts/uninstall.sh' | sudo bash
```

## Documentation

For more information on Falco setup, visit the [official documentation](https://falco.org/docs/setup/).

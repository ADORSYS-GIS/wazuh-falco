#!/bin/bash

# Set shell options
if [ -n "$BASH_VERSION" ]; then
    set -euo pipefail
else
    set -eu
fi

# Define text formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NORMAL='\033[0m'

# Variables
FALCO_YAML_URL="https://raw.githubusercontent.com/ADORSYS-GIS/wazuh-falco/refs/heads/feat/install-config/config/falco.yaml"
UNAME=$(uname -s)
if [ "$UNAME" = "Darwin" ]; then
    if [[ $(uname -m) == 'arm64' ]]; then
        FALCO_CONFIG_DIR="/opt/homebrew/etc/falco"
    else
        FALCO_CONFIG_DIR="/usr/local/etc/falco"
    fi
else
    FALCO_CONFIG_DIR="/etc/falco/config.d"
fi

# Function for logging with timestamp
log() {
    local LEVEL="$1"
    shift
    local MESSAGE="$*"
    local TIMESTAMP
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${TIMESTAMP} ${LEVEL} ${MESSAGE}"
}

# Logging helpers
info_message() {
    log "${BLUE}${BOLD}[INFO]${NORMAL}" "$*"
}

warn_message() {
    log "${YELLOW}${BOLD}[WARNING]${NORMAL}" "$*"
}

error_message() {
    log "${RED}${BOLD}[ERROR]${NORMAL}" "$*"
}

success_message() {
    log "${GREEN}${BOLD}[SUCCESS]${NORMAL}" "$*"
}

print_step() {
    log "${BLUE}${BOLD}[STEP]${NORMAL}" "$1: $2"
}

print_step_header() {
    echo -e "\n${BOLD}===== STEP $1: $2 =====${NORMAL}\n";
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure root privileges, either directly or through sudo
maybe_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command_exists sudo; then
            sudo "$@"
        else
            error_message "This script requires root privileges. Please run with sudo or as root."
            exit 1
        fi
    else
        "$@"
    fi
}

# Error Handler
error_exit() {
    error_message "$1"
    exit 1
}

# Detect OS and Install
if [ -f /etc/debian_version ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected Debian/Ubuntu-based system"

    print_step_header "2" "Adding Falco Repository"
    curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | maybe_sudo gpg --dearmor -o /usr/share/keyrings/falcosecurity-packages.gpg
    echo "deb [signed-by=/usr/share/keyrings/falcosecurity-packages.gpg] https://download.falco.org/packages/deb stable main" | maybe_sudo tee /etc/apt/sources.list.d/falcosecurity.list
    
    info_message "Updating package lists"
    if ! maybe_sudo apt-get update 2>&1 >/dev/null; then
        error_exit "Failed to update package lists"
    fi

    print_step_header "3" "Installing Falco"
    info_message "Using modern-ebpf driver"
    if ! maybe_sudo env FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED=no FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco 2>&1 >/dev/null; then 
        error_exit "Failed to install Falco"
    fi

elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected RHEL/CentOS/Fedora/Amazon Linux-based system"

    print_step_header "2" "Adding Falco Repository"
    maybe_sudo rpm --import https://falco.org/repo/falcosecurity-packages.asc
    if ! maybe_sudo curl -s -o /etc/yum.repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo; then
        error_exit "Failed to add Falco repository"
    fi

    print_step_header "3" "Installing Falco"
    info_message "Using modern-ebpf driver"
    if command_exists dnf; then
        if ! maybe_sudo env FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED=no FALCO_DRIVER_CHOICE=modern_ebpf dnf install -y falco 2>&1 >/dev/null; then
            error_exit "Failed to install Falco using dnf"
        fi
    else
        if ! maybe_sudo env FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED=no FALCO_DRIVER_CHOICE=modern_ebpf yum install -y falco 2>&1 >/dev/null; then
            error_exit "Failed to install Falco using yum"
        fi
    fi

elif [ "$UNAME" = "Darwin" ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected macOS system"

    print_step_header "2" "Installing Falco via Homebrew"
    if ! command_exists brew; then
        error_exit "Homebrew is not installed. Please install it first: https://brew.sh/"
    fi

    if ! brew install falco; then
        error_exit "Failed to install Falco using Homebrew"
    fi
else
    error_exit "Unsupported operating system"
fi

# Step 4: Configuration and Rules
print_step_header "4" "Configuring Falco and Downloading Rules"

info_message "Downloading configuration from ${FALCO_YAML_URL}"
if ! maybe_sudo curl -s -L -o "${FALCO_CONFIG_DIR}/falco.yaml" "${FALCO_YAML_URL}"; then
    error_exit "Failed to download falco.yaml"
fi

info_message "Ensuring log file /var/log/falco_events.json exists"
maybe_sudo touch /var/log/falco_events.json
maybe_sudo chmod 644 /var/log/falco_events.json

# Step 5: Restart Service
print_step_header "5" "Restarting Falco Service"
if [ "$UNAME" = "Darwin" ]; then
    info_message "Restarting Falco via Homebrew services"
    brew services restart falco
else
    info_message "Restarting Falco via systemctl"
    if ! maybe_sudo systemctl restart falco; then
        error_exit "Failed to restart Falco service"
    fi
fi

success_message "Falco installation and configuration completed successfully"

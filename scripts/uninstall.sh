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

# Detect OS
if [ -f /etc/debian_version ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected Debian/Ubuntu-based system"

    print_step_header "2" "Removing Falco Package"
    if ! maybe_sudo apt-get remove -y falco 2>&1 >/dev/null; then
        error_exit "Failed to remove Falco package"
    fi

    print_step_header "3" "Cleaning up repositories and keys"
    maybe_sudo rm -f /etc/apt/sources.list.d/falcosecurity.list
    maybe_sudo rm -f /usr/share/keyrings/falcosecurity-packages.gpg
    
    info_message "Updating package lists"
    maybe_sudo apt-get update 2>&1 >/dev/null || warn_message "Failed to update package lists after cleanup"

elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected RHEL/CentOS/Fedora/Amazon Linux-based system"

    print_step_header "2" "Removing Falco Package"
    if command_exists dnf; then
        if ! maybe_sudo dnf remove -y falco; then
            error_exit "Failed to remove Falco using dnf"
        fi
    else
        if ! maybe_sudo yum remove -y falco; then
            error_exit "Failed to remove Falco using yum"
        fi
    fi

    print_step_header "3" "Cleaning up repositories"
    maybe_sudo rm -f /etc/yum.repos.d/falcosecurity.repo

elif [ "$(uname)" = "Darwin" ]; then
    print_step_header "1" "Detecting OS"
    info_message "Detected macOS system"

    print_step_header "2" "Removing Falco via Homebrew"
    if ! command_exists brew; then
        error_exit "Homebrew not found, cannot uninstall"
    fi
    if ! brew uninstall falco; then
        error_exit "Failed to uninstall Falco via Homebrew"
    fi
else
    error_exit "Unsupported operating system"
fi

success_message "Falco uninstallation completed successfully"

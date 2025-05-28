#!/bin/sh

. /etc/rc.subr

exerr () { echo -e "$*" >&2 ; exit 1; }

# Get the full path of the script
SCRIPT_PATH=$(realpath "$0")
START_FOLDER=$(dirname "$SCRIPT_PATH")

# Define color variables
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BOLD="\033[1m"
RESET="\033[0m"

# Function to check if necessary commands are available
check_dependencies() {
    if [ ! -x "/usr/bin/fetch" ]; then
        exerr "ERROR: fetch is not installed or executable. Please install it and try again."
    fi
    if [ ! -x "$(command -v tar)" ]; then
        exerr "ERROR: tar is not installed or executable. Please install it and try again."
    fi
}

# Function to prompt for confirmation before updating
confirm_action() {
    echo
    echo -e "${YELLOW}${BOLD}WARNING:${RESET}${YELLOW} This will update AdGuard Home to the latest version and overwrite existing files.${RESET}"
    printf "${BOLD}Do you want to continue? (y/N): ${RESET}"
    read -r answer
    case "$answer" in
        [Yy]*) echo -e "${GREEN}Proceeding with update...${RESET}" ;;
        *) echo -e "${RED}Update cancelled by user.${RESET}"; exit 0 ;;
    esac
    echo
}

# Function to get the latest version from GitHub
get_latest_version() {
    json_file="/tmp/agh_latest.json"
    fetch -q -o "$json_file" https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest || exerr "ERROR: Failed to fetch latest release info."

    # Check if file contains a valid tag_name
    latest_version=$(grep -oE '"tag_name": ?"v[0-9]+\.[0-9]+\.[0-9]+"' "$json_file" | head -n1 | cut -d '"' -f4)

    # Sanity check the version string
    if echo "$latest_version" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
        echo "$latest_version"
    else
        exerr "ERROR: Failed to parse latest version from JSON!"
    fi
}

# Function to get the installed version
get_installed_version() {
    if [ -f "/AdGuardHome/AdGuardHome" ]; then
        version_output=$(/AdGuardHome/AdGuardHome --version 2>/dev/null)
        installed_version=$(echo "$version_output" | sed -n 's/.*version \(v[0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
    else
        installed_version="Not Installed"
    fi
    echo "$installed_version"
}

# Function to check for updates
check_update() {
    installed_version=$(get_installed_version)
    latest_version=$(get_latest_version)

    echo -e "Current installed version: ${GREEN}${BOLD}$installed_version${RESET}"
    echo -e "Latest available version:  ${YELLOW}${BOLD}$latest_version${RESET}"

    if [ "$installed_version" != "Not Installed" ] && [ "$installed_version" = "$latest_version" ]; then
        echo -e "${BLUE}${BOLD}Your AdGuardHome is up to date!${RESET}"
    else
        echo -e "${RED}${BOLD}A new version is available! Consider updating.${RESET}"
    fi
}

# Function to update AdGuardHome
update_adguard() {
    # Confirm before proceeding
    confirm_action

    echo -e "${RED}Creating backup of AdGuard Home config...${RESET}"
    cd /AdGuardHome || exerr "ERROR: /AdGuardHome does not exist!"
    tar -czf AdGuardHome_backup.tar.gz AdGuardHome || exerr "ERROR: Backup failed!"
    echo -e "${GREEN}Backup created at /AdGuardHome/AdGuardHome_backup.tar.gz${RESET}"
    echo

    # Get latest version info
    latest_version=$(get_latest_version)
    AGH_ROOT="/"
    DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/$latest_version/AdGuardHome_freebsd_amd64.tar.gz"

    # Create and enter temporary folder
    mkdir -p "$START_FOLDER/temporary" || exerr "ERROR: Could not create temp directory!"
    cd "$START_FOLDER/temporary" || exerr "ERROR: Could not access temp directory!"

    echo -e "Retrieving AdGuardHome version ${BOLD}${latest_version}${RESET}..."
    fetch -o AdGuardHome.tar.gz "$DOWNLOAD_URL" || exerr "ERROR: Failed to download AdGuardHome!"
    echo

    echo -e "Unpacking to ${BOLD}/AdGuardHome${RESET}..."
    tar -xzf AdGuardHome.tar.gz -C "$AGH_ROOT" --strip-components 1 || exerr "ERROR: Failed to extract files!"
    echo

    echo "Stopping AdGuardHome service..."
    service adguard stop || exerr "ERROR: Failed to stop AdGuardHome!"
    echo "Restarting AdGuardHome service..."
    service adguard start || exerr "ERROR: Failed to start AdGuardHome!"
    echo

    currentdate=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}AdGuardHome updated successfully to version ${BOLD}${latest_version}${RESET}"
    echo -e "${BLUE}Update completed on: ${BOLD}${currentdate}${RESET}"

    echo "Cleaning up temporary files..."
    rm -rf "$START_FOLDER/temporary" || exerr "ERROR: Failed to remove temporary folder!"
    echo
}

# Run dependency checks
check_dependencies

# Main logic
if [ -z "$1" ]; then
    exerr "ERROR: You must provide an argument: 'check' or 'update'."
fi

case "$1" in
    check)
        check_update
        ;;
    update)
        update_adguard
        ;;
    *)
        exerr "ERROR: Invalid argument. Use 'check' to check for updates or 'update' to update AdGuardHome."
        ;;
esac

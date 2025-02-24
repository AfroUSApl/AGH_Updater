#!/bin/sh

. /etc/rc.subr

exerr () { echo -e "$*" >&2 ; exit 1; }

# Get the full path of the script
SCRIPT_PATH=$(realpath "$0")  # Get the absolute path of the script
START_FOLDER=$(dirname "$SCRIPT_PATH")  # Extract the directory where the script is located

# Define color variables
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"
BOLD="\033[1m"
RESET="\033[0m"  # Reset text formatting

# Function to check if necessary commands are available
check_dependencies() {
    if [ ! -x "/usr/bin/fetch" ]; then
        exerr "ERROR: fetch is not installed or executable. Please install it and try again."
    fi
    if [ ! -x "$(command -v jq)" ]; then
        exerr "ERROR: jq is not installed or executable. Please install it and try again."
    fi
    if [ ! -x "$(command -v tar)" ]; then
        exerr "ERROR: tar is not installed or executable. Please install it and try again."
    fi
}

# Function to get the latest version from GitHub
get_latest_version() {
    latest_version=$(curl -s https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest | jq -r '.tag_name')
    if [ -z "$latest_version" ] || [ "$latest_version" = "null" ]; then
        exerr "ERROR: Unable to fetch the latest version information."
    fi
    echo "$latest_version"
}

# Function to get the installed version
get_installed_version() {
    if [ -f "/AdGuardHome/AdGuardHome" ]; then
        # Run the version command and capture output
        version_output=$(/AdGuardHome/AdGuardHome --version 2>/dev/null)
        # Extract the version number directly using sed
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

    echo -e "Current installed version: \033[1;32m$installed_version\033[0m"  # Green + Bold
    echo -e "Latest available version: \033[1;33m$latest_version\033[0m"   # Yellow + Bold

    if [ "$installed_version" != "Not Installed" ] && [ "$installed_version" = "$latest_version" ]; then
        echo -e "\033[1;34mYour AdGuardHome is up to date!\033[0m"  # Blue + Bold
    else
        echo -e "\033[1;31mA new version is available! Consider updating.\033[0m"  # Red + Bold
    fi
}

# Function to update AdGuardHome
update_adguard() {

# Backup function to create a backup of AdGuardHome configuration
    echo
    echo -e "${RED}Creating backup of AdGuard Home config ...${RESET}"
    cd /AdGuardHome
    tar -czf /AdGuardHome_backup.tar.gz AdGuardHome
    cd ..
    echo -e "${GREEN}Backup created: /AdGuardHome/AdGuardHome_backup.tar.gz${RESET}"
    echo
    
# Proceeding to update AdGuardHome 
    latest_version=$(get_latest_version)
    AGH_ROOT="/"  # Set your installation directory here
    DOWNLOAD_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${latest_version}/AdGuardHome_freebsd_amd64.tar.gz"
    
    # Create working folder
    mkdir -p $START_FOLDER/temporary || exerr "ERROR: Could not create install directory!"
    cd $START_FOLDER/temporary || exerr "ERROR: Could not access install directory!"

    # Fetch the AdGuard file
    echo -e "Retrieving AdGuardHome version \033[1m${latest_version}\033[0m from \033[1m${DOWNLOAD_URL}\033[0m..."
    fetch -o "AdGuardHome.tar.gz" "$DOWNLOAD_URL" || exerr "ERROR: Failed to download AdGuardHome!"
    echo

    # Extract files into the installation directory
    echo -e "Unpacking the tarball into \033[1m/AdguardHome\033[0m..."
    tar -xzf "AdGuardHome.tar.gz" -C "$AGH_ROOT" --strip-components 1 || exerr "ERROR: Failed to extract files!"
    echo

    # Restart AdGuardHome service
    echo "Restarting AdGuardHome service..."
    service adguard restart || exerr "ERROR: Failed to restart AdGuardHome!"
    echo

    # Display success message
    currentdate=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}AdGuardHome updated successfully to version \033[1m${latest_version}\033[0m."
    echo -e "${BLUE}Update completed on: \033[1m$currentdate${RESET}"
    
    # Cleanup
    echo "Cleaning up temporary files..."
    rm -rf "$START_FOLDER/temporary" || exerr "ERROR: Failed to remove temporary folder!"
    echo
}

# Check for necessary dependencies
check_dependencies

# Main script logic
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

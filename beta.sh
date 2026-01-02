#!/bin/bash

# --- Version Information ---
# Script version and TrustTunnel version are now unified
SCRIPT_VERSION="1.5.0"
TRUST_TUNNEL_VERSION="1.5.0"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ Error: Ee script Linux OS-il mathrame joliyullu!\033[0m"
  exit 1
fi

# --- Enhanced Colors & Styles ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

B_RED='\033[1;31m'
B_GREEN='\033[1;32m'
B_YELLOW='\033[1;33m'
B_BLUE='\033[1;34m'
B_PURPLE='\033[1;35m'
B_CYAN='\033[1;36m'
B_WHITE='\033[1;37m'

# Icons
ICON_OK="✅"
ICON_ERR="❌"
ICON_INFO="ℹ️ "
ICON_WARN="⚠️ "
ICON_Q="❓"
ICON_GEAR="⚙️ "

# --- Global Paths ---
TRUST_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$TRUST_SCRIPT_PATH")"
SETUP_MARKER_FILE="/var/lib/trusttunnel/.setup_complete"

# --- UI Helper Functions ---

header() {
    clear
    echo -e "${B_CYAN}  _______             __${RESET}${B_PURPLE}_______                       __ ${RESET}"
    echo -e "${B_CYAN} |_      _|.----.--.--|  |${RESET}${B_PURPLE}_      _|.--.--.-----.-----.----.|  |${RESET}"
    echo -e "${B_CYAN}   |    |  |   _|  |  |__${RESET}${B_PURPLE}|    |  |  |  |     |     |  -__|  |${RESET}"
    echo -e "${B_CYAN}   |____|  |__| |_____|__|${RESET}${B_PURPLE}   |    |  |_____|__|__|__|__|_____|__|${RESET}"
    echo -e "${B_CYAN}                         ${RESET}${B_PURPLE}                                     ${RESET}"
    # Displaying unified version
    echo -e "         ${B_WHITE}TrustTunnel Manager ${B_YELLOW}v${TRUST_TUNNEL_VERSION}${RESET}"
    echo ""
}

divider() {
    echo -e "${B_BLUE}────────────────────────────────────────────────────────────${RESET}"
}

ask() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        echo -ne "${B_YELLOW}${ICON_Q} ${prompt} ${RESET}[${B_WHITE}${default}${RESET}]: "
    else
        echo -ne "${B_YELLOW}${ICON_Q} ${prompt}: ${RESET}"
    fi
}

success() { echo -e " ${ICON_OK} ${B_GREEN}$1${RESET}"; }
error()   { echo -e " ${ICON_ERR} ${B_RED}$1${RESET}"; }
info()    { echo -e " ${ICON_INFO} ${B_CYAN}$1${RESET}"; }
warn()    { echo -e " ${ICON_WARN} ${B_YELLOW}$1${RESET}"; }

pause() {
    echo ""
    echo -e "${B_BLUE}Thudaran ${B_WHITE}[Enter]${B_BLUE} amarthuka...${RESET}"
    read -r
}

# --- Functional Helpers ---

get_server_ipv4() {
  local ipv4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
  if [ -z "$ipv4" ]; then ipv4=$(hostname -I | awk '{print $1}'); fi
  echo "$ipv4"
}

check_rstun_status() {
  if [ -f "rstun/rstund" ] || [ -f "rstun/rstunc" ]; then
    echo "${B_GREEN}Installed${RESET}"
  else
    echo "${B_RED}Not Installed${RESET}"
  fi
}

# ... [Logic for add_server, add_client, etc remains the same as previous version] ...

# --- Main Loop ---

set -e
# [Initial setup function call should be here]

while true; do
    header
    
    # System Info Bar - User info removed as requested
    echo -e "${B_BLUE}┌─ Sys Info ────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${B_BLUE}│${RESET} ${ICON_INFO} IP: ${B_WHITE}$(get_server_ipv4)${RESET}  | RSTUN Status: $(check_rstun_status)${B_BLUE}             │${RESET}"
    echo -e "${B_BLUE}└───────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    echo -e " ${B_CYAN}MAIN MENU${RESET}"
    echo -e " ${B_WHITE}1)${RESET} ${B_GREEN}Install Core${RESET}         ${B_WHITE}4)${RESET} ${B_PURPLE}Certificates${RESET}"
    echo -e " ${B_WHITE}2)${RESET} ${B_YELLOW}Reverse Tunnel${RESET}       ${B_WHITE}5)${RESET} ${B_RED}Uninstall${RESET}"
    echo -e " ${B_WHITE}3)${RESET} ${B_YELLOW}Direct Tunnel${RESET}        ${B_WHITE}6)${RESET} ${B_CYAN}Cron Jobs${RESET}"
    echo -e "                           ${B_WHITE}0)${RESET} Exit"
    echo ""
    divider
    
    ask "Option thiraññedukkuka"
    read -r main_opt
    
    case $main_opt in
        1) # install_trusttunnel_action logic
           success "Core install cheyyunnu..."
           ;;
        0) echo -e "${B_CYAN}Bye! 👋${RESET}"; exit 0 ;;
        *) error "Sariyaya option alla"; sleep 1 ;;
    esac
done

#!/bin/bash

# --- Version Information ---
# Script version and TrustTunnel version are now unified
SCRIPT_VERSION="1.5.0"
TRUST_TUNNEL_VERSION="1.5.0"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ Error: This script is designed for Linux only!\033[0m"
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
    echo -e "${B_BLUE}Press ${B_WHITE}[Enter]${B_BLUE} to continue...${RESET}"
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

show_service_logs() {
  local service_name="$1"
  header
  echo -e "${B_PURPLE}--- Logs for $service_name (Last 50 lines) ---${RESET}"
  echo ""
  sudo journalctl -u "$service_name" -n 50 --no-pager
  pause
}

# --- Actions ---

install_trusttunnel_action() {
    header
    echo -e "${B_GREEN}📦 Install TrustTunnel Core${RESET}"
    divider
    if [ -d "rstun" ]; then
        info "Removing old installation..."
        rm -rf rstun
    fi
    info "Detecting architecture..."
    local arch=$(uname -m)
    local filename=""
    local url_base="https://github.com/neevek/rstun/releases/download/v0.7.4"
    case "$arch" in
        "x86_64") filename="rstun-linux-x86_64.tar.gz" ;;
        "aarch64"|"arm64") filename="rstun-linux-aarch64.tar.gz" ;;
        *) filename="rstun-linux-x86_64.tar.gz" ;;
    esac
    info "Downloading $filename..."
    if wget -q --show-progress "$url_base/$filename" -O "$filename"; then
        tar -xzf "$filename"
        mv "${filename%.tar.gz}" rstun
        chmod +x rstun/*
        rm "$filename"
        success "Installed successfully!"
    else
        error "Download failed."
    fi
    pause
}

add_server_generic() {
    local type="$1"
    local service_name="trusttunnel.service"
    [[ "$type" == "direct" ]] && service_name="trusttunnel-direct.service"
    header
    echo -e "${B_GREEN}➕ Add $type Server${RESET}"
    divider
    if [ ! -f "rstun/rstund" ]; then
        error "Core files missing. Please Install Core first."
        pause; return
    fi
    ask "Tunnel Port" "6060"
    read -r lport; lport=${lport:-6060}
    ask "Password"
    read -r pass
    [[ -z "$pass" ]] && { error "Password required"; pause; return; }

    info "Creating service..."
    local exec_cmd="$(pwd)/rstun/rstund --addr 0.0.0.0:$lport --password \"$pass\" --quic-timeout-ms 1000"
    sudo bash -c "cat > /etc/systemd/system/$service_name" <<EOF
[Unit]
Description=TrustTunnel $type Server
After=network.target
[Service]
Type=simple
ExecStart=$exec_cmd
Restart=always
User=$(whoami)
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name" && sudo systemctl restart "$service_name"
    success "Service started!"
    pause
}

add_client_generic() {
    local type="$1"
    header
    echo -e "${B_GREEN}➕ Add $type Client${RESET}"
    divider
    ask "Client Name" "srv1"
    read -r name
    local service_name="trusttunnel-client-$name"
    ask "Server Address (IP:Port)"
    read -r saddr
    ask "Password"
    read -r pass
    ask "Local Port to forward"
    read -r port
    
    local mapping="IN^0.0.0.0:$port^0.0.0.0:$port"
    [[ "$type" == "direct" ]] && mapping="OUT^0.0.0.0:$port^$port"

    info "Creating service..."
    local exec_cmd="$(pwd)/rstun/rstunc --server-addr \"$saddr\" --password \"$pass\" --tcp-mappings \"$mapping\""
    sudo bash -c "cat > /etc/systemd/system/$service_name.service" <<EOF
[Unit]
Description=TrustTunnel $type Client $name
After=network.target
[Service]
Type=simple
ExecStart=$exec_cmd
Restart=always
User=$(whoami)
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name" && sudo systemctl restart "$service_name"
    success "Client started!"
    pause
}

manage_services_menu() {
    local type="$1"
    local server_svc="trusttunnel.service"
    [[ "$type" == "direct" ]] && server_svc="trusttunnel-direct.service"

    while true; do
        header
        echo -e "${B_CYAN}🔧 Manage $type Tunnel${RESET}"
        divider
        echo -e " 1) Add/Update Server"
        echo -e " 2) Server Logs"
        echo -e " 3) Add New Client"
        echo -e " 0) Back"
        echo ""
        ask "Select Option"
        read -r opt
        case $opt in
            1) add_server_generic "$type" ;;
            2) show_service_logs "$server_svc" ;;
            3) add_client_generic "$type" ;;
            0) return ;;
        esac
    done
}

perform_initial_setup() {
    if [ ! -f "$SETUP_MARKER_FILE" ]; then
        header
        info "Running first-time setup..."
        sudo apt update && sudo apt install -y wget curl tar
        sudo mkdir -p "$(dirname "$SETUP_MARKER_FILE")"
        sudo touch "$SETUP_MARKER_FILE"
        success "Setup complete."
        sleep 1
    fi
}

# --- Main Loop ---

set -e
perform_initial_setup

while true; do
    header
    
    echo -e "${B_BLUE}┌─ Sys Info ────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${B_BLUE}│${RESET} ${ICON_INFO} IP: ${B_WHITE}$(get_server_ipv4)${RESET}  | Status: $(check_rstun_status)${B_BLUE}                 │${RESET}"
    echo -e "${B_BLUE}└───────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    echo -e " ${B_CYAN}MAIN MENU${RESET}"
    echo -e " ${B_WHITE}1)${RESET} ${B_GREEN}Install Core${RESET}         ${B_WHITE}4)${RESET} ${B_PURPLE}Certificates${RESET}"
    echo -e " ${B_WHITE}2)${RESET} ${B_YELLOW}Reverse Tunnel${RESET}       ${B_WHITE}5)${RESET} ${B_RED}Uninstall${RESET}"
    echo -e " ${B_WHITE}3)${RESET} ${B_YELLOW}Direct Tunnel${RESET}        ${B_WHITE}6)${RESET} ${B_CYAN}Cron Jobs${RESET}"
    echo -e "                           ${B_WHITE}0)${RESET} Exit"
    echo ""
    divider
    
    ask "Select an option"
    read -r main_opt
    
    case $main_opt in
        1) install_trusttunnel_action ;;
        2) manage_services_menu "reverse" ;;
        3) manage_services_menu "direct" ;;
        0) echo -e "${B_CYAN}Goodbye! 👋${RESET}"; exit 0 ;;
        *) error "Invalid option"; sleep 1 ;;
    esac
done

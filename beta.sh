#!/bin/bash

# --- Version Information ---
SCRIPT_VERSION="1.1.0"
TRUST_TUNNEL_VERSION="1.5.0"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ Error: This script is only for Linux!\033[0m"
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
ICON_SRV="🖥️"
ICON_CLI="👥"
ICON_NET="🌐"

# --- Global Paths ---
TRUST_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$TRUST_SCRIPT_PATH")"
CONFIG_FILE="$HOME/.trusttunnel_config"

# --- Configuration Management ---
PREFERRED_VIEW="ALL" 

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

save_config() {
    echo "PREFERRED_VIEW=\"$PREFERRED_VIEW\"" > "$CONFIG_FILE"
}

# --- Helper Functions for Status ---

get_server_status() {
    if systemctl is-active --quiet trusttunnel.service || systemctl is-active --quiet trusttunnel-direct.service; then
        echo -e "${B_GREEN}ON${RESET}"
    else
        echo -e "${RED}OFF${RESET}"
    fi
}

get_active_clients_count() {
    local count=$(systemctl list-units --type=service --all | grep -E "trusttunnel.*client" | grep -v "grep" | wc -l)
    if [ "$count" -gt 0 ]; then
        echo -e "${B_PURPLE}$count Active${RESET}"
    else
        echo -e "${WHITE}None${RESET}"
    fi
}

get_server_ipv4() {
  local ipv4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
  if [ -z "$ipv4" ]; then ipv4=$(hostname -I | awk '{print $1}'); fi
  echo "$ipv4"
}

check_rstun_status() {
  if [ -f "$SCRIPT_DIR/rstun/rstund" ] || [ -f "$SCRIPT_DIR/rstun/rstunc" ]; then
    echo -e "${B_GREEN}Installed${RESET}"
  else
    echo -e "${RED}Missing${RESET}"
  fi
}

# --- UI Components ---

header() {
    clear
    echo -e "${B_CYAN}  _______             __${RESET}${B_PURPLE}_______                       __ ${RESET}"
    echo -e "${B_CYAN} |_     _|.----.--.--|  |${RESET}${B_PURPLE}_     _|.--.--.-----.-----.----.|  |${RESET}"
    echo -e "${B_CYAN}   |   |  |   _|  |  |__${RESET}${B_PURPLE}|   |  |  |  |     |     |  -__|  |${RESET}"
    echo -e "${B_CYAN}   |___|  |__| |_____|__|${RESET}${B_PURPLE}   |  |_____|__|__|__|__|_____|__|${RESET}"
    echo -e "${B_CYAN}                         ${RESET}${B_PURPLE}                                    ${RESET}"
    echo -e "         ${B_WHITE}TrustTunnel Manager ${B_YELLOW}v${TRUST_TUNNEL_VERSION}${RESET} | ${B_GREEN}Script v${SCRIPT_VERSION}${RESET}"
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
    echo -e "${B_BLUE}Press ${B_WHITE}[Enter]${B_BLUE} to return to menu...${RESET}"
    read -r
}

# --- Installation & Core Actions ---

install_trusttunnel_action() {
    header
    echo -e "${B_GREEN}📦 Install TrustTunnel Core${RESET}"
    divider
    info "Downloading latest binaries..."
    local arch=$(uname -m)
    local filename="rstun-linux-x86_64.tar.gz"
    [[ "$arch" == "aarch64" ]] && filename="rstun-linux-aarch64.tar.gz"
    
    mkdir -p "$SCRIPT_DIR/rstun_tmp"
    if wget -q --show-progress "https://github.com/neevek/rstun/releases/download/v0.7.4/$filename" -O "$SCRIPT_DIR/$filename"; then
        tar -xzf "$SCRIPT_DIR/$filename" -C "$SCRIPT_DIR/"
        # Rename extracted folder to 'rstun' for consistency
        local extracted_dir=$(tar -tf "$SCRIPT_DIR/$filename" | head -1 | cut -f1 -d"/")
        if [ "$extracted_dir" != "rstun" ]; then
            rm -rf "$SCRIPT_DIR/rstun"
            mv "$SCRIPT_DIR/$extracted_dir" "$SCRIPT_DIR/rstun"
        fi
        chmod +x "$SCRIPT_DIR/rstun"/*
        rm "$SCRIPT_DIR/$filename"
        success "Installation complete."
    else
        error "Download failed. Check your internet connection."
    fi
    pause
}

add_server_generic() {
    local type="$1"
    local s_name="trusttunnel.service"
    [[ "$type" == "direct" ]] && s_name="trusttunnel-direct.service"
    
    header
    echo -e "${B_GREEN}➕ Add $type Server${RESET}"
    divider
    ask "Listen Port" "6060"; read -r lport; lport=${lport:-6060}
    ask "Password"; read -r pass
    if [[ -z "$pass" ]]; then
        error "Password cannot be empty!"
        pause; return
    fi
    
    info "Configuring systemd service..."
    local exec_cmd="$SCRIPT_DIR/rstun/rstund --addr 0.0.0.0:$lport --password \"$pass\" --tcp-upstream 8800 --udp-upstream 8800"
    
    sudo bash -c "cat > /etc/systemd/system/$s_name" <<EOF
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
    sudo systemctl daemon-reload && sudo systemctl enable "$s_name" && sudo systemctl restart "$s_name"
    success "Server $s_name is now active!"; pause
}

# --- Port Management ---

manage_client_ports() {
    local type="$1"
    local srv_pattern="trusttunnel-"
    [[ "$type" == "direct" ]] && srv_pattern="trusttunnel-direct-client-"

    while true; do
        header
        echo -e "${B_CYAN}🔧 Manage Ports for $type Client${RESET}"
        divider
        mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | grep "client" | awk '{print $1}' | sed 's/.service$//')
        
        if [ ${#clients[@]} -eq 0 ]; then
            warn "No $type clients found in system services."
            pause; return
        fi

        local i=1
        for c in "${clients[@]}"; do echo -e "  ${B_YELLOW}$i)${RESET} $c"; ((i++)); done
        echo -e "  ${B_YELLOW}0)${RESET} Back"
        echo ""
        ask "Select Client"
        read -r ci
        
        [[ "$ci" -eq 0 || -z "$ci" ]] && return
        local idx=$((ci-1))
        if [[ -z "${clients[$idx]}" ]]; then error "Invalid selection"; sleep 1; continue; fi

        local service_name="${clients[$idx]}"
        local service_file="/etc/systemd/system/${service_name}.service"
        
        # --- Internal Port Edit Loop ---
        edit_client_logic "$service_name" "$service_file" "$type"
    done
}

edit_client_logic() {
    local service_name="$1"
    local service_file="$2"
    local type="$3"

    local exec_line=$(grep '^ExecStart=' "$service_file" | cut -d= -f2-)
    local saddr=$(echo "$exec_line" | grep -oP '(?<=--server-addr ")[^"]*' | head -1)
    local pass=$(echo "$exec_line" | grep -oP '(?<=--password ")[^"]*' | head -1)
    local old_tcp=$(echo "$exec_line" | grep -oP '(?<=--tcp-mappings ")[^"]*' | head -1)
    local old_udp=$(echo "$exec_line" | grep -oP '(?<=--udp-mappings ")[^"]*' | head -1)
    
    local tcp_ports=()
    local udp_ports=()
    IFS=',' read -ra ADDR_T <<< "$old_tcp"
    for map in "${ADDR_T[@]}"; do local p="${map##*:}"; [[ "$p" =~ ^[0-9]+$ ]] && tcp_ports+=("$p"); done
    IFS=',' read -ra ADDR_U <<< "$old_udp"
    for map in "${ADDR_U[@]}"; do local p="${map##*:}"; [[ "$p" =~ ^[0-9]+$ ]] && udp_ports+=("$p"); done

    while true; do
        header
        echo -e "${B_PURPLE}Editing: $service_name${RESET}"
        divider
        echo -ne "${B_BLUE}TCP Ports:${RESET} ${tcp_ports[*]:-None}\n"
        echo -ne "${B_BLUE}UDP Ports:${RESET} ${udp_ports[*]:-None}\n"
        echo ""
        echo -e " ${B_WHITE}1)${RESET} Add Port    ${B_WHITE}2)${RESET} Remove Port    ${B_WHITE}3)${RESET} Save & Restart    ${B_WHITE}0)${RESET} Cancel"
        echo ""
        ask "Action"
        read -r action
        
        case $action in
            1)
                ask "Port Number"; read -r new_p
                [[ ! "$new_p" =~ ^[0-9]+$ ]] && continue
                ask "Type (tcp/udp/both)" "both"; read -r proto; proto=${proto:-both}
                [[ "$proto" == "tcp" || "$proto" == "both" ]] && tcp_ports+=("$new_p")
                [[ "$proto" == "udp" || "$proto" == "both" ]] && udp_ports+=("$new_p")
                tcp_ports=($(echo "${tcp_ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
                udp_ports=($(echo "${udp_ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
                ;;
            2)
                ask "Port to remove"; read -r del_p
                tcp_ports=($(echo "${tcp_ports[@]}" | sed "s/\b$del_p\b//g"))
                udp_ports=($(echo "${udp_ports[@]}" | sed "s/\b$del_p\b//g"))
                ;;
            3)
                local t_maps="" u_maps=""
                for p in "${tcp_ports[@]}"; do
                    m="IN^0.0.0.0:$p^0.0.0.0:$p"; [[ "$type" == "direct" ]] && m="OUT^0.0.0.0:$p^$p"
                    [[ -z "$t_maps" ]] && t_maps="$m" || t_maps="$t_maps,$m"
                done
                for p in "${udp_ports[@]}"; do
                    m="IN^0.0.0.0:$p^0.0.0.0:$p"; [[ "$type" == "direct" ]] && m="OUT^0.0.0.0:$p^$p"
                    [[ -z "$u_maps" ]] && u_maps="$m" || u_maps="$u_maps,$m"
                done
                
                local args=""
                [[ -n "$t_maps" ]] && args="$args --tcp-mappings \"$t_maps\""
                [[ -n "$u_maps" ]] && args="$args --udp-mappings \"$u_maps\""
                
                local exec_cmd="$SCRIPT_DIR/rstun/rstunc --server-addr \"$saddr\" --password \"$pass\" $args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000 --wait-before-retry-ms 3000"
                sudo bash -c "cat > $service_file" <<EOF
[Unit]
Description=TrustTunnel Client Updated
After=network.target
[Service]
Type=simple
ExecStart=$exec_cmd
Restart=always
RestartSec=5
User=$(whoami)
[Install]
WantedBy=multi-user.target
EOF
                sudo systemctl daemon-reload && sudo systemctl restart "$service_name"
                success "Configuration saved and service restarted."; pause; return ;;
            0) return ;;
        esac
    done
}

# --- Menus ---

manage_services_menu() {
    local type="$1"
    while true; do
        header
        echo -e "${B_CYAN}🔧 Manage $type Tunnel${RESET}"
        divider
        echo -e "  ${B_WHITE}1)${RESET} Add/Update Server"
        echo -e "  ${B_WHITE}2)${RESET} Manage Client Ports"
        echo -e "  ${B_WHITE}3)${RESET} View Live Logs"
        echo -e "  ${B_WHITE}0)${RESET} Back"
        echo ""
        ask "Option"
        read -r m_opt
        case $m_opt in
            1) add_server_generic "$type" ;;
            2) manage_client_ports "$type" ;;
            3) 
               info "Showing logs (Ctrl+C to stop)..."
               sleep 1
               journalctl -f -u "trusttunnel*" ;;
            0) return ;;
            *) error "Invalid selection"; sleep 1 ;;
        esac
    done
}

settings_menu() {
    while true; do
        header
        echo -e "${B_CYAN}${ICON_GEAR} Preferences${RESET}"
        divider
        echo -e " Current View: ${B_PURPLE}$PREFERRED_VIEW${RESET}"
        echo ""
        echo -e "  ${B_WHITE}1)${RESET} View: ALL (Hybrid)"
        echo -e "  ${B_WHITE}2)${RESET} View: REVERSE Focused"
        echo -e "  ${B_WHITE}3)${RESET} View: DIRECT Focused"
        echo -e "  ${B_WHITE}0)${RESET} Back"
        echo ""
        ask "Select Option"
        read -r s
        case $s in
            1) PREFERRED_VIEW="ALL" ;;
            2) PREFERRED_VIEW="REVERSE" ;;
            3) PREFERRED_VIEW="DIRECT" ;;
            0) return ;;
            *) continue ;;
        esac
        save_config; success "Preferences updated."; sleep 1
    done
}

# --- Main Entry ---

load_config

while true; do
    header
    
    # --- Live Sys Info Bar ---
    echo -e "${B_BLUE}┌─ Sys Info ────────────────────────────────────────────────────────┐${RESET}"
    echo -ne "${B_BLUE}│${RESET} ${ICON_NET} IP: ${B_WHITE}$(get_server_ipv4)${RESET}"
    echo -ne "  ${ICON_SRV} SVR: $(get_server_status)"
    echo -ne "  ${ICON_CLI} CLI: $(get_active_clients_count)"
    echo -e "  Core: $(check_rstun_status)${B_BLUE} │${RESET}"
    echo -e "${B_BLUE}└───────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    # Dynamic Menu Building
    if [[ "$PREFERRED_VIEW" == "ALL" ]]; then
        echo -e "  ${B_WHITE}1)${RESET} Install Core      ${B_WHITE}4)${RESET} Certificates"
        echo -e "  ${B_WHITE}2)${RESET} Reverse Tunnel    ${B_WHITE}5)${RESET} Settings"
        echo -e "  ${B_WHITE}3)${RESET} Direct Tunnel     ${B_WHITE}6)${RESET} Uninstall"
        echo -e "                     ${B_WHITE}0)${RESET} Exit"
    elif [[ "$PREFERRED_VIEW" == "REVERSE" ]]; then
        echo -e "  ${B_WHITE}1)${RESET} Install Core      ${B_WHITE}4)${RESET} Certificates"
        echo -e "  ${B_WHITE}2)${RESET} ${B_GREEN}Manage Reverse${RESET}    ${B_WHITE}5)${RESET} Settings"
        echo -e "  ${B_WHITE}3)${RESET} Cron & Tools      ${B_WHITE}0)${RESET} Exit"
    else
        echo -e "  ${B_WHITE}1)${RESET} Install Core      ${B_WHITE}4)${RESET} Certificates"
        echo -e "  ${B_WHITE}2)${RESET} ${B_GREEN}Manage Direct${RESET}     ${B_WHITE}5)${RESET} Settings"
        echo -e "  ${B_WHITE}3)${RESET} Cron & Tools      ${B_WHITE}0)${RESET} Exit"
    fi
    echo ""
    divider
    
    ask "Option"
    read -r opt
    
    case $opt in
        1) install_trusttunnel_action ;;
        2) 
           if [[ "$PREFERRED_VIEW" == "DIRECT" ]]; then
               manage_services_menu "direct"
           else
               manage_services_menu "reverse"
           fi
           ;;
        3) 
           if [[ "$PREFERRED_VIEW" == "ALL" ]]; then
               manage_services_menu "direct"
           else
               info "Cron & Tools coming soon..."; pause
           fi
           ;;
        4) info "Certificates Management coming soon..."; pause ;;
        5) settings_menu ;;
        6) warn "Uninstall logic not implemented yet."; pause ;;
        0) clear; exit 0 ;;
        *) error "Invalid selection"; sleep 1 ;;
    esac
done

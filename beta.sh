#!/bin/bash

# --- Version Information ---
RSTUN_VERSION="0.7.4"
TRUST_TUNNEL_VERSION="3.0.0"
AUTHOR="@Erfan_XRay"
GITHUB_REPO="https://github.com/Erfan-XRay/TrustTunnel"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ Error: This script is designed for Linux only!\033[0m"
  exit 1
fi

# --- Colors & Styles ---
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
ICON_LINK="🔗"
ICON_TG="✈️ "

# --- Global Paths ---
TRUST_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$TRUST_SCRIPT_PATH")"
SETUP_MARKER_FILE="/var/lib/trusttunnel/.setup_complete"

# --- UI Helper Functions ---

header() {
    clear
    if command -v figlet >/dev/null 2>&1; then
        echo -e "${B_CYAN}"
        figlet -f slant "TrustTunnel"
        echo -e "${RESET}"
    else
        echo -e "${B_CYAN}  _______                __${RESET}${B_PURPLE}_______                        __ ${RESET}"
        echo -e "${B_CYAN} |_   _|.----.--.--|  |${RESET}${B_PURPLE}_   _|.--.--.-----.-----.----.|  |${RESET}"
        echo -e "${B_CYAN}   |   |  |   _|  |  |__${RESET}${B_PURPLE}|   |  |  |  |     |     |  __|  |${RESET}"
        echo -e "${B_CYAN}   |___|  |__| |_____|__|${RESET}${B_PURPLE}   |  |_____|__|__|__|__|_____|__|${RESET}"
    fi
    
    echo -e " ${B_WHITE}TrustTunnel Manager ${B_YELLOW}v${TRUST_TUNNEL_VERSION}${RESET} | ${B_GREEN}Core v${RSTUN_VERSION}${RESET}"
    echo -e " ${B_BLUE}${ICON_LINK} GitHub: ${B_WHITE}${GITHUB_REPO}${RESET}"
    echo -e " ${B_BLUE}${ICON_TG} Telegram: ${B_WHITE}${AUTHOR}${RESET}"
    divider
}

divider() {
    echo -e "${B_BLUE}───────────────────────────────────────────────────────────────────${RESET}"
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
    echo -e "${B_GREEN}Installed (v$RSTUN_VERSION)${RESET}"
  else
    echo -e "${B_RED}Not Installed${RESET}"
  fi
}

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

show_service_logs() {
  local service_name="$1"
  header
  echo -e "${B_PURPLE}--- Logs for $service_name (Last 50 lines) ---${RESET}"
  echo ""
  sudo journalctl -u "$service_name" -n 50 --no-pager
  pause
}

# --- Advanced Port Management ---

manage_ports_action() {
    local type="$1"
    local service_name="$2"
    local service_path="/etc/systemd/system/${service_name}.service"
    
    if [ ! -f "$service_path" ]; then
        error "Service file not found."
        pause; return
    fi

    # Extract current ExecStart line
    local current_exec=$(grep "ExecStart=" "$service_path" | sed 's/ExecStart=//')
    # Extract TCP mappings string
    local tcp_maps=$(echo "$current_exec" | grep -oP '(?<=--tcp-mappings\s")[^"]+' || echo "")
    
    # Load into array for manipulation
    IFS=',' read -r -a port_array <<< "$tcp_maps"

    while true; do
        header
        echo -e "${B_PURPLE}⚙️  Port Management: ${B_WHITE}$service_name${RESET}"
        divider
        
        echo -e "${B_CYAN}Current Active Mappings:${RESET}"
        if [ ${#port_array[@]} -eq 0 ] || [ -z "${port_array[0]}" ]; then
            echo -e " ${RED}No ports configured.${RESET}"
        else
            local i=1
            for mapping in "${port_array[@]}"; do
                local p_num=$(echo "$mapping" | grep -oP '\d+$')
                echo -e " ${B_WHITE}$i)${RESET} Port ${B_GREEN}$p_num${RESET}"
                ((i++))
            done
        fi
        
        divider
        echo -e " ${B_YELLOW}[A]${RESET} Add Port    ${B_RED}[R]${RESET} Remove Port    ${B_GREEN}[S]${RESET} Save & Restart    ${B_WHITE}[0]${RESET} Cancel"
        echo ""
        
        ask "Selection"
        read -r action
        
        case $action in
            [Aa])
                ask "Port Number to Add"
                read -r p
                if validate_port "$p"; then
                    local new_m=""
                    if [[ "$type" == "direct" ]]; then
                        new_m="OUT^0.0.0.0:$p^$p"
                    else
                        new_m="IN^0.0.0.0:$p^0.0.0.0:$p"
                    fi
                    port_array+=("$new_m")
                    success "Port $p added to staging list."
                else
                    error "Invalid port."
                fi
                sleep 1
                ;;
            [Rr])
                ask "Enter index (number) to remove"
                read -r idx
                if [[ "$idx" -gt 0 && "$idx" -le "${#port_array[@]}" ]]; then
                    port_array=("${port_array[@]:0:$((idx-1))}" "${port_array[@]:$idx}")
                    success "Removed from staging list."
                else
                    error "Invalid index."
                fi
                sleep 1
                ;;
            [Ss])
                info "Applying changes..."
                local final_maps=$(IFS=,; echo "${port_array[*]}")
                local updated_exec="$current_exec"
                
                # Update both TCP and UDP mappings to match
                updated_exec=$(echo "$updated_exec" | sed -E "s/--tcp-mappings\s+\"[^\"]*\"/--tcp-mappings \"$final_maps\"/")
                updated_exec=$(echo "$updated_exec" | sed -E "s/--udp-mappings\s+\"[^\"]*\"/--udp-mappings \"$final_maps\"/")
                
                sudo sed -i "s|^ExecStart=.*|ExecStart=$updated_exec|" "$service_path"
                sudo systemctl daemon-reload
                sudo systemctl restart "$service_name"
                success "Service updated and restarted!"
                pause; return
                ;;
            0) return ;;
        esac
    done
}

# --- Installation & Setup ---

perform_initial_setup() {
    if [ -f "$SETUP_MARKER_FILE" ]; then return 0; fi
    header
    info "Installing system dependencies..."
    sudo apt update && sudo apt install -y build-essential curl pkg-config libssl-dev git figlet certbot cron wget
    sudo mkdir -p "$(dirname "$SETUP_MARKER_FILE")"
    sudo touch "$SETUP_MARKER_FILE"
    success "Setup complete."
    sleep 1
}

install_core() {
    header
    echo -e "${B_GREEN}📦 Install RSTun Core${RESET}"
    divider
    local arch=$(uname -m)
    local filename=""
    case "$arch" in
        "x86_64") filename="rstun-linux-x86_64.tar.gz" ;;
        "aarch64"|"arm64") filename="rstun-linux-aarch64.tar.gz" ;;
        *) error "Unsupported architecture: $arch"; pause; return ;;
    esac

    info "Downloading binaries for $arch..."
    wget -q --show-progress "https://github.com/neevek/rstun/releases/download/v$RSTUN_VERSION/$filename" -O "$filename"
    tar -xzf "$filename"
    mv rstun-linux-* rstun
    chmod +x rstun/*
    rm "$filename"
    success "RSTun installed successfully."
    pause
}

# --- Tunnel Configuration ---

add_server() {
    local type="$1" # reverse or direct
    header
    echo -e "${B_GREEN}➕ Setup ${type^} Server${RESET}"
    divider
    
    ask "Listen Port" "6060"
    read -r lport; lport=${lport:-6060}
    ask "Password"
    read -r pass
    
    local service_name="trusttunnel-${type}.service"
    local exec_cmd="$(pwd)/rstun/rstund --addr 0.0.0.0:$lport --password \"$pass\" --tcp-upstream 8800 --udp-upstream 8800"

    sudo bash -c "cat > /etc/systemd/system/$service_name" <<EOF
[Unit]
Description=TrustTunnel ${type^} Server
After=network.target

[Service]
ExecStart=$exec_cmd
Restart=always
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now "$service_name"
    success "Server started: $service_name"
    pause
}

add_client() {
    local type="$1"
    header
    echo -e "${B_GREEN}➕ Add ${type^} Client${RESET}"
    divider
    
    ask "Client Unique Name" "srv1"
    read -r name
    ask "Server IP:Port"
    read -r saddr
    ask "Password"
    read -r pass
    ask "Port to forward" "80"
    read -r p

    local mapping=""
    [[ "$type" == "direct" ]] && mapping="OUT^0.0.0.0:$p^$p" || mapping="IN^0.0.0.0:$p^0.0.0.0:$p"
    
    local service_name="trusttunnel-${type}-client-${name}"
    local exec_cmd="$(pwd)/rstun/rstunc --server-addr \"$saddr\" --password \"$pass\" --tcp-mappings \"$mapping\" --udp-mappings \"$mapping\""

    sudo bash -c "cat > /etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=TrustTunnel Client $name
After=network.target

[Service]
ExecStart=$exec_cmd
Restart=always
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now "${service_name}"
    success "Client $name started!"
    pause
}

# --- Menus ---

manage_tunnel_menu() {
    local type="$1"
    local pattern="trusttunnel-${type}-client-"
    while true; do
        header
        echo -e "${B_CYAN}Manage ${type^} Tunnels${RESET}"
        divider
        echo -e " 1) Setup Server"
        echo -e " 2) Add New Client"
        echo -e " 3) Manage Client Ports"
        echo -e " 4) View Logs"
        echo -e " 5) Delete Client"
        echo -e " 0) Back"
        echo ""
        ask "Option"
        read -r opt
        case $opt in
            1) add_server "$type" ;;
            2) add_client "$type" ;;
            3)
                mapfile -t clients < <(systemctl list-units --all | grep "$pattern" | awk '{print $1}' | sed 's/.service$//')
                if [ ${#clients[@]} -eq 0 ]; then warn "No clients found."; pause; continue; fi
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select Client"; read -r ci
                manage_ports_action "$type" "${clients[$((ci-1))]}"
                ;;
            4)
                mapfile -t clients < <(systemctl list-units --all | grep "trusttunnel-" | awk '{print $1}' | sed 's/.service$//')
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select Service"; read -r ci
                show_service_logs "${clients[$((ci-1))]}"
                ;;
            5)
                mapfile -t clients < <(systemctl list-units --all | grep "$pattern" | awk '{print $1}' | sed 's/.service$//')
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select to DELETE"; read -r ci
                local svc="${clients[$((ci-1))]}"
                sudo systemctl stop "$svc" && sudo systemctl disable "$svc"
                sudo rm "/etc/systemd/system/$svc.service"
                sudo systemctl daemon-reload
                success "Deleted $svc"; pause
                ;;
            0) return ;;
        esac
    done
}

# --- Main ---
perform_initial_setup
while true; do
    header
    echo -e " IP: $(get_server_ipv4) | RSTun: $(check_rstun_status)"
    divider
    echo -e " 1) Install Core"
    echo -e " 2) Reverse Tunnel"
    echo -e " 3) Direct Tunnel"
    echo -e " 4) Uninstall All"
    echo -e " 0) Exit"
    echo ""
    ask "Select"
    read -r m_opt
    case $m_opt in
        1) install_core ;;
        2) manage_tunnel_menu "reverse" ;;
        3) manage_tunnel_menu "direct" ;;
        4) 
           sudo systemctl stop trusttunnel-* 2>/dev/null
           sudo rm /etc/systemd/system/trusttunnel-* 2>/dev/null
           sudo systemctl daemon-reload
           rm -rf rstun
           success "Everything removed."; pause ;;
        0) exit 0 ;;
    esac
done

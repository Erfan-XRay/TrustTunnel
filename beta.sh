#!/bin/bash

# --- Version Information ---
SCRIPT_VERSION="0.7.4"
TRUST_TUNNEL_VERSION="1.5.0"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ خطا: این اسکریپت فقط برای سیستم عامل لینوکس طراحی شده است!\033[0m"
  exit 1
fi

# --- Enhanced Colors & Styles ---
# Using specific ANSI codes for better UI/UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Bright/Neon variations
B_RED='\033[1;31m'
B_GREEN='\033[1;32m'
B_YELLOW='\033[1;33m'
B_BLUE='\033[1;34m'
B_PURPLE='\033[1;35m'
B_CYAN='\033[1;36m'
B_WHITE='\033[1;37m'

# Backgrounds (optional use)
BG_RED='\033[41m'

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

# Header function to clear screen and show banner
header() {
    clear
    echo -e "${B_CYAN}  _______             __${RESET}${B_PURPLE}_______                       __ ${RESET}"
    echo -e "${B_CYAN} |_     _|.----.--.--|  |${RESET}${B_PURPLE}_     _|.--.--.-----.-----.----.|  |${RESET}"
    echo -e "${B_CYAN}   |   |  |   _|  |  |__${RESET}${B_PURPLE}|   |  |  |  |     |     |  -__|  |${RESET}"
    echo -e "${B_CYAN}   |___|  |__| |_____|__|${RESET}${B_PURPLE}   |  |_____|__|__|__|__|_____|__|${RESET}"
    echo -e "${B_CYAN}                         ${RESET}${B_PURPLE}                                    ${RESET}"
    echo -e "         ${B_WHITE}TrustTunnel Manager ${B_YELLOW}v${TRUST_TUNNEL_VERSION}${RESET} | ${B_GREEN}RSTun v${SCRIPT_VERSION}${RESET}"
    echo ""
}

# Print a section divider
divider() {
    echo -e "${B_BLUE}────────────────────────────────────────────────────────────${RESET}"
}

# Prompt user for input (Standardized)
ask() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        echo -ne "${B_YELLOW}${ICON_Q} ${prompt} ${RESET}[${B_WHITE}${default}${RESET}]: "
    else
        echo -ne "${B_YELLOW}${ICON_Q} ${prompt}: ${RESET}"
    fi
}

# Print formatted messages
success() { echo -e " ${ICON_OK} ${B_GREEN}$1${RESET}"; }
error()   { echo -e " ${ICON_ERR} ${B_RED}$1${RESET}"; }
info()    { echo -e " ${ICON_INFO} ${B_CYAN}$1${RESET}"; }
warn()    { echo -e " ${ICON_WARN} ${B_YELLOW}$1${RESET}"; }

# Pause function
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

validate_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 ))
}

validate_host() {
    # Simple regex for IP or Domain
    [[ "$1" =~ ^[a-zA-Z0-9.:\[\]-]+$ ]]
}

validate_email() {
    [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]
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

reset_timer() {
    local service="$1"
    header
    echo -e "${B_CYAN}⏰ Schedule Restart for: ${B_WHITE}$service${RESET}"
    divider
    
    if [[ -z "$service" ]]; then
        ask "Service name to restart"
        read -r service
    fi
    
    if [ ! -f "/etc/systemd/system/${service}.service" ]; then
        error "Service '$service' not found!"
        pause; return 1
    fi

    echo -e "${B_WHITE}1)${RESET} Every 30 mins   ${B_WHITE}2)${RESET} Every 1 hour"
    echo -e "${B_WHITE}3)${RESET} Every 2 hours   ${B_WHITE}4)${RESET} Every 4 hours"
    echo -e "${B_WHITE}5)${RESET} Every 6 hours   ${B_WHITE}6)${RESET} Every 12 hours"
    echo -e "${B_WHITE}7)${RESET} Daily (Midnight)"
    echo ""
    
    ask "Select interval"
    read -r choice

    local cron_time=""
    local desc=""
    
    case "$choice" in
        1) cron_time="*/30 * * * *"; desc="every 30m" ;;
        2) cron_time="0 */1 * * *"; desc="every 1h" ;;
        3) cron_time="0 */2 * * *"; desc="every 2h" ;;
        4) cron_time="0 */4 * * *"; desc="every 4h" ;;
        5) cron_time="0 */6 * * *"; desc="every 6h" ;;
        6) cron_time="0 */12 * * *"; desc="every 12h" ;;
        7) cron_time="0 0 * * *"; desc="Daily" ;;
        *) error "Invalid choice"; pause; return 1 ;;
    esac

    local cron_cmd="/usr/bin/systemctl restart $service >> /var/log/trusttunnel_cron.log 2>&1"
    local job="$cron_time $cron_cmd # TrustTunnel automated restart for $service"
    
    (sudo crontab -l 2>/dev/null | sed "/# TrustTunnel automated restart for $service$/d"; echo "$job") | sudo crontab -
    
    success "Scheduled restart for $service ($desc)."
    pause
}

delete_cron_job_action() {
    header
    echo -e "${B_RED}🗑️  Remove Scheduled Restarts${RESET}"
    divider
    
    mapfile -t services_with_cron < <(sudo crontab -l 2>/dev/null | grep "# TrustTunnel automated restart for" | awk '{print $NF}' | sort -u)

    if [ ${#services_with_cron[@]} -eq 0 ]; then
        info "No scheduled restarts found."
        pause; return
    fi

    local i=1
    for svc in "${services_with_cron[@]}"; do
        echo -e "${B_YELLOW}$i)${RESET} ${B_WHITE}$svc${RESET}"
        ((i++))
    done
    echo -e "${B_YELLOW}0)${RESET} Cancel"
    echo ""
    
    ask "Select service to remove schedule"
    read -r choice
    
    if [[ "$choice" -gt 0 && "$choice" -le "${#services_with_cron[@]}" ]]; then
        local svc="${services_with_cron[$((choice-1))]}"
        (sudo crontab -l | grep -v "# TrustTunnel automated restart for $svc$") | sudo crontab -
        success "Schedule removed for $svc"
    else
        warn "Cancelled."
    fi
    pause
}

uninstall_trusttunnel_action() {
    header
    echo -e "${B_RED}⚠️  DANGER ZONE: UNINSTALL TRUSTTUNNEL${RESET}"
    divider
    ask "Are you sure? This will remove all services and files" "N"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then return; fi

    echo ""
    info "Stopping services..."
    
    # Stop Server
    sudo systemctl stop trusttunnel.service 2>/dev/null
    sudo systemctl disable trusttunnel.service 2>/dev/null
    sudo rm -f /etc/systemd/system/trusttunnel.service

    # Stop Clients
    for svc in $(systemctl list-unit-files | grep '^trusttunnel-.*\.service' | awk '{print $1}'); do
        sudo systemctl stop "$svc" 2>/dev/null
        sudo systemctl disable "$svc" 2>/dev/null
        sudo rm -f "/etc/systemd/system/$svc"
    done
    
    sudo systemctl daemon-reload

    info "Removing files..."
    rm -rf rstun
    sudo rm -f "$SETUP_MARKER_FILE"

    info "Cleaning cron jobs..."
    (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart") | sudo crontab -

    success "Uninstalled successfully."
    pause
}

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
        "armv7l") filename="rstun-linux-armv7.tar.gz" ;;
        *) 
            error "Unsupported: $arch"
            ask "Try x86_64 fallback?" "N"
            read -r fb
            [[ "$fb" =~ ^[Yy]$ ]] && filename="rstun-linux-x86_64.tar.gz" || { pause; return 1; }
            ;;
    esac

    info "Downloading $filename..."
    if wget -q --show-progress "$url_base/$filename" -O "$filename"; then
        success "Downloaded."
        tar -xzf "$filename"
        mv "${filename%.tar.gz}" rstun
        chmod +x rstun/*
        rm "$filename"
        success "Installed successfully!"
    else
        error "Download failed. Trying fallback version (v0.7.1)..."
        # Fallback logic simplified for UI/UX
        local url_fallback="https://github.com/neevek/rstun/releases/download/v0.7.1/$filename"
        if wget -q --show-progress "$url_fallback" -O "$filename"; then
            tar -xzf "$filename"
            mv "${filename%.tar.gz}" rstun
            chmod +x rstun/*
            rm "$filename"
            success "Installed v0.7.1 successfully!"
        else
            error "Installation failed."
        fi
    fi
    pause
}

# --- Generic Add Server (Direct or Reverse) ---
add_server_generic() {
    local type="$1" # "reverse" or "direct"
    local service_name="trusttunnel.service"
    local title="Reverse Tunnel Server"
    local default_port=6060
    local default_tcp=8800
    local default_udp=8800

    if [[ "$type" == "direct" ]]; then
        service_name="trusttunnel-direct.service"
        title="Direct Tunnel Server"
        default_port=8800
        default_tcp=2030
        default_udp=2040
    fi

    header
    echo -e "${B_GREEN}➕ Add $title${RESET}"
    divider
    
    if [ ! -f "rstun/rstund" ]; then
        error "Core files missing. Please Install RSTUN first."
        pause; return
    fi

    # TLS Setup
    local cert_args=""
    ask "Enable TLS/SSL?" "Y"
    read -r tls
    if [[ ! "$tls" =~ ^[Nn]$ ]]; then
        local certs_dir="/etc/letsencrypt/live"
        if [ -d "$certs_dir" ]; then
            mapfile -t domains < <(sudo find "$certs_dir" -maxdepth 1 -mindepth 1 -type d ! -name "README" -exec basename {} \;)
            if [ ${#domains[@]} -gt 0 ]; then
                echo -e "${B_CYAN}Select Certificate:${RESET}"
                local i=1
                for d in "${domains[@]}"; do echo -e "${B_YELLOW}$i)${RESET} $d"; ((i++)); done
                ask "Choice"
                read -r c
                local domain="${domains[$((c-1))]}"
                cert_args="--cert \"$certs_dir/$domain/fullchain.pem\" --key \"$certs_dir/$domain/privkey.pem\""
                success "Selected: $domain"
            else
                error "No certificates found in $certs_dir"
                return
            fi
        else
            error "No certs directory."
            return
        fi
    fi

    # Configs
    local listen_addr="0.0.0.0"
    if [[ "$type" == "direct" ]]; then
        ask "Use IPv6?" "N"
        read -r ipv6
        [[ "$ipv6" =~ ^[Yy]$ ]] && listen_addr="[::]"
    fi

    ask "Tunnel Port" "$default_port"
    read -r lport; lport=${lport:-$default_port}

    ask "TCP Upstream Port" "$default_tcp"
    read -r tport; tport=${tport:-$default_tcp}

    ask "UDP Upstream Port" "$default_udp"
    read -r uport; uport=${uport:-$default_udp}

    ask "Password"
    read -r pass
    if [ -z "$pass" ]; then error "Password required"; pause; return; fi

    # Service Creation
    info "Creating service..."
    local exec_cmd="$(pwd)/rstun/rstund --addr $listen_addr:$lport --password \"$pass\" --tcp-upstream $tport --udp-upstream $uport $cert_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000"
    
    # Just in case for reverse mode, arguments differ slightly in logic but here simplified as they share flags mostly. 
    # Actually reverse server uses --addr as listen for clients (tunnel) and upstream ports for local forwarding? 
    # Let's double check original logic.
    # Original Reverse: --addr (tunnel) --tcp-upstream --udp-upstream
    # Original Direct: --addr (listen) --tcp-upstream --udp-upstream
    # The flags are identical, just logic of use differs. Code is safe.

    sudo bash -c "cat > /etc/systemd/system/$service_name" <<EOF
[Unit]
Description=$title
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

    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name" >/dev/null 2>&1
    sudo systemctl restart "$service_name"
    
    success "Service started!"
    ask "View logs?" "N"
    read -r vlogs
    [[ "$vlogs" =~ ^[Yy]$ ]] && show_service_logs "$service_name"
}

add_client_generic() {
    local type="$1" # "reverse" or "direct"
    local prefix="trusttunnel-"
    local title="Reverse Tunnel Client"
    
    if [[ "$type" == "direct" ]]; then
        prefix="trusttunnel-direct-client-"
        title="Direct Tunnel Client"
    fi

    header
    echo -e "${B_GREEN}➕ Add $title${RESET}"
    divider

    ask "Client Name (e.g., srv1)"
    read -r name
    local service_name="${prefix}${name}"

    if [ -f "/etc/systemd/system/${service_name}.service" ]; then
        error "Client $name already exists!"
        pause; return
    fi

    ask "Server Address (host:port)"
    read -r saddr

    ask "Tunnel Mode (tcp/udp/both)" "both"
    read -r mode; mode=${mode:-both}

    ask "Password"
    read -r pass

    ask "How many ports to forward?" "1"
    read -r count
    count=${count:-1}

    local mappings=""
    for ((i=1; i<=count; i++)); do
        ask "Enter Port #$i"
        read -r p
        local m=""
        if [[ "$type" == "direct" ]]; then
            m="OUT^0.0.0.0:$p^$p"
        else
            m="IN^0.0.0.0:$p^0.0.0.0:$p"
        fi
        
        if [ -z "$mappings" ]; then mappings="$m"; else mappings="$mappings,$m"; fi
    done

    local args=""
    if [[ "$mode" == "tcp" || "$mode" == "both" ]]; then args="$args --tcp-mappings \"$mappings\""; fi
    if [[ "$mode" == "udp" || "$mode" == "both" ]]; then args="$args --udp-mappings \"$mappings\""; fi

    info "Creating service..."
    local exec_cmd="$(pwd)/rstun/rstunc --server-addr \"$saddr\" --password \"$pass\" $args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000 --wait-before-retry-ms 3000"

    sudo bash -c "cat > /etc/systemd/system/${service_name}.service" <<EOF
[Unit]
Description=$title - $name
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

    sudo systemctl daemon-reload
    sudo systemctl enable "${service_name}" >/dev/null 2>&1
    sudo systemctl restart "${service_name}"

    success "Client started!"
    ask "View logs?" "N"
    read -r vlogs
    [[ "$vlogs" =~ ^[Yy]$ ]] && show_service_logs "${service_name}"
}

manage_client_ports() {
    local type="$1"
    local srv_pattern="trusttunnel-"
    if [[ "$type" == "direct" ]]; then srv_pattern="trusttunnel-direct-client-"; fi

    # 1. Select Client
    header
    echo -e "${B_CYAN}🔧 Manage Ports for $type Client${RESET}"
    divider
    mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | awk '{print $1}' | sed 's/.service$//')
    
    if [ ${#clients[@]} -eq 0 ]; then
        warn "No clients found."
        pause; return
    fi

    local i=1
    for c in "${clients[@]}"; do echo -e "${B_YELLOW}$i)${RESET} $c"; ((i++)); done
    echo -e "${B_YELLOW}0)${RESET} Back"
    echo ""
    ask "Select Client"
    read -r ci
    
    if [[ "$ci" -eq 0 || -z "${clients[$((ci-1))]}" ]]; then return; fi
    local service_name="${clients[$((ci-1))]}"
    local service_file="/etc/systemd/system/${service_name}.service"

    # 2. Parse Config
    if [ ! -f "$service_file" ]; then error "Service file not found!"; pause; return; fi
    
    local exec_line=$(grep '^ExecStart=' "$service_file" | cut -d= -f2-)
    
    # Extract params using grep -oP
    local saddr=$(echo "$exec_line" | grep -oP '(?<=--server-addr ")[^"]*')
    local pass=$(echo "$exec_line" | grep -oP '(?<=--password ")[^"]*')
    local old_tcp=$(echo "$exec_line" | grep -oP '(?<=--tcp-mappings ")[^"]*')
    local old_udp=$(echo "$exec_line" | grep -oP '(?<=--udp-mappings ")[^"]*')
    
    # Clean up empty vars
    [ -z "$saddr" ] && error "Could not parse server address!" && pause && return
    
    # Temporary arrays to hold ports
    local tcp_ports=()
    local udp_ports=()
    
    # Populate arrays
    IFS=',' read -ra ADDR <<< "$old_tcp"
    for map in "${ADDR[@]}"; do
        # Extract port from end of string
        local p="${map##*:}"
        [[ "$p" =~ ^[0-9]+$ ]] && tcp_ports+=("$p")
    done
    
    IFS=',' read -ra ADDR <<< "$old_udp"
    for map in "${ADDR[@]}"; do
        local p="${map##*:}"
        [[ "$p" =~ ^[0-9]+$ ]] && udp_ports+=("$p")
    done

    # 3. Edit Loop
    while true; do
        header
        echo -e "${B_PURPLE}Editing: $service_name${RESET}"
        echo -e "Server: $saddr"
        divider
        echo -e "${B_CYAN}Current Ports:${RESET}"
        
        echo -ne "${B_BLUE}[TCP]:${RESET} "
        if [ ${#tcp_ports[@]} -eq 0 ]; then echo "None"; else echo "${tcp_ports[*]}"; fi
        
        echo -ne "${B_BLUE}[UDP]:${RESET} "
        if [ ${#udp_ports[@]} -eq 0 ]; then echo "None"; else echo "${udp_ports[*]}"; fi
        
        echo ""
        echo -e "${B_WHITE}1)${RESET} Add Port"
        echo -e "${B_WHITE}2)${RESET} Remove Port"
        echo -e "${B_WHITE}3)${RESET} Save & Restart"
        echo -e "${B_WHITE}0)${RESET} Cancel"
        echo ""
        
        ask "Select"
        read -r action
        
        case $action in
            1) # Add
                ask "Port Number"
                read -r new_p
                if ! validate_port "$new_p"; then error "Invalid port"; sleep 1; continue; fi
                ask "Type (tcp/udp/both)" "both"
                read -r proto
                proto=${proto:-both}
                
                if [[ "$proto" == "tcp" || "$proto" == "both" ]]; then
                    if [[ ! " ${tcp_ports[*]} " =~ " ${new_p} " ]]; then tcp_ports+=("$new_p"); fi
                fi
                if [[ "$proto" == "udp" || "$proto" == "both" ]]; then
                    if [[ ! " ${udp_ports[*]} " =~ " ${new_p} " ]]; then udp_ports+=("$new_p"); fi
                fi
                ;;
            2) # Remove
                ask "Port to remove"
                read -r del_p
                
                # Rebuild arrays excluding del_p
                local new_tcp=()
                for p in "${tcp_ports[@]}"; do [[ "$p" != "$del_p" ]] && new_tcp+=("$p"); done
                tcp_ports=("${new_tcp[@]}")
                
                local new_udp=()
                for p in "${udp_ports[@]}"; do [[ "$p" != "$del_p" ]] && new_udp+=("$p"); done
                udp_ports=("${new_udp[@]}")
                ;;
            3) # Save
                # Reconstruct strings
                local new_tcp_map=""
                local new_udp_map=""
                
                for p in "${tcp_ports[@]}"; do
                    local m=""
                    if [[ "$type" == "direct" ]]; then m="OUT^0.0.0.0:$p^$p"; else m="IN^0.0.0.0:$p^0.0.0.0:$p"; fi
                    if [ -z "$new_tcp_map" ]; then new_tcp_map="$m"; else new_tcp_map="$new_tcp_map,$m"; fi
                done
                
                for p in "${udp_ports[@]}"; do
                    local m=""
                    if [[ "$type" == "direct" ]]; then m="OUT^0.0.0.0:$p^$p"; else m="IN^0.0.0.0:$p^0.0.0.0:$p"; fi
                    if [ -z "$new_udp_map" ]; then new_udp_map="$m"; else new_udp_map="$new_udp_map,$m"; fi
                done
                
                # Build Args
                local args=""
                if [ -n "$new_tcp_map" ]; then args="$args --tcp-mappings \"$new_tcp_map\""; fi
                if [ -n "$new_udp_map" ]; then args="$args --udp-mappings \"$new_udp_map\""; fi
                
                local exec_cmd="$(pwd)/rstun/rstunc --server-addr \"$saddr\" --password \"$pass\" $args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000 --wait-before-retry-ms 3000"
                
                # Update Service File
                sudo bash -c "cat > $service_file" <<EOF
[Unit]
Description=Reverse Tunnel Client - ${service_name#$srv_pattern}
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
                sudo systemctl daemon-reload
                sudo systemctl restart "$service_name"
                success "Configuration updated!"
                pause
                return
                ;;
            0) return ;;
        esac
    done
}

# --- Certificate Actions ---

cert_menu() {
    while true; do
        header
        echo -e "${B_CYAN}🔐 Certificate Manager${RESET}"
        divider
        echo -e "${B_WHITE}1)${RESET} Get New Cert (Certbot)"
        echo -e "${B_WHITE}2)${RESET} Delete Cert"
        echo -e "${B_WHITE}3)${RESET} Add Custom Cert (Paste)"
        echo -e "${B_WHITE}0)${RESET} Back"
        echo ""
        ask "Select"
        read -r c
        case $c in
            1) 
                ask "Domain"
                read -r d
                ask "Email"
                read -r e
                sudo certbot certonly --standalone -d "$d" --non-interactive --agree-tos -m "$e"
                pause
                ;;
            2)
                ask "Domain to delete"
                read -r d
                sudo certbot delete --cert-name "$d"
                pause
                ;;
            3)
                add_custom_certificate_action
                ;;
            0) return ;;
        esac
    done
}

add_custom_certificate_action() {
    header
    echo -e "${B_GREEN}Paste Certificate Files${RESET}"
    ask "Domain Name"
    read -r domain
    local dir="/etc/letsencrypt/live/$domain"
    sudo mkdir -p "$dir"
    
    echo -e "${B_YELLOW}Paste FULLCHAIN.pem content, type 'END' on new line:${RESET}"
    local fc=""
    while IFS= read -r line; do [[ "$line" == "END" ]] && break; fc+="$line"$'\n'; done
    echo "$fc" | sudo tee "$dir/fullchain.pem" >/dev/null

    echo -e "${B_YELLOW}Paste PRIVKEY.pem content, type 'END' on new line:${RESET}"
    local pk=""
    while IFS= read -r line; do [[ "$line" == "END" ]] && break; pk+="$line"$'\n'; done
    echo "$pk" | sudo tee "$dir/privkey.pem" >/dev/null
    
    success "Saved to $dir"
    pause
}

# --- Initial Setup ---
perform_initial_setup() {
    if [ -f "$SETUP_MARKER_FILE" ]; then return 0; fi
    header
    info "First time setup..."
    sudo apt update && sudo apt install -y build-essential curl pkg-config libssl-dev git figlet certbot rustc cargo cron
    
    if ! command -v rustc >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    
    sudo mkdir -p "$(dirname "$SETUP_MARKER_FILE")"
    sudo touch "$SETUP_MARKER_FILE"
    success "Setup Complete."
    sleep 2
}

# --- Menus ---

manage_services_menu() {
    local type="$1" # reverse or direct
    local srv_pattern="trusttunnel-"
    local server_svc="trusttunnel.service"
    
    if [[ "$type" == "direct" ]]; then
        srv_pattern="trusttunnel-direct-client-"
        server_svc="trusttunnel-direct.service"
    fi

    while true; do
        header
        echo -e "${B_CYAN}🔧 Manage $type Tunnel${RESET}"
        divider
        echo -e "${B_PURPLE}SERVER:${RESET}"
        echo -e " ${B_WHITE}1)${RESET} Add/Update Server"
        echo -e " ${B_WHITE}2)${RESET} Server Logs"
        echo -e " ${B_WHITE}3)${RESET} Stop/Delete Server"
        echo -e " ${B_WHITE}4)${RESET} Schedule Restart (Server)"
        echo ""
        echo -e "${B_PURPLE}CLIENTS:${RESET}"
        echo -e " ${B_WHITE}5)${RESET} Add New Client"
        echo -e " ${B_WHITE}6)${RESET} Client Logs"
        echo -e " ${B_WHITE}7)${RESET} Delete Client"
        echo -e " ${B_WHITE}8)${RESET} Schedule Restart (Client)"
        echo -e " ${B_WHITE}9)${RESET} Manage Client Ports"
        echo ""
        echo -e "${B_WHITE}0)${RESET} Back"
        echo ""
        
        ask "Select Option"
        read -r opt
        
        case $opt in
            1) add_server_generic "$type" ;;
            2) show_service_logs "$server_svc" ;;
            3) 
                info "Stopping $server_svc..."
                sudo systemctl stop "$server_svc" 2>/dev/null
                sudo systemctl disable "$server_svc" 2>/dev/null
                sudo rm -f "/etc/systemd/system/$server_svc"
                sudo systemctl daemon-reload
                success "Deleted."
                pause
                ;;
            4) reset_timer "$server_svc" ;;
            5) add_client_generic "$type" ;;
            6) 
                # List clients
                mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | awk '{print $1}' | sed 's/.service$//')
                if [ ${#clients[@]} -eq 0 ]; then warn "No clients."; pause; continue; fi
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select"; read -r ci
                show_service_logs "${clients[$((ci-1))]}"
                ;;
            7)
                mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | awk '{print $1}' | sed 's/.service$//')
                if [ ${#clients[@]} -eq 0 ]; then warn "No clients."; pause; continue; fi
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select to DELETE"; read -r ci
                local svc="${clients[$((ci-1))]}"
                sudo systemctl stop "$svc" 2>/dev/null
                sudo systemctl disable "$svc" 2>/dev/null
                sudo rm -f "/etc/systemd/system/$svc.service"
                sudo systemctl daemon-reload
                success "Deleted $svc"
                pause
                ;;
            8)
                mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | awk '{print $1}' | sed 's/.service$//')
                if [ ${#clients[@]} -eq 0 ]; then warn "No clients."; pause; continue; fi
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select"; read -r ci
                reset_timer "${clients[$((ci-1))]}"
                ;;
            9) manage_client_ports "$type" ;;
            0) return ;;
            *) error "Invalid"; pause ;;
        esac
    done
}

# --- Main Loop ---

set -e
perform_initial_setup

while true; do
    header
    
    # System Info Bar
    echo -e "${B_BLUE}┌─ Sys Info ────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${B_BLUE}│${RESET} ${ICON_INFO} IP: ${B_WHITE}$(get_server_ipv4)${RESET}  | User: ${B_WHITE}$(whoami)${RESET}  | RSTUN: $(check_rstun_status)${B_BLUE}    │${RESET}"
    echo -e "${B_BLUE}└───────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    
    # Grid Menu Layout
    echo -e " ${B_CYAN}MAIN MENU${RESET}"
    echo -e " ${B_WHITE}1)${RESET} ${B_GREEN}Install Core${RESET}         ${B_WHITE}4)${RESET} ${B_PURPLE}Certificates${RESET}"
    echo -e " ${B_WHITE}2)${RESET} ${B_YELLOW}Reverse Tunnel${RESET}       ${B_WHITE}5)${RESET} ${B_RED}Uninstall${RESET}"
    echo -e " ${B_WHITE}3)${RESET} ${B_YELLOW}Direct Tunnel${RESET}        ${B_WHITE}6)${RESET} ${B_CYAN}Cron Jobs${RESET}"
    echo -e "                          ${B_WHITE}0)${RESET} Exit"
    echo ""
    divider
    
    ask "Select Option"
    read -r main_opt
    
    case $main_opt in
        1) install_trusttunnel_action ;;
        2) manage_services_menu "reverse" ;;
        3) manage_services_menu "direct" ;;
        4) cert_menu ;;
        5) uninstall_trusttunnel_action ;;
        6) delete_cron_job_action ;;
        0) echo -e "${B_CYAN}Bye! 👋${RESET}"; exit 0 ;;
        *) error "Invalid option"; pause ;;
    esac
done

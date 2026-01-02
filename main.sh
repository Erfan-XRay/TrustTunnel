#!/bin/bash

# --- Version Information ---
RSTUN_VERSION="0.7.4"
TRUST_TUNNEL_VERSION="3.0.0"
AUTHOR="@Erfan_XRay"
GITHUB_REPO="https://github.com/Erfan-XRay/TrustTunnel"

# --- System Check ---
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo -e "\033[1;31m❌ خطا: این اسکریپت فقط برای سیستم عامل لینوکس طراحی شده است!\033[0m"
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
ICON_LINK="🔗"
ICON_TG="✈️ "

# --- Global Paths ---
TRUST_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$TRUST_SCRIPT_PATH")"
SETUP_MARKER_FILE="/var/lib/trusttunnel/.setup_complete"

# --- UI Helper Functions ---

header() {
    clear
    # Logo using FIGlet
    if command -v figlet >/dev/null 2>&1; then
        echo -e "${B_CYAN}"
        figlet -f slant "TrustTunnel"
        echo -e "${RESET}"
    else
        # Fallback ASCII Logo
        echo -e "${B_CYAN}  _______               __${RESET}${B_PURPLE}_______                       __ ${RESET}"
        echo -e "${B_CYAN} |_   _|.----.--.--|  |${RESET}${B_PURPLE}_   _|.--.--.-----.-----.----.|  |${RESET}"
        echo -e "${B_CYAN}   |   |  |   _|  |  |__${RESET}${B_PURPLE}|   |  |  |  |     |     |  -__|  |${RESET}"
        echo -e "${B_CYAN}   |___|  |__| |_____|__|${RESET}${B_PURPLE}   |  |_____|__|__|__|__|_____|__|${RESET}"
    fi
    
    echo -e " ${B_WHITE}TrustTunnel Manager ${B_YELLOW}v${TRUST_TUNNEL_VERSION}${RESET} | ${B_GREEN}RSTun v${RSTUN_VERSION}${RESET}"
    echo -e " ${B_BLUE}${ICON_LINK} Project: ${B_WHITE}${GITHUB_REPO}${RESET}"
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
    
    sudo systemctl stop trusttunnel.service 2>/dev/null || true
    sudo systemctl disable trusttunnel.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/trusttunnel.service

    for svc in $(systemctl list-unit-files | grep '^trusttunnel-.*\.service' | awk '{print $1}'); do
        sudo systemctl stop "$svc" 2>/dev/null || true
        sudo systemctl disable "$svc" 2>/dev/null || true
        sudo rm -f "/etc/systemd/system/$svc"
    done
    
    sudo systemctl daemon-reload

    info "Removing files..."
    rm -rf rstun
    sudo rm -f "$SETUP_MARKER_FILE"

    info "Cleaning cron jobs..."
    (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart") | sudo crontab - || true

    success "Uninstalled successfully."
    pause
}

install_trusttunnel_action() {
    header
    echo -e "${B_GREEN}📦 Install TrustTunnel Core (v$RSTUN_VERSION)${RESET}"
    divider

    if [ -d "rstun" ]; then
        info "Removing old installation..."
        rm -rf rstun
    fi

    info "Detecting architecture..."
    local arch=$(uname -m)
    local filename=""
    local url_base="https://github.com/neevek/rstun/releases/download/v$RSTUN_VERSION"
    
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
        local extracted_dir=$(tar -tf "$filename" | head -1 | cut -f1 -d"/")
        mv "$extracted_dir" rstun
        chmod +x rstun/*
        rm "$filename"
        success "Installed version $RSTUN_VERSION successfully!"
    else
        error "Download failed. Check your internet or GitHub availability."
    fi
    pause
}

add_server_generic() {
    local type="$1"
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
                error "No certificates found. Run Certificate Manager first."
                pause; return
            fi
        else
            error "No certs directory found."
            pause; return
        fi
    fi

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

    info "Creating service..."
    local exec_cmd="$(pwd)/rstun/rstund --addr $listen_addr:$lport --password \"$pass\" --tcp-upstream $tport --udp-upstream $uport $cert_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000"
    
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
    pause
}

add_client_generic() {
    local type="$1"
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
    read -r count; count=${count:-1}

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
    pause
}

manage_ports_action() {
    local type="$1"
    local service_name="$2"
    local prefix="trusttunnel-"
    [[ "$type" == "direct" ]] && prefix="trusttunnel-direct-client-"

    header
    echo -e "${B_PURPLE}⚙️  Manage Ports for $service_name${RESET}"
    divider

    local service_path="/etc/systemd/system/${service_name}.service"
    if [ ! -f "$service_path" ]; then
        error "Service file not found."
        pause; return
    fi

    # Extract mappings from service file
    local current_exec=$(grep "ExecStart=" "$service_path" | sed 's/ExecStart=//')
    local tcp_maps=$(echo "$current_exec" | grep -oP '(?<=--tcp-mappings\s")[^"]+' || echo "")
    local udp_maps=$(echo "$current_exec" | grep -oP '(?<=--udp-mappings\s")[^"]+' || echo "")

    echo -e "${B_WHITE}Current Mappings:${RESET}"
    echo -e "TCP: ${B_YELLOW}${tcp_maps:-None}${RESET}"
    echo -e "UDP: ${B_YELLOW}${udp_maps:-None}${RESET}"
    echo ""
    echo -e "${B_WHITE}1)${RESET} Add New Port"
    echo -e "${B_WHITE}2)${RESET} Remove Port"
    echo -e "${B_WHITE}0)${RESET} Back"
    echo ""
    ask "Select"
    read -r port_opt

    case $port_opt in
        1)
            ask "New Port to Forward"
            read -r p
            local new_m=""
            if [[ "$type" == "direct" ]]; then
                new_m="OUT^0.0.0.0:$p^$p"
            else
                new_m="IN^0.0.0.0:$p^0.0.0.0:$p"
            fi
            
            # Update strings
            if [[ -z "$tcp_maps" ]]; then tcp_maps="$new_m"; else tcp_maps="$tcp_maps,$new_m"; fi
            if [[ -z "$udp_maps" ]]; then udp_maps="$new_m"; else udp_maps="$udp_maps,$new_m"; fi
            ;;
        2)
            local all_ports=$(echo "$tcp_maps,$udp_maps" | tr ',' '\n' | grep -oP '\d+$' | sort -u)
            if [ -z "$all_ports" ]; then warn "No ports to remove."; pause; return; fi
            
            mapfile -t ports_list <<< "$all_ports"
            local i=1
            for p in "${ports_list[@]}"; do echo "$i) Port $p"; ((i++)); done
            ask "Select Port to REMOVE"
            read -r p_choice
            local p_val="${ports_list[$((p_choice-1))]}"
            
            tcp_maps=$(echo "$tcp_maps" | tr ',' '\n' | grep -v "$p_val$" | paste -sd "," -)
            udp_maps=$(echo "$udp_maps" | tr ',' '\n' | grep -v "$p_val$" | paste -sd "," -)
            ;;
        0) return ;;
        *) return ;;
    esac

    # Safely update the exec line
    # If mappings become empty, this logic should ideally remove the flag, but we'll stick to updating for now
    local updated_exec="$current_exec"
    if [[ -n "$tcp_maps" ]]; then
        updated_exec=$(echo "$updated_exec" | sed -E "s/--tcp-mappings\s+\"[^\"]*\"/--tcp-mappings \"$tcp_maps\"/")
    fi
    if [[ -n "$udp_maps" ]]; then
        updated_exec=$(echo "$updated_exec" | sed -E "s/--udp-mappings\s+\"[^\"]*\"/--udp-mappings \"$udp_maps\"/")
    fi
    
    sudo sed -i "s|^ExecStart=.*|ExecStart=$updated_exec|" "$service_path"
    sudo systemctl daemon-reload
    sudo systemctl restart "$service_name"
    success "Ports updated and service restarted!"
    pause
}

cert_menu() {
    while true; do
        header
        echo -e "${B_CYAN}🔐 Certificate Manager${RESET}"
        divider
        echo -e " ${B_WHITE}1)${RESET} Get New Cert (Certbot)"
        echo -e " ${B_WHITE}2)${RESET} Delete Cert"
        echo -e " ${B_WHITE}0)${RESET} Back"
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
            0) return ;;
        esac
    done
}

# --- Initial Setup ---
perform_initial_setup() {
    if [ -f "$SETUP_MARKER_FILE" ]; then return 0; fi
    header
    info "Installing dependencies..."
    sudo apt update && sudo apt install -y build-essential curl pkg-config libssl-dev git figlet certbot cron wget
    
    sudo mkdir -p "$(dirname "$SETUP_MARKER_FILE")"
    sudo touch "$SETUP_MARKER_FILE"
    success "Initial setup complete."
    sleep 1
}

manage_services_menu() {
    local type="$1"
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
        echo -e " ${B_WHITE}3)${RESET} Delete Server"
        echo ""
        echo -e "${B_PURPLE}CLIENTS:${RESET}"
        echo -e " ${B_WHITE}4)${RESET} Add New Client"
        echo -e " ${B_WHITE}5)${RESET} Manage Ports"
        echo -e " ${B_WHITE}6)${RESET} Client Logs"
        echo -e " ${B_WHITE}7)${RESET} Delete Client"
        echo ""
        echo -e " ${B_WHITE}0)${RESET} Back"
        echo ""
        
        ask "Select Option"
        read -r opt
        
        case $opt in
            1) add_server_generic "$type" ;;
            2) show_service_logs "$server_svc" ;;
            3) 
                sudo systemctl stop "$server_svc" 2>/dev/null || true
                sudo systemctl disable "$server_svc" 2>/dev/null || true
                sudo rm -f "/etc/systemd/system/$server_svc"
                sudo systemctl daemon-reload
                success "Deleted."
                pause
                ;;
            4) add_client_generic "$type" ;;
            5)
                mapfile -t clients < <(systemctl list-units --type=service --all | grep "$srv_pattern" | awk '{print $1}' | sed 's/.service$//')
                if [ ${#clients[@]} -eq 0 ]; then warn "No clients."; pause; continue; fi
                local i=1; for c in "${clients[@]}"; do echo "$i) $c"; ((i++)); done
                ask "Select client to manage ports"; read -r ci
                manage_ports_action "$type" "${clients[$((ci-1))]}"
                ;;
            6)
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
                sudo systemctl stop "$svc" 2>/dev/null || true
                sudo systemctl disable "$svc" 2>/dev/null || true
                sudo rm -f "/etc/systemd/system/$svc.service"
                sudo systemctl daemon-reload
                success "Deleted $svc"
                pause
                ;;
            0) return ;;
        esac
    done
}

# --- Main Loop ---
perform_initial_setup

while true; do
    header
    echo -e "${B_BLUE}┌─ Sys Info ────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${B_BLUE}│${RESET} ${ICON_INFO} IP: ${B_WHITE}$(get_server_ipv4)${RESET}  | User: ${B_WHITE}$(whoami)${RESET}  | RSTUN: $(check_rstun_status)${B_BLUE}     │${RESET}"
    echo -e "${B_BLUE}└───────────────────────────────────────────────────────────────────┘${RESET}"
    echo ""
    echo -e " ${B_CYAN}MAIN MENU${RESET}"
    echo -e " ${B_WHITE}1)${RESET} ${B_GREEN}Install Core${RESET}         ${B_WHITE}4)${RESET} ${B_PURPLE}Certificates${RESET}"
    echo -e " ${B_WHITE}2)${RESET} ${B_YELLOW}Reverse Tunnel${RESET}       ${B_WHITE}5)${RESET} ${B_RED}Uninstall${RESET}"
    echo -e " ${B_WHITE}3)${RESET} ${B_YELLOW}Direct Tunnel${RESET}        ${B_WHITE}6)${RESET} ${B_CYAN}Cron Jobs${RESET}"
    echo -e "                           ${B_WHITE}0)${RESET} Exit"
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

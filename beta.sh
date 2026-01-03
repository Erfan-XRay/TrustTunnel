#!/bin/bash

# Define colors for better terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m' # No Color
BOLD_GREEN='\033[1;32m' # Bold Green for menu title

# --- Global Paths and Markers ---
# Use readlink -f to get the canonical path of the script, resolving symlinks and /dev/fd/ issues
TRUST_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$TRUST_SCRIPT_PATH")"
SETUP_MARKER_FILE="/var/lib/trusttunnel/.setup_complete"
# TRUST_COMMAND_PATH="/usr/local/bin/trust" # Removed as per user request

# --- Helper Functions ---

# Function to draw a colored line for menu separation
draw_line() {
  local color="$1"
  local char="$2"
  local length=${3:-40} # Default length 40 if not provided
  printf "${color}"
  for ((i=0; i<length; i++)); do
    printf "$char"
  done
  printf "${RESET}\n"
}

# Function to print success messages in green
print_success() {
  local message="$1"
  echo -e "\033[0;32m✅ $message\033[0m" # Green color for success messages
}

# Function to print error messages in red
print_error() {
  local message="$1"
  echo -e "\033[0;31m❌ $message\033[0m" # Red color for error messages
}

# Function to show service logs and return to a "menu"
show_service_logs() {
  local service_name="$1"
  clear # Clear the screen before showing logs
  echo -e "\033[0;34m--- Displaying logs for $service_name ---\033[0m" # Blue color for header

  # Display the last 50 lines of logs for the specified service
  # --no-pager ensures the output is direct to the terminal without opening 'less'
  sudo journalctl -u "$service_name" -n 50 --no-pager

  echo ""
  echo -e "\033[1;33mPress any key to return to the previous menu...\033[0m" # Yellow color for prompt
  read -n 1 -s -r # Read a single character, silent, raw input

  clear
}

# Function to draw a green line (used for main menu border)
draw_green_line() {
  echo -e "${GREEN}+--------------------------------------------------------+${RESET}"
}

# --- Validation Functions ---

# Function to validate an email address
validate_email() {
  local email="$1"
  if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
    return 0 # Valid
  else
    return 1 # Invalid
  fi
}

# Function to validate a port number
validate_port() {
  local port="$1"
  if [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
    return 0 # Valid
  else
    return 1 # Invalid
  fi
}

validate_host() {
  local host="$1"
  
  # حذف براکت‌های اطراف IPv6 در صورت وجود
  host="${host#[}"
  host="${host%]}"
  
  local ipv4_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
  local domain_regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
  local ipv6_regex="^(([0-9a-fA-F]{1,4}:){7}([0-9a-fA-F]{1,4}|:)|\
([0-9a-fA-F]{1,4}:){1,7}:|\
([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|\
([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|\
([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|\
([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|\
([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|\
[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|\
:((:[0-9a-fA-F]{1,4}){1,7}|:)|\
fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|\
::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9])|\
([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1?[0-9])?[0-9])\.){3}(25[0-5]|(2[0-4]|1?[0-9])?[0-9]))$"

  if [[ "$host" =~ $ipv4_regex ]] || [[ "$host" =~ $domain_regex ]] || [[ "$host" =~ $ipv6_regex ]]; then
    return 0 # Valid
  else
    return 1 # Invalid
  fi
}


# --- Function to ensure 'trust' command symlink exists ---
# This function is now removed as per user request.
# ensure_trust_command_available() {
#   echo -e "${CYAN}Checking 'trust' command symlink status...${RESET}"
#
#   local symlink_ok=false
#   local current_symlink_target=$(readlink "$TRUST_COMMAND_PATH" 2>/dev/null)
#
#   if [[ "$current_symlink_target" == /dev/fd/* ]]; then
#     print_error "❌ Warning: The existing 'trust' symlink points to a temporary location ($current_symlink_target)."
#     print_error "   This can happen if the script was run in a non-standard way (e.g., piped to bash)."
#     print_error "   Attempting to fix it by recreating the symlink to the permanent script path."
#   fi
#
#   sudo mkdir -p "$(dirname "$TRUST_COMMAND_PATH")"
#   if sudo ln -sf "$TRUST_SCRIPT_PATH" "$TRUST_COMMAND_PATH"; then
#     print_success "Attempted to create/update 'trust' command symlink."
#     if [ -L "$TRUST_COMMAND_PATH" ] && [ "$(readlink "$TRUST_COMMAND_PATH" 2>/dev/null)" = "$TRUST_SCRIPT_PATH" ]; then
#       symlink_ok=true
#     Fİ
#   else
#     print_error "Failed to create/update 'trust' command symlink initially. Check permissions."
#   fi
#
#   if [ "$symlink_ok" = true ]; then
#     print_success "'trust' command symlink is correctly set up."
#     return 0
#   else
#     print_error "❌ Critical Error: The 'trust' command symlink is not properly set up or accessible."
#     print_error "   This means the 'trust' command will not work."
#     print_error "   Please try the following manual steps to fix it:"
#     echo -e "${WHITE}   1. Ensure you are running this script directly from its file path (e.g., 'sudo bash /path/to/your_script.sh')."
#     echo -e "${WHITE}   2. Run: sudo ln -sf \"$TRUST_SCRIPT_PATH\" \"$TRUST_COMMAND_PATH\"${RESET}"
#     echo -e "${WHITE}   3. Check your PATH: echo \$PATH${RESET}"
#     echo -e "${WHITE}      Ensure '/usr/local/bin' is in your PATH. If not, add it to your shell's config (e.g., ~/.bashrc, ~/.zshrc):${RESET}"
#     echo -e "${WHITE}      export PATH=\"/usr/local/bin:\$PATH\"${RESET}"
#     echo -e "${WHITE}   4. After making changes, restart your terminal or run: source ~/.bashrc (or your shell's config file)${RESET}"
#     sleep 5
#     return 1
#   fi
# }


# --- New: reset_timer function to schedule service restart via cron ---
reset_timer() {
  local service_to_restart="$1" # Optional: service name passed as argument

  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}     ⏰ Schedule Service Restart${RESET}" # Schedule Service Restart
  draw_line "$CYAN" "=" 40
  echo ""

  # If service_to_restart is not provided as an argument, prompt the user
  if [[ -z "$service_to_restart" ]]; then
    echo -e "👉 ${WHITE}Which service do you want to restart (e.g., 'nginx', 'apache2', 'trusttunnel')? ${RESET}" # Which service do you want to restart
    read -p "" service_to_restart
    echo ""
  fi

  if [[ -z "$service_to_restart" ]]; then
    print_error "Service name cannot be empty. Aborting scheduling." # Service name cannot be empty. Aborting scheduling.
    echo ""
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
    read -p ""
    return 1 # Indicate failure
  fi

  # --- New Validation: Check if the service exists by checking for its .service file ---
  if [ ! -f "/etc/systemd/system/${service_to_restart}.service" ]; then
    print_error "Service '$service_to_restart' does not exist on this system. Cannot schedule restart." # Service 'service_to_restart' does not exist on this system. Cannot schedule restart.
    echo ""
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
    read -p ""
    return 1 # Indicate failure
  fi
  # --- End New Validation ---


  echo -e "${CYAN}Scheduling restart for service: ${WHITE}$service_to_restart${RESET}" # Scheduling restart for service:
  echo ""
  echo "Please select a time interval for the service to restart RECURRINGLY:" # Please select a time interval for the service to restart RECURRINGLY:
  echo -e "  ${YELLOW}1)${RESET} ${WHITE}Every 30 minutes${RESET}"
  echo -e "  ${YELLOW}2)${RESET} ${WHITE}Every 1 hour${RESET}"
  echo -e "  ${YELLOW}3)${RESET} ${WHITE}Every 2 hours${RESET}"
  echo -e "  ${YELLOW}4)${RESET} ${WHITE}Every 4 hours${RESET}"
  echo -e "  ${YELLOW}5)${RESET} ${WHITE}Every 6 hours${RESET}"
  echo -e "  ${YELLOW}6)${RESET} ${WHITE}Every 12 hours${RESET}"
  echo -e "  ${YELLOW}7)${RESET} ${WHITE}Every 24 hours${RESET}"
  echo ""
  read -p "👉 Enter your choice (1-7): " choice # Enter your choice (1-7):
  echo ""

  local cron_minute=""
  local cron_hour=""
  local cron_day_of_month="*"
  local cron_month="*"
  local cron_day_of_week="*"
  local description=""

  case "$choice" in
    1)
      cron_minute="*/30"
      cron_hour="*"
      description="every 30 minutes"
      ;;
    2)
      cron_minute="0"
      cron_hour="*/1" # or simply "*"
      description="every 1 hour"
      ;;
    3)
      cron_minute="0"
      cron_hour="*/2"
      description="every 2 hours"
      ;;
    4)
      cron_minute="0"
      cron_hour="*/4"
      description="every 4 hours"
      ;;
    5)
      cron_minute="0"
      cron_hour="*/6"
      description="every 6 hours"
      ;;
    6)
      cron_minute="0"
      cron_hour="*/12"
      description="every 12 hours"
      ;;
    7)
      cron_minute="0"
      cron_hour="0" # At midnight every day
      description="every 24 hours (daily at midnight)"
      ;;
    *)
      echo -e "${RED}❌ Invalid choice. No cron job will be scheduled.${RESET}" # Invalid choice. No cron job will be scheduled.
      echo ""
      echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
      read -p ""
      return 1 # Indicate failure
      ;;
  esac

  echo -e "${CYAN}Scheduling '$service_to_restart' to restart $description...${RESET}" # Scheduling restart for service:
  echo ""
  
  # Define the cron command
  # Using an absolute path for systemctl is good practice in cron jobs
  local cron_command="/usr/bin/systemctl restart $service_to_restart >> /var/log/trusttunnel_cron.log 2>&1"
  local cron_job_entry="$cron_minute $cron_hour $cron_day_of_month $cron_month $cron_day_of_week $cron_command # TrustTunnel automated restart for $service_to_restart"

  # --- Start of improved cron job management ---
  local temp_cron_file=$(mktemp)
  if ! sudo crontab -l &> /dev/null; then
      # If crontab is empty or doesn't exist, create an empty one
      echo "" | sudo crontab -
  fi
  sudo crontab -l > "$temp_cron_file"

  # Remove any existing TrustTunnel cron job for this service
  sed -i "/# TrustTunnel automated restart for $service_to_restart$/d" "$temp_cron_file"

  # Add the new cron job entry
  echo "$cron_job_entry" >> "$temp_cron_file"

  # Load the modified crontab
  if sudo crontab "$temp_cron_file"; then
    print_success "Successfully scheduled a restart for '$service_to_restart' $description." # Successfully scheduled a restart for 'service_to_restart' in description.
    echo -e "${CYAN}   The cron job entry looks like this:${RESET}" # The cron job entry looks like this:
    echo -e "${WHITE}   $cron_job_entry${RESET}"
    echo -e "${CYAN}   You can check scheduled cron jobs with: ${WHITE}sudo crontab -l${RESET}" # You can check scheduled cron jobs with: sudo crontab -l
    echo -e "${CYAN}   Logs will be written to: ${WHITE}/var/log/trusttunnel_cron.log${RESET}" # Logs will be written to: /var/log/trusttunnel_cron.log
  else
    print_error "Failed to schedule the cron job. Check permissions or cron service status.${RESET}" # Failed to schedule the cron job. Check permissions or cron service status.
  fi

  # Clean up the temporary file
  rm -f "$temp_cron_file"
  # --- End of improved cron job management ---

  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
  read -p ""
}

# --- New: delete_cron_job_action to remove scheduled restarts ---
delete_cron_job_action() {
  clear
  echo ""
  draw_line "$RED" "=" 40
  echo -e "${RED}     🗑️ Delete Scheduled Restart (Cron)${RESET}" # Delete Scheduled Restart (Cron)
  draw_line "$RED" "=" 40
  echo ""

  echo -e "${CYAN}🔍 Searching for TrustTunnel related services with scheduled restarts...${RESET}" # Searching for TrustTunnel related services with scheduled restarts...

  # List active TrustTunnel related services (both server and clients)
  mapfile -t services_with_cron < <(sudo crontab -l 2>/dev/null | grep "# TrustTunnel automated restart for" | awk '{print $NF}' | sort -u)

  # Extract service names from the cron job comments
  local service_names=()
  for service_comment in "${services_with_cron[@]}"; do
    # The service name is the last word in the comment, which is the service name itself
    # We need to strip the "# TrustTunnel automated restart for " part
    local extracted_name=$(echo "$service_comment" | sed 's/# TrustTunnel automated restart for //')
    service_names+=("$extracted_name")
  done

  if [ ${#service_names[@]} -eq 0 ]; then
    print_error "No TrustTunnel services with scheduled cron jobs found." # No TrustTunnel services with scheduled cron jobs found.
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
    read -p ""
    return 1
  fi

  echo -e "${CYAN}📋 Please select a service to delete its scheduled restart:${RESET}" # Please select a service to delete its scheduled restart:
  # Add a "Back to previous menu" option
  service_names+=("Back to previous menu")
  select selected_service_name in "${service_names[@]}"; do
    if [[ "$selected_service_name" == "Back to previous menu" ]]; then
      echo -e "${YELLOW}Returning to previous menu...${RESET}" # Returning to previous menu...
      echo ""
      return 0
    elif [ -n "$selected_service_name" ]; then
      break # Exit the select loop if a valid option is chosen
    else
      print_error "Invalid selection. Please enter a valid number." # Invalid selection. Please enter a valid number.
    fi
  done
  echo ""

  if [[ -z "$selected_service_name" ]]; then
    print_error "No service selected. Aborting." # No service selected. Aborting.
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
    read -p ""
    return 1
  fi

  echo -e "${CYAN}Attempting to delete cron job for '$selected_service_name'...${RESET}" # Attempting to delete cron job for 'selected_service_name'...

  # --- Start of improved cron job management for deletion ---
  local temp_cron_file=$(mktemp)
  if ! sudo crontab -l &> /dev/null; then
      # If crontab is empty or doesn't exist, nothing to delete
      print_error "Crontab is empty or not accessible. Nothing to delete." # Crontab is empty or not accessible. Nothing to delete.
      rm -f "$temp_cron_file"
      echo ""
      echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
      read -p ""
      return 1
  fi
  sudo crontab -l > "$temp_cron_file"

  # Remove the cron job for the selected service using the unique identifier
  sed -i "/# TrustTunnel automated restart for $selected_service_name$/d" "$temp_cron_file"

  # Load the modified crontab
  if sudo crontab "$temp_cron_file"; then
    print_success "Successfully removed scheduled restart for '$selected_service_name'." # Successfully removed scheduled restart for 'selected_service_name'.
    echo -e "${WHITE}You can verify with: ${YELLOW}sudo crontab -l${RESET}" # You can verify with: sudo crontab -l
  else
    print_error "Failed to delete cron job. It might not exist or there's a permission issue.${RESET}" # Failed to delete cron job. It might not exist or there's a permission issue.
  fi

  # Clean up the temporary file
  rm -f "$temp_cron_file"
  # --- End of improved cron job management ---

  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
  read -p ""
}

# --- Uninstall TrustTunnel Action ---
uninstall_trusttunnel_action() {
  clear
  echo ""
  echo -e "${RED}⚠️ Are you sure you want to uninstall TrustTunnel and remove all associated files and services? (y/N): ${RESET}" # Are you sure you want to uninstall TrustTunnel and remove all associated files and services? (y/N):
  read -p "" confirm
  echo ""

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "🧹 Uninstalling TrustTunnel..." # Uninstalling TrustTunnel...

    # --- Explicitly handle trusttunnel.service (server) ---
    local server_service_name="trusttunnel.service"
    if systemctl list-unit-files --full --no-pager | grep -q "^$server_service_name"; then
      echo "🛑 Stopping and disabling TrustTunnel server service ($server_service_name)..." # Stopping and disabling TrustTunnel server service (server_service_name)...
      sudo systemctl stop "$server_service_name" > /dev/null 2>&1
      sudo systemctl disable "$server_service_name" > /dev/null 2>&1
      sudo rm -f "/etc/systemd/system/$server_service_name" > /dev/null 2>&1
      print_success "TrustTunnel server service removed." # TrustTunnel server service removed.
    else
      echo "⚠️ TrustTunnel server service ($server_service_name) not found. Skipping." # TrustTunnel server service (server_service_name) not found. Skipping.
    fi

    # Find and remove all trusttunnel-* services (clients)
    echo "Searching for TrustTunnel client services to remove..." # Searching for TrustTunnel client services to remove...
    # List all unit files that start with 'trusttunnel-'
    mapfile -t trusttunnel_client_services < <(sudo systemctl list-unit-files --full --no-pager | grep '^trusttunnel-.*\.service' | awk '{print $1}')

    if [ ${#trusttunnel_client_services[@]} -gt 0 ]; then
      echo "🛑 Stopping and disabling TrustTunnel client services..." # Stopping and disabling TrustTunnel client services...
      for service_file in "${trusttunnel_client_services[@]}"; do
        local service_name=$(basename "$service_file") # Get just the service name from the file path
        echo "  - Processing $service_name..." # Processing service_name...
        sudo systemctl stop "$service_name" > /dev/null 2>&1
        sudo systemctl disable "$service_name" > /dev/null 2>&1
        sudo rm -f "/etc/systemd/system/$service_name" > /dev/null 2>&1
      done
      print_success "All TrustTunnel client services have been stopped, disabled, and removed." # All TrustTunnel client services have been stopped, disabled, and removed.
    else
      echo "⚠️ No TrustTunnel client services found to remove." # No TrustTunnel client services found to remove.
    fi

    sudo systemctl daemon-reload # Reload daemon after removing services

    # Remove rstun folder if exists
    if [ -d "rstun" ]; then
      echo "🗑️ Removing 'rstun' folder..." # Removing 'rstun' folder...
      rm -rf rstun
      print_success "'rstun' folder removed successfully." # 'rstun' folder removed successfully.
    else
      echo "⚠️ 'rstun' folder not found." # 'rstun' folder not found.
    fi

    # Remove TrustTunnel related cron jobs
    echo -e "${CYAN}🧹 Removing any associated TrustTunnel cron jobs...${RESET}" # Removing any associated TrustTunnel cron jobs...
    (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart for") | sudo crontab -
    print_success "Associated cron jobs removed." # Associated cron jobs removed.

    # Remove 'trust' command symlink (if it was ever created, though it shouldn't be now)
    if [ -L "$TRUST_COMMAND_PATH" ]; then # Check if it's a symbolic link
      echo "🗑️ Removing 'trust' command symlink..." # Removing 'trust' command symlink...
      sudo rm -f "$TRUST_COMMAND_PATH"
      print_success "'trust' command symlink removed." # 'trust' command symlink removed.
    fi
    # Remove setup marker file
    if [ -f "$SETUP_MARKER_FILE" ]; then
      echo "🗑️ Removing setup marker file..." # Removing setup marker file...
      sudo rm -f "$SETUP_MARKER_FILE"
      print_success "Setup marker file removed." # Setup marker file removed.
    fi

    print_success "TrustTunnel uninstallation complete." # TrustTunnel uninstallation complete.
  else
    echo -e "${YELLOW}❌ Uninstall cancelled.${RESET}" # Uninstall cancelled.
  fi
  echo ""
  echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
  read -p ""
}

# --- Install TrustTunnel Action ---
install_trusttunnel_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}     📥 Installing TrustTunnel${RESET}" # Installing TrustTunnel
  draw_line "$CYAN" "=" 40
  echo ""

  # Delete existing rstun folder if it exists
  if [ -d "rstun" ]; then
    echo -e "${YELLOW}🧹 Removing existing 'rstun' folder...${RESET}" # Removing existing 'rstun' folder...
    rm -rf rstun
    print_success "Existing 'rstun' folder removed." # Existing 'rstun' folder removed.
  fi

  echo -e "${CYAN}🚀 Detecting system architecture...${RESET}" # Detecting system architecture...
  local arch=$(uname -m)
  local download_url=""
  local filename=""
  local supported_arch=true # Flag to track if architecture is directly supported

  case "$arch" in
    "x86_64")
      filename="rstun-linux-x86_64.tar.gz"
      ;;
    "aarch64" | "arm64")
      filename="rstun-linux-aarch64.tar.gz"
      ;;
    "armv7l") # Corrected filename for armv7l
      filename="rstun-linux-armv7.tar.gz"
      ;;
    *)
      supported_arch=false # Mark as unsupported
      echo -e "${RED}❌ Error: Unsupported architecture detected: $arch${RESET}" # Error: Unsupported architecture detected: arch
      echo -e "${YELLOW}Do you want to try installing the x86_64 version as a fallback? (y/N): ${RESET}" # Do you want to try installing the x86_64 version as a fallback? (y/N):
      read -p "" fallback_confirm
      echo ""
      if [[ "$fallback_confirm" =~ ^[Yy]$ ]]; then
        filename="rstun-linux-x86_64.tar.gz"
        echo -e "${CYAN}Proceeding with x86_64 version as requested.${RESET}" # Proceeding with x86_64 version as requested.
      else
        echo -e "${YELLOW}Installation cancelled. Please download rstun manually for your system from https://github.com/neevek/rstun/releases${RESET}" # Installation cancelled. Please download rstun manually for your system from https://github.com/neevek/rstun/releases
        echo ""
        echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
        read -p ""
        return 1 # Indicate failure
      fi
      ;;
  esac

  download_url="https://github.com/neevek/rstun/releases/download/v0.7.4/${filename}"

  echo -e "${CYAN}Downloading $filename for $arch...${RESET}" # Downloading filename for arch...
  if wget -q --show-progress "$download_url" -O "$filename"; then
    print_success "Download complete!" # Download complete!
  else
    echo -e "${RED}❌ Error: Failed to download $filename. Please check your internet connection or the URL.${RESET}" # Error: Failed to download filename. Please check your internet connection or the URL.
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
    read -p ""
    return 1 # Indicate failure
  fi

  echo -e "${CYAN}📦 Extracting files...${RESET}" # Extracting files...
  if tar -xzf "$filename"; then
    mv "${filename%.tar.gz}" rstun # Rename extracted folder to 'rstun'
    print_success "Extraction complete!" # Extraction complete!
  else
    echo -e "${RED}❌ Error: Failed to extract $filename. Corrupted download?${RESET}" # Error: Failed to extract filename. Corrupted download?
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
    read -p ""
    return 1 # Indicate failure
  fi

  echo -e "${CYAN}➕ Setting execute permissions...${RESET}" # Setting execute permissions...
  find rstun -type f -exec chmod +x {} \;
  print_success "Permissions set." # Permissions set.

  echo -e "${CYAN}🗑️ Cleaning up downloaded archive...${RESET}" # Cleaning up downloaded archive...
  rm "$filename"
  print_success "Cleanup complete." # Cleanup complete.

  echo ""
  print_success "TrustTunnel installation complete!" # TrustTunnel installation complete!
  # ensure_trust_command_available # Removed as per user request
  echo ""
  echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
  read -p ""
}

# --- Add New Server Action (Beautified) ---
add_new_server_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}     ➕ Add New TrustTunnel Server${RESET}" # Add New TrustTunnel Server
  draw_line "$CYAN" "=" 40
  echo ""

  if [ ! -f "rstun/rstund" ]; then
    echo -e "${RED}❗ Server build (rstun/rstund) not found.${RESET}" # Server build (rstun/rstund) not found.
    echo -e "${YELLOW}Please run 'Install TrustTunnel' option from the main menu first.${RESET}" # Please run 'Install TrustTunnel' option from the main menu first.
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
    read -p ""
    return # Use return instead of continue in a function
  fi

  local tls_enabled="true" # Default to true (recommended)
  echo -e "${CYAN}🔒 TLS/SSL Mode Configuration:${RESET}"
  echo -e "  (It's highly recommended to enable TLS for secure communication.)"
  echo -e "👉 ${WHITE}Do you want to enable TLS/SSL for this server? (Y/n, default: Y):${RESET} "
  read -p "" tls_choice_input
  tls_choice_input=${tls_choice_input:-Y} # Default to Y if empty

  if [[ "$tls_choice_input" =~ ^[Nn]$ ]]; then
    tls_enabled="false"
    print_error "TLS/SSL is disabled. Communication will not be encrypted."
    echo ""
    echo -e "${YELLOW}Press Enter to continue without TLS...${RESET}"
    read -p ""
  else
    print_success "TLS/SSL is enabled. Proceeding with certificate configuration."
    echo ""
  fi

  local cert_path=""
  local cert_args=""

  if [[ "$tls_enabled" == "true" ]]; then
    # لیست کردن certificate های موجود
    local certs_dir="/etc/letsencrypt/live"
    if [ ! -d "$certs_dir" ]; then
      echo -e "${RED}❌ No certificates directory found at $certs_dir.${RESET}"
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi

    # Find directories under /etc/letsencrypt/live/ that are not 'README'
    # and get their base names (which are the domain names)
    mapfile -t cert_domains < <(sudo find "$certs_dir" -maxdepth 1 -mindepth 1 -type d ! -name "README" -exec basename {} \;)

    if [ ${#cert_domains[@]} -eq 0 ]; then
      echo -e "${RED}❌ No SSL certificates found.${RESET}"
      echo -e "${YELLOW}Please create one from the 'Certificate management' menu first.${RESET}"
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi

    echo -e "${CYAN}Available SSL Certificates:${RESET}"
    for i in "${!cert_domains[@]}"; do
      echo -e "  ${YELLOW}$((i+1)))${RESET} ${WHITE}${cert_domains[$i]}${RESET}"
    done

    local cert_choice
    while true; do
      echo -e "👉 ${WHITE}Select a certificate by number:${RESET} "
      read -p "" cert_choice
      if [[ "$cert_choice" =~ ^[0-9]+$ ]] && [ "$cert_choice" -ge 1 ] && [ "$cert_choice" -le ${#cert_domains[@]} ]; then
        break
      else
        print_error "Invalid selection. Please enter a valid number."
      fi
    done
    local selected_domain_name="${cert_domains[$((cert_choice-1))]}"
    cert_path="$certs_dir/$selected_domain_name"
    echo -e "${GREEN}Selected certificate: $selected_domain_name (Path: $cert_path)${RESET}"
    echo ""

    if [ ! -d "$cert_path" ]; then
      echo -e "${RED}❌ SSL certificate not available. Server setup aborted.${RESET}"
      echo ""
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi
    cert_args="--cert \"$cert_path/fullchain.pem\" --key \"$cert_path/privkey.pem\""
  else
    echo -e "${YELLOW}Skipping SSL certificate selection as TLS is disabled.${RESET}"
    echo ""
  fi

  echo -e "${CYAN}⚙️ Server Configuration:${RESET}" # Server Configuration:
  echo -e "  (Default tunneling address port is 6060)"
  
  # Validate Listen Port
  local listen_port
  while true; do
    echo -e "👉 ${WHITE}Enter tunneling address port (1-65535, default 6060):${RESET} " # Enter tunneling address port (1-65535, default 6060):
    read -p "" listen_port_input
    listen_port=${listen_port_input:-6060} # Apply default if empty
    if validate_port "$listen_port"; then
      break
    else
      print_error "❌ Invalid port number. Port must be between 1 and 65535."
    fi
  done

  echo -e "  (Default TCP upstream port is 8800)"
  # Validate TCP Upstream Port
  local tcp_upstream_port
  while true; do
    echo -e "👉 ${WHITE}Enter TCP upstream port (1-65535, default 8800):${RESET} " # Enter TCP upstream port (1-65535, default 8800):
    read -p "" tcp_upstream_port_input
    tcp_upstream_port=${tcp_upstream_port_input:-8800} # Apply default if empty
    if validate_port "$tcp_upstream_port"; then
      break
    else
      print_error "❌ Invalid port number. Port must be between 1 and 65535."
    fi
  done

  echo -e "  (Default UDP upstream port is 8800)"
  # Validate UDP Upstream Port
  local udp_upstream_port
  while true; do
    echo -e "👉 ${WHITE}Enter UDP upstream port (1-65535, default 8800):${RESET} " # Enter UDP upstream port (1-65535, default 8800):
    read -p "" udp_upstream_port_input
    udp_upstream_port=${udp_upstream_port_input:-8800} # Apply default if empty
    if validate_port "$udp_upstream_port"; then
      break
    else
      print_error "❌ Invalid port number. Port must be between 1 and 65535."
    fi
  done

  echo -e "👉 ${WHITE}Enter password:${RESET} " # Enter password:
  read -p "" password
  echo ""

  if [[ -z "$password" ]]; then
    echo -e "${RED}❌ Password cannot be empty!${RESET}" # Password cannot be empty!
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
    read -p ""
    return # Use return instead of exit 1
  fi

  local service_file="/etc/systemd/system/trusttunnel.service"

  if systemctl is-active --quiet trusttunnel.service || systemctl is-enabled --quiet trusttunnel.service; then
    echo -e "${YELLOW}🛑 Stopping existing Trusttunnel service...${RESET}" # Stopping existing Trusttunnel service...
    sudo systemctl stop trusttunnel.service > /dev/null 2>&1
    echo -e "${YELLOW}🗑️ Disabling and removing existing Trusttunnel service...${RESET}" # Disabling and removing existing Trusttunnel service...
    sudo systemctl disable trusttunnel.service > /dev/null 2>&1
    sudo rm -f /etc/systemd/system/trusttunnel.service > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
    print_success "Existing TrustTunnel service removed." # TrustTunnel service removed.
  fi

  cat <<EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=TrustTunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$(pwd)/rstun/rstund --addr 0.0.0.0:$listen_port --tcp-upstream $tcp_upstream_port --udp-upstream $udp_upstream_port --password "$password" $cert_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000
Restart=always
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

  # Verify service file was created
  if [ ! -f "$service_file" ]; then
    print_error "❌ Failed to create service file at $service_file"
    echo -e "${YELLOW}Check permissions and try again${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
    read -p ""
    return 1
  else
    echo -e "${GREEN}✅ Service file created at $service_file${RESET}"
  fi

  echo -e "${CYAN}🔧 Reloading systemd daemon...${RESET}" # Reloading systemd daemon...
  sudo systemctl daemon-reload

  echo -e "${CYAN}🚀 Enabling and starting Trusttunnel service...${RESET}" # Enabling and starting Trusttunnel service...

  # Enable the service
  if sudo systemctl enable trusttunnel.service > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service enabled successfully${RESET}"
  else
    print_error "Failed to enable the service"
  fi

  # Start the service and check if it started successfully
  if sudo systemctl start trusttunnel.service > /dev/null 2>&1; then
    # Check if service is actually running
    if systemctl is-active --quiet trusttunnel.service; then
      print_success "✅ TrustTunnel server started successfully!"
      echo -e "${CYAN}📋 Service Details:${RESET}"
      echo -e "   ${WHITE}Service: trusttunnel.service${RESET}"
      echo -e "   ${WHITE}Status: $(systemctl is-active trusttunnel.service)${RESET}"
      echo -e "   ${WHITE}Listen Port: $listen_port${RESET}"
      echo -e "   ${WHITE}TCP Upstream: $tcp_upstream_port${RESET}"
      echo -e "   ${WHITE}UDP Upstream: $udp_upstream_port${RESET}"
      if [[ "$tls_enabled" == "true" ]]; then
        echo -e "   ${WHITE}TLS: Enabled (Domain: $selected_domain_name)${RESET}"
      else
        echo -e "   ${WHITE}TLS: Disabled${RESET}"
      fi
    else
      print_error "❌ Service failed to start. Checking status..."
      echo -e "${YELLOW}Service Status: $(systemctl is-active trusttunnel.service)${RESET}"
      echo -e "${YELLOW}Run 'sudo systemctl status trusttunnel.service' for more details${RESET}"
    fi
  else
    print_error "❌ Failed to start the service"
    echo -e "${YELLOW}Check service file: /etc/systemd/system/trusttunnel.service${RESET}"
    echo -e "${YELLOW}Run 'sudo systemctl status trusttunnel.service' for error details${RESET}"
  fi

  echo ""
  echo -e "${YELLOW}Do you want to view the logs for trusttunnel.service now? (y/N): ${RESET}" # Do you want to view the logs for trusttunnel.service now? (y/N):
  read -p "" view_logs_choice
  echo ""

  if [[ "$view_logs_choice" =~ ^[Yy]$ ]]; then
    show_service_logs trusttunnel.service
  fi

  echo ""
  
  echo -e "${YELLOW}Press Enter to return to main menu...${RESET}" # Press Enter to return to main menu...
  read -p ""
}

add_new_client_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 50
  echo -e "${BOLD_GREEN}     ➕ Add New Reverse Tunnel Client${RESET}"
  draw_line "$CYAN" "=" 50
  echo ""
  echo -e "${WHITE}Create a new reverse tunnel client connection${RESET}"
  echo ""

  # Prompt for the client name (e.g., asiatech, respina, server2)
  echo -e "${CYAN}📛 Client Configuration:${RESET}"
  echo -e "${WHITE}Choose a unique name for this client (used for service identification)${RESET}"
  echo -e "${YELLOW}Examples: asiatech, respina, server2, home-server, office-vpn${RESET}"
  echo ""
  read -p "👉 Enter client name: " client_name
  echo ""

  # Construct the service name based on the client name
  service_name="trusttunnel-$client_name"
  # Define the path for the systemd service file
  service_file="/etc/systemd/system/${service_name}.service"

  # Check if a service with the given name already exists
  if [ -f "$service_file" ]; then
    echo -e "${RED}❌ Error: A client with the name '$client_name' already exists.${RESET}"
    echo -e "${YELLOW}💡 Choose a different name or delete the existing client first.${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
    return # Return to menu
  fi

  echo -e "${CYAN}🌐 Server Connection Details:${RESET}"
  echo -e "${WHITE}Specify the reverse tunnel server this client should connect to${RESET}"
  echo -e "${YELLOW}Format: hostname:port or IP:port${RESET}"
  echo -e "${YELLOW}Examples: server.yourdomain.com:6060, 192.168.1.100:6060${RESET}"
  echo ""

  # Validate Server Address
  local server_addr
  while true; do
    read -p "👉 Enter server address and port: " server_addr_input
    # Split into host and port for validation
    local host_part=$(echo "$server_addr_input" | cut -d':' -f1)
    local port_part=$(echo "$server_addr_input" | cut -d':' -f2)

    if validate_host "$host_part" && validate_port "$port_part"; then
      server_addr="$server_addr_input"
      break
    else
      print_error "❌ Invalid server address format. Use 'hostname:port' or 'IP:port' (e.g., server.example.com:6060)."
    fi
  done
  echo ""

  echo -e "${CYAN}📡 Tunnel Protocol Configuration:${RESET}"
  echo -e "${WHITE}Choose which network protocols to tunnel through this connection${RESET}"
  echo -e "${YELLOW}Options: tcp (web/HTTP), udp (games/DNS), both (recommended)${RESET}"
  echo ""
  read -p "👉 Select tunnel mode (tcp/udp/both): " tunnel_mode
  echo ""

  echo -e "${CYAN}🔐 Security Configuration:${RESET}"
  echo -e "${WHITE}Enter the password that matches your tunnel server${RESET}"
  echo -e "${YELLOW}This must be identical to the server password${RESET}"
  echo ""
  read -p "👉 Enter connection password: " password
  echo ""

  echo -e "${CYAN}🔢 Port Mapping Configuration:${RESET}"
  echo -e "${WHITE}Specify which local ports to tunnel to the remote server${RESET}"
  echo -e "${YELLOW}Each port will be accessible from the server side${RESET}"
  echo ""

  local port_count
  while true; do
    read -p "👉 How many ports to tunnel? " port_count_input
    if [[ "$port_count_input" =~ ^[0-9]+$ ]] && (( port_count_input >= 0 )); then
      port_count=$port_count_input
      break
    else
      print_error "❌ Invalid input. Please enter 0 or a positive number for the port count."
    fi
  done
  echo ""
  
  mappings=""
  for ((i=1; i<=port_count; i++)); do
    local port
    while true; do
      read -p "👉 Enter Port #$i (1-65535): " port_input
      if validate_port "$port_input"; then
        port="$port_input"
        break
      else
        print_error "❌ Invalid port number. Port must be between 1 and 65535."
      fi
    done
    mapping="IN^0.0.0.0:$port^0.0.0.0:$port"
    [ -z "$mappings" ] && mappings="$mapping" || mappings="$mappings,$mapping"
    echo ""
  done

  # Determine the mapping arguments based on the tunnel_mode
  mapping_args=""
  case "$tunnel_mode" in
    "tcp")
      mapping_args="--tcp-mappings \"$mappings\""
      ;;
    "udp")
      mapping_args="--udp-mappings \"$mappings\""
      ;;
    "both")
      mapping_args="--tcp-mappings \"$mappings\" --udp-mappings \"$mappings\""
      ;;
    *)
      echo -e "${YELLOW}⚠️ Invalid tunnel mode specified. Using 'both' as default.${RESET}" # Invalid tunnel mode specified. Using 'both' as default.
      mapping_args="--tcp-mappings \"$mappings\" --udp-mappings \"$mappings\""
      ;;
  esac

  # Create the systemd service file using a here-document
  cat <<EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=TrustTunnel Client - $client_name
After=network.target

[Service]
Type=simple
ExecStart=$(pwd)/rstun/rstunc --server-addr "$server_addr" --password "$password" $mapping_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000 --wait-before-retry-ms 3000
Restart=always
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

  echo -e "${CYAN}🔧 Reloading systemd daemon...${RESET}" # Reloading systemd daemon...
  sudo systemctl daemon-reload

  echo -e "${CYAN}🚀 Enabling and starting Trusttunnel client service...${RESET}" # Enabling and starting Trusttunnel client service...
  sudo systemctl enable "$service_name" > /dev/null 2>&1
  sudo systemctl start "$service_name" > /dev/null 2>&1

  print_success "✅ Reverse tunnel client '$client_name' has been created and started!"
  echo -e "${CYAN}📋 Service Details:${RESET}"
  echo -e "   ${WHITE}Service Name: $service_name${RESET}"
  echo -e "   ${WHITE}Connection: $server_addr${RESET}"
  echo -e "   ${WHITE}Protocol: $tunnel_mode${RESET}"
  echo -e "   ${WHITE}Ports: ${mappings//,/, }${RESET}"
  echo ""
  echo -e "${CYAN}🔍 Monitoring Options:${RESET}"
  read -p "👉 View client logs now? (y/N): " view_logs_choice
  echo ""

  if [[ "$view_logs_choice" =~ ^[Yy]$ ]]; then
    show_service_logs "$service_name"
  fi
  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
  read -p ""
}

# --- Initial Setup Function ---
# This function performs one-time setup tasks like installing dependencies
# and creating the 'trust' command symlink.
perform_initial_setup() {
  # Check if initial setup has already been performed
  if [ -f "$SETUP_MARKER_FILE" ]; then
    echo -e "${YELLOW}Initial setup already performed. Skipping prerequisites installation.${RESET}" # Updated message
    # ensure_trust_command_available # Removed as per user request
    return 0 # Exit successfully
  fi

  echo -e "${CYAN}Performing initial setup (installing dependencies)...${RESET}" # Performing initial setup (installing dependencies)...

  # Install required tools
  echo -e "${CYAN}Updating package lists and installing dependencies...${RESET}" # Updating package lists and installing dependencies...
  sudo apt update
  sudo apt install -y build-essential curl pkg-config libssl-dev git figlet certbot rustc cargo cron

  # Default path for the Cargo environment file.
  CARGO_ENV_FILE="$HOME/.cargo/env"

  echo "Checking for Rust installation..." # Checking for Rust installation...

  # Check if 'rustc' command is available in the system's PATH.
  if command -v rustc >/dev/null 2>&1; then
    # If 'rustc' is found, Rust is already installed.
    echo "✅ Rust is already installed: $(rustc --version)" # Rust is already installed: rustc --version
    RUST_IS_READY=true
  else
    # If 'rustc' is not found, start the installation.
    echo "🦀 Rust is not installed. Installing..." # Rust is not installed. Installing...
    RUST_IS_READY=false

    # Download and run the rustup installer.
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
      echo "✅ Rust installed successfully." # Rust installed successfully.

      # Source the Cargo environment file for the current script session.
      if [ -f "$CARGO_ENV_FILE" ]; then
        source "$CARGO_ENV_FILE"
        echo "♻️ Cargo environment file sourced for this script session." # Cargo environment file sourced for this script session.
      else
        # Fallback if the environment file is not found.
        echo "⚠️ Cargo environment file ($CARGO_ENV_FILE) not found. You might need to set PATH manually." # Cargo environment file (CARGO_ENV_FILE) not found. You might need to set PATH manually.
        export PATH="$HOME/.cargo/bin:$PATH"
      fi

      # Display the installed version for confirmation.
      if command -v rustc >/dev/null 2>&1; then
        echo "✅ Installed Rust version: $(rustc --version)" # Installed Rust version: rustc --version
        RUST_IS_READY=true
      else
        echo "❌ Rust is installed but 'rustc' is not available in the current PATH." # Rust is installed but 'rustc' is not available in the current PATH.
      fi

      echo ""
      echo "------------------------------------------------------------------"
      echo "⚠️ Important: To make Rust available in your terminal," # Important: To make Rust available in your terminal,
      echo "    you need to restart your terminal or run this command:" # you need to restart your terminal or run this command:
      echo "    source \"$CARGO_ENV_FILE\""
      echo "    Run this command once in each new terminal session." # Run this command once in each new terminal session.
      echo "------------------------------------------------------------------"

    else
      # Error message if installation fails.
      echo "❌ An error occurred during Rust installation. Please check your internet connection or try again." # An error occurred during Rust installation. Please check your internet connection or try again.
      return 1 # Indicate failure
    fi
  fi

  # ensure_trust_command_available # Removed as per user request
  if [ "$RUST_IS_READY" = true ]; then
    sudo mkdir -p "$(dirname "$SETUP_MARKER_FILE")" # Ensure directory exists for marker file
    sudo touch "$SETUP_MARKER_FILE" # Create marker file only if all initial setup steps (excluding symlink) succeed
    print_success "Initial setup complete." # Initial setup complete.
    return 0
  else
    print_error "Rust is not ready. Skipping setup marker." # Rust is not ready. Skipping setup marker.
    return 1 # Indicate failure
  fi
  echo ""
  return 0
}


# --- Add New Direct Server Action ---
add_new_direct_server_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}        ➕ Add New Direct Server${RESET}"
  draw_line "$CYAN" "=" 40
  echo ""
  
  if [ ! -f "rstun/rstund" ]; then
    echo -e "${RED}❗ Server build (rstun/rstund) not found.${RESET}"
    echo -e "${YELLOW}Please run 'Install TrustTunnel' option from the main menu first.${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
    read -p ""
    return
  fi

  local tls_enabled="true" # Default to true (recommended)
  echo -e "${CYAN}🔒 TLS/SSL Mode Configuration:${RESET}"
  echo -e "  (It's highly recommended to enable TLS for secure communication.)"
  echo -e "👉 ${WHITE}Do you want to enable TLS/SSL for this server? (Y/n, default: Y):${RESET} "
  read -p "" tls_choice_input
  tls_choice_input=${tls_choice_input:-Y} # Default to Y if empty

  if [[ "$tls_choice_input" =~ ^[Nn]$ ]]; then
    tls_enabled="false"
    print_error "TLS/SSL is disabled. Communication will not be encrypted."
    echo ""
    echo -e "${YELLOW}Press Enter to continue without TLS...${RESET}"
    read -p ""
  else
    print_success "TLS/SSL is enabled. Proceeding with certificate configuration."
    echo ""
  fi

  local cert_path=""
  local cert_args=""

  if [[ "$tls_enabled" == "true" ]]; then
    # لیست کردن certificate های موجود
    local certs_dir="/etc/letsencrypt/live"
    if [ ! -d "$certs_dir" ]; then
      echo -e "${RED}❌ No certificates directory found at $certs_dir.${RESET}"
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi

    mapfile -t cert_domains < <(sudo find "$certs_dir" -maxdepth 1 -mindepth 1 -type d ! -name "README" -exec basename {} \;)

    if [ ${#cert_domains[@]} -eq 0 ]; then
      echo -e "${RED}❌ No SSL certificates found.${RESET}"
      echo -e "${YELLOW}Please create one from the 'Certificate management' menu first.${RESET}"
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi

    echo -e "${CYAN}Available SSL Certificates:${RESET}"
    for i in "${!cert_domains[@]}"; do
      echo -e "  ${YELLOW}$((i+1)))${RESET} ${WHITE}${cert_domains[$i]}${RESET}"
    done

    local cert_choice
    while true; do
      echo -e "👉 ${WHITE}Select a certificate by number:${RESET} "
      read -p "" cert_choice
      if [[ "$cert_choice" =~ ^[0-9]+$ ]] && [ "$cert_choice" -ge 1 ] && [ "$cert_choice" -le ${#cert_domains[@]} ]; then
        break
      else
        print_error "Invalid selection. Please enter a valid number."
      fi
    done
    local selected_domain_name="${cert_domains[$((cert_choice-1))]}"
    cert_path="$certs_dir/$selected_domain_name"
    echo -e "${GREEN}Selected certificate: $selected_domain_name (Path: $cert_path)${RESET}"
    echo ""

    if [ ! -d "$cert_path" ]; then
      echo -e "${RED}❌ SSL certificate not available. Server setup aborted.${RESET}"
      echo ""
      echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
      read -p ""
      return
    fi
    cert_args="--cert \"$cert_path/fullchain.pem\" --key \"$cert_path/privkey.pem\""
  else
    echo -e "${YELLOW}Skipping SSL certificate selection as TLS is disabled.${RESET}"
    echo ""
  fi

  echo -e "${CYAN}⚙️ Server Configuration:${RESET}"
  # Prompt for IPv6 usage
  local use_ipv6_input
  local server_listen_addr="0.0.0.0" # Default to IPv4
  echo -e "👉 ${WHITE}Do you want to use IPv6 for the server address? (Y/n, default: N):${RESET} "
  read -p "" use_ipv6_input
  use_ipv6_input=${use_ipv6_input:-N} # Default to N if empty

  if [[ "$use_ipv6_input" =~ ^[Yy]$ ]]; then
    server_listen_addr="[::]"
    print_success "Server will listen on IPv6 (and potentially IPv4 via mapped addresses)."
  else
    print_success "Server will listen on IPv4 only."
  fi
  echo ""
    
  # Validate Listen Port
  local listen_port
  while true; do
    echo -e "  (Default listen port is 8800)"
    echo -e "👉 ${WHITE}Enter listen port (1-65535, default 8800):${RESET} "
    read -p "" listen_port_input
    listen_port=${listen_port_input:-8800}
    if validate_port "$listen_port"; then
      break
    else
      print_error "Invalid port number. Please enter a number between 1 and 65535."
    fi
  done
  echo -e "  (Default TCP upstream port is 2030)"
  # Validate TCP Upstream Port
  local tcp_upstream_port
  while true; do
    echo -e "👉 ${WHITE}Enter TCP upstream port (1-65535, default 2030):${RESET} " # Enter TCP upstream port (1-65535, default 8800):
    read -p "" tcp_upstream_port_input
    tcp_upstream_port=${tcp_upstream_port_input:-2030} # Apply default if empty
    if validate_port "$tcp_upstream_port"; then
      break
    else
      print_error "❌ Invalid port number. Port must be between 1 and 65535."
    fi
  done

  echo -e "  (Default UDP upstream port is 2040)"
  # Validate UDP Upstream Port
  local udp_upstream_port
  while true; do
    echo -e "👉 ${WHITE}Enter UDP upstream port (1-65535, default 2040):${RESET} " # Enter UDP upstream port (1-65535, default 8800):
    read -p "" udp_upstream_port_input
    udp_upstream_port=${udp_upstream_port_input:-2040} # Apply default if empty
    if validate_port "$udp_upstream_port"; then
      break
    else
      print_error "❌ Invalid port number. Port must be between 1 and 65535."
    fi
    done


  echo -e "👉 ${WHITE}Enter password:${RESET} "
  read -p "" password
  echo ""

  if [[ -z "$password" ]]; then
    echo -e "${RED}❌ Password cannot be empty!${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
    read -p ""
    return
  fi

  local service_file="/etc/systemd/system/trusttunnel-direct.service"

  if systemctl is-active --quiet trusttunnel-direct.service || systemctl is-enabled --quiet trusttunnel-direct.service; then
    echo -e "${YELLOW}🛑 Stopping existing Direct Trusttunnel service...${RESET}"
    sudo systemctl stop trusttunnel-direct.service > /dev/null 2>&1
    sudo systemctl disable trusttunnel-direct.service > /dev/null 2>&1
    sudo rm -f /etc/systemd/system/trusttunnel-direct.service > /dev/null 2>&1
    sudo systemctl daemon-reload > /dev/null 2>&1
    print_success "Existing Direct TrustTunnel service removed."
  fi

  cat <<EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=Direct TrustTunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$(pwd)/rstun/rstund --addr $server_listen_addr:$listen_port --password "$password" --tcp-upstream $tcp_upstream_port --udp-upstream $udp_upstream_port $cert_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000
Restart=always
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

  # Verify service file was created
  if [ ! -f "$service_file" ]; then
    print_error "❌ Failed to create service file at $service_file"
    echo -e "${YELLOW}Check permissions and try again${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
    read -p ""
    return 1
  else
    echo -e "${GREEN}✅ Service file created at $service_file${RESET}"
  fi

  echo -e "${CYAN}🔧 Reloading systemd daemon...${RESET}"
  sudo systemctl daemon-reload

  echo -e "${CYAN}🚀 Enabling and starting Direct Trusttunnel service...${RESET}"

  # Enable the service
  if sudo systemctl enable trusttunnel-direct.service > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service enabled successfully${RESET}"
  else
    print_error "Failed to enable the service"
  fi

  # Start the service and check if it started successfully
  if sudo systemctl start trusttunnel-direct.service > /dev/null 2>&1; then
    # Check if service is actually running
    if systemctl is-active --quiet trusttunnel-direct.service; then
      print_success "✅ Direct TrustTunnel server started successfully!"
      echo -e "${CYAN}📋 Service Details:${RESET}"
      echo -e "   ${WHITE}Service: trusttunnel-direct.service${RESET}"
      echo -e "   ${WHITE}Status: $(systemctl is-active trusttunnel-direct.service)${RESET}"
      echo -e "   ${WHITE}Listen Address: $server_listen_addr:$listen_port${RESET}"
      echo -e "   ${WHITE}TCP Upstream: $tcp_upstream_port${RESET}"
      echo -e "   ${WHITE}UDP Upstream: $udp_upstream_port${RESET}"
      if [[ "$tls_enabled" == "true" ]]; then
        echo -e "   ${WHITE}TLS: Enabled (Domain: $selected_domain_name)${RESET}"
      else
        echo -e "   ${WHITE}TLS: Disabled${RESET}"
      fi
    else
      print_error "❌ Service failed to start. Checking status..."
      echo -e "${YELLOW}Service Status: $(systemctl is-active trusttunnel-direct.service)${RESET}"
      echo -e "${YELLOW}Run 'sudo systemctl status trusttunnel-direct.service' for more details${RESET}"
    fi
  else
    print_error "❌ Failed to start the service"
    echo -e "${YELLOW}Check service file: /etc/systemd/system/trusttunnel-direct.service${RESET}"
    echo -e "${YELLOW}Run 'sudo systemctl status trusttunnel-direct.service' for error details${RESET}"
  fi

  echo ""
  echo -e "${YELLOW}Do you want to view the logs for trusttunnel-direct.service now? (y/N): ${RESET}"
  read -p "" view_logs_choice
  echo ""

  if [[ "$view_logs_choice" =~ ^[Yy]$ ]]; then
    show_service_logs trusttunnel-direct.service
  fi

  echo ""
  echo -e "${YELLOW}Press Enter to return to main menu...${RESET}"
  read -p ""
}


# --- Manage Client Ports Action ---
manage_client_ports_action() {
  local client_type="$1" # "reverse" or "direct"
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  if [[ "$client_type" == "reverse" ]]; then
    echo -e "${CYAN}     🔧 Manage Reverse Client Ports${RESET}"
  else
    echo -e "${CYAN}     🔧 Manage Direct Client Ports${RESET}"
  fi
  draw_line "$CYAN" "=" 40
  echo ""

  # Determine service pattern based on client type
  local service_pattern
  if [[ "$client_type" == "reverse" ]]; then
    service_pattern="trusttunnel-"
  else
    service_pattern="trusttunnel-direct-client-"
  fi

  echo -e "${CYAN}🔍 Searching for ${client_type} clients ...${RESET}"

  # List all systemd services matching the pattern
  mapfile -t services < <(systemctl list-units --type=service --all | grep "$service_pattern" | awk '{print $1}' | sed 's/.service$//')

  if [ ${#services[@]} -eq 0 ]; then
    echo -e "${RED}❌ No ${client_type} clients found.${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
    read -p ""
    return
  fi

  echo -e "${CYAN}📋 Please select a client to manage ports:${RESET}"
  services+=("Back to previous menu")
  select selected_service in "${services[@]}"; do
    if [[ "$selected_service" == "Back to previous menu" ]]; then
      echo -e "${YELLOW}Returning to previous menu...${RESET}"
      echo ""
      return
    elif [ -n "$selected_service" ]; then
      break
    else
      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}"
    fi
  done
  echo ""

  # Parse current port mappings from the service file
  local service_file="/etc/systemd/system/${selected_service}.service"
  local exec_start_line=$(grep "ExecStart=" "$service_file")
  local tcp_mappings=""
  local udp_mappings=""

  # Extract TCP mappings
  if [[ "$exec_start_line" =~ --tcp-mappings[[:space:]]+\"([^\"]+)\" ]]; then
    tcp_mappings="${BASH_REMATCH[1]}"
  fi

  # Extract UDP mappings
  if [[ "$exec_start_line" =~ --udp-mappings[[:space:]]+\"([^\"]+)\" ]]; then
    udp_mappings="${BASH_REMATCH[1]}"
  fi

  # Parse ports from mappings
  declare -a tcp_ports=()
  declare -a udp_ports=()

  # Function to extract ports from mapping string
  extract_ports_from_mappings() {
    local mapping_str="$1"
    local port_array_name="$2"
    local -n ports_ref="$port_array_name"

    if [[ -n "$mapping_str" ]]; then
      # Split by comma and extract ports
      IFS=',' read -ra mappings <<< "$mapping_str"
      for mapping in "${mappings[@]}"; do
        if [[ "$client_type" == "reverse" ]]; then
          # Format: IN^0.0.0.0:port^0.0.0.0:port
          if [[ "$mapping" =~ IN\^0\.0\.0\.0:([0-9]+)\^0\.0\.0\.0:[0-9]+ ]]; then
            ports_ref+=("${BASH_REMATCH[1]}")
          fi
        else
          # Format: OUT^0.0.0.0:port^port
          if [[ "$mapping" =~ OUT\^0\.0\.0\.0:([0-9]+)\^[0-9]+ ]]; then
            ports_ref+=("${BASH_REMATCH[1]}")
          fi
        fi
      done
    fi
  }

  extract_ports_from_mappings "$tcp_mappings" tcp_ports
  extract_ports_from_mappings "$udp_mappings" udp_ports

  # Remove duplicates and sort
  tcp_ports=($(echo "${tcp_ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  udp_ports=($(echo "${udp_ports[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

  # Port management menu
  while true; do
    clear
    echo ""
    draw_line "$CYAN" "=" 40
    echo -e "${CYAN}     🔧 Managing Ports for: ${WHITE}$selected_service${RESET}"
    draw_line "$CYAN" "=" 40
    echo ""

    echo -e "${CYAN}📊 Current Port Configuration:${RESET}"
    echo -e "  ${YELLOW}TCP Ports:${RESET} ${tcp_ports[*]:-None}"
    echo -e "  ${YELLOW}UDP Ports:${RESET} ${udp_ports[*]:-None}"
    echo ""

    echo -e "${CYAN}Choose an action:${RESET}"
    echo -e "  ${YELLOW}1)${RESET} ${WHITE}Add ports${RESET}"
    echo -e "  ${YELLOW}2)${RESET} ${WHITE}Edit ports${RESET}"
    echo -e "  ${YELLOW}3)${RESET} ${WHITE}Delete ports${RESET}"
    echo -e "  ${YELLOW}4)${RESET} ${WHITE}Back to client management${RESET}"
    echo ""
    draw_line "$CYAN" "-" 40
    echo -e "👉 ${CYAN}Your choice:${RESET} "
    read -p "" port_action
    echo ""

    case $port_action in
      1) # Add ports
        echo -e "${CYAN}➕ Add Ports:${RESET}"
        echo -e "  (Enter ports as comma-separated values, e.g., 80,443,8080)"
        echo ""

        # Add TCP ports
        echo -e "👉 ${WHITE}Enter TCP ports to add (or press Enter to skip):${RESET} "
        read -p "" new_tcp_ports_input
        if [[ -n "$new_tcp_ports_input" ]]; then
          IFS=',' read -ra new_tcp_ports <<< "$new_tcp_ports_input"
          for port in "${new_tcp_ports[@]}"; do
            port=$(echo "$port" | xargs) # Trim whitespace
            if validate_port "$port"; then
              if [[ ! " ${tcp_ports[*]} " =~ " ${port} " ]]; then
                tcp_ports+=("$port")
                print_success "TCP port $port added."
              else
                echo -e "${YELLOW}⚠️ TCP port $port already exists.${RESET}"
              fi
            else
              print_error "Invalid TCP port: $port"
            fi
          done
        fi

        # Add UDP ports
        echo ""
        echo -e "👉 ${WHITE}Enter UDP ports to add (or press Enter to skip):${RESET} "
        read -p "" new_udp_ports_input
        if [[ -n "$new_udp_ports_input" ]]; then
          IFS=',' read -ra new_udp_ports <<< "$new_udp_ports_input"
          for port in "${new_udp_ports[@]}"; do
            port=$(echo "$port" | xargs) # Trim whitespace
            if validate_port "$port"; then
              if [[ ! " ${udp_ports[*]} " =~ " ${port} " ]]; then
                udp_ports+=("$port")
                print_success "UDP port $port added."
              else
                echo -e "${YELLOW}⚠️ UDP port $port already exists.${RESET}"
              fi
            else
              print_error "Invalid UDP port: $port"
            fi
          done
        fi
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${RESET}"
        read -p ""
        ;;

      2) # Edit ports
        echo -e "${CYAN}✏️ Edit Ports:${RESET}"
        echo ""

        # Edit TCP ports
        if [ ${#tcp_ports[@]} -gt 0 ]; then
          echo -e "${YELLOW}Current TCP ports: ${tcp_ports[*]}${RESET}"
          echo -e "👉 ${WHITE}Enter new TCP ports (comma-separated, replaces all existing):${RESET} "
          read -p "" edit_tcp_input
          if [[ -n "$edit_tcp_input" ]]; then
            tcp_ports=()
            IFS=',' read -ra new_tcp_ports <<< "$edit_tcp_input"
            for port in "${new_tcp_ports[@]}"; do
              port=$(echo "$port" | xargs)
              if validate_port "$port"; then
                tcp_ports+=("$port")
              else
                print_error "Invalid TCP port: $port"
              fi
            done
            print_success "TCP ports updated."
          fi
        else
          echo -e "${YELLOW}No TCP ports configured.${RESET}"
        fi

        # Edit UDP ports
        echo ""
        if [ ${#udp_ports[@]} -gt 0 ]; then
          echo -e "${YELLOW}Current UDP ports: ${udp_ports[*]}${RESET}"
          echo -e "👉 ${WHITE}Enter new UDP ports (comma-separated, replaces all existing):${RESET} "
          read -p "" edit_udp_input
          if [[ -n "$edit_udp_input" ]]; then
            udp_ports=()
            IFS=',' read -ra new_udp_ports <<< "$edit_udp_input"
            for port in "${new_udp_ports[@]}"; do
              port=$(echo "$port" | xargs)
              if validate_port "$port"; then
                udp_ports+=("$port")
              else
                print_error "Invalid UDP port: $port"
              fi
            done
            print_success "UDP ports updated."
          fi
        else
          echo -e "${YELLOW}No UDP ports configured.${RESET}"
        fi
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${RESET}"
        read -p ""
        ;;

      3) # Delete ports
        echo -e "${CYAN}🗑️ Delete Ports:${RESET}"
        echo ""

        # Delete TCP ports
        if [ ${#tcp_ports[@]} -gt 0 ]; then
          echo -e "${YELLOW}Current TCP ports: ${tcp_ports[*]}${RESET}"
          echo -e "👉 ${WHITE}Enter TCP ports to delete (comma-separated):${RESET} "
          read -p "" delete_tcp_input
          if [[ -n "$delete_tcp_input" ]]; then
            IFS=',' read -ra ports_to_delete <<< "$delete_tcp_input"
            for port in "${ports_to_delete[@]}"; do
              port=$(echo "$port" | xargs)
              for i in "${!tcp_ports[@]}"; do
                if [[ "${tcp_ports[i]}" == "$port" ]]; then
                  unset 'tcp_ports[i]'
                  print_success "TCP port $port deleted."
                  break
                fi
              done
            done
            # Re-index array
            tcp_ports=("${tcp_ports[@]}")
          fi
        else
          echo -e "${YELLOW}No TCP ports configured.${RESET}"
        fi

        # Delete UDP ports
        echo ""
        if [ ${#udp_ports[@]} -gt 0 ]; then
          echo -e "${YELLOW}Current UDP ports: ${udp_ports[*]}${RESET}"
          echo -e "👉 ${WHITE}Enter UDP ports to delete (comma-separated):${RESET} "
          read -p "" delete_udp_input
          if [[ -n "$delete_udp_input" ]]; then
            IFS=',' read -ra ports_to_delete <<< "$delete_udp_input"
            for port in "${ports_to_delete[@]}"; do
              port=$(echo "$port" | xargs)
              for i in "${!udp_ports[@]}"; do
                if [[ "${udp_ports[i]}" == "$port" ]]; then
                  unset 'udp_ports[i]'
                  print_success "UDP port $port deleted."
                  break
                fi
              done
            done
            # Re-index array
            udp_ports=("${udp_ports[@]}")
          fi
        else
          echo -e "${YELLOW}No UDP ports configured.${RESET}"
        fi
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${RESET}"
        read -p ""
        ;;

      4) # Back
        break
        ;;

      *)
        echo -e "${RED}❌ Invalid option.${RESET}"
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${RESET}"
        read -p ""
        ;;
    esac
  done

  # Update the service file with new port mappings
  if [[ ${#tcp_ports[@]} -gt 0 || ${#udp_ports[@]} -gt 0 ]]; then
    echo -e "${CYAN}🔄 Updating service configuration...${RESET}"

    # Build new mapping strings
    local new_tcp_mappings=""
    local new_udp_mappings=""

    for port in "${tcp_ports[@]}"; do
      if [[ "$client_type" == "reverse" ]]; then
        mapping="IN^0.0.0.0:$port^0.0.0.0:$port"
      else
        mapping="OUT^0.0.0.0:$port^$port"
      fi
      [ -z "$new_tcp_mappings" ] && new_tcp_mappings="$mapping" || new_tcp_mappings="$new_tcp_mappings,$mapping"
    done

    for port in "${udp_ports[@]}"; do
      if [[ "$client_type" == "reverse" ]]; then
        mapping="IN^0.0.0.0:$port^0.0.0.0:$port"
      else
        mapping="OUT^0.0.0.0:$port^$port"
      fi
      [ -z "$new_udp_mappings" ] && new_udp_mappings="$mapping" || new_udp_mappings="$new_udp_mappings,$mapping"
    done

    # Update the ExecStart line in the service file
    local new_exec_start="$exec_start_line"

    # Replace TCP mappings
    if [[ -n "$new_tcp_mappings" ]]; then
      if [[ "$new_exec_start" =~ --tcp-mappings[[:space:]]+\"[^\"]*\" ]]; then
        new_exec_start=$(echo "$new_exec_start" | sed "s/--tcp-mappings \"[^\"]*\"/--tcp-mappings \"$new_tcp_mappings\"/")
      else
        # Add TCP mappings if they don't exist
        new_exec_start=$(echo "$new_exec_start" | sed "s/rstunc /rstunc --tcp-mappings \"$new_tcp_mappings\" /")
      fi
    else
      # Remove TCP mappings if empty
      new_exec_start=$(echo "$new_exec_start" | sed 's/--tcp-mappings \"[^\"]*\"//')
    fi

    # Replace UDP mappings
    if [[ -n "$new_udp_mappings" ]]; then
      if [[ "$new_exec_start" =~ --udp-mappings[[:space:]]+\"[^\"]*\" ]]; then
        new_exec_start=$(echo "$new_exec_start" | sed "s/--udp-mappings \"[^\"]*\"/--udp-mappings \"$new_udp_mappings\"/")
      else
        # Add UDP mappings if they don't exist
        new_exec_start=$(echo "$new_exec_start" | sed "s/rstunc /rstunc --udp-mappings \"$new_udp_mappings\" /")
      fi
    else
      # Remove UDP mappings if empty
      new_exec_start=$(echo "$new_exec_start" | sed 's/--udp-mappings \"[^\"]*\"//')
    fi

    # Clean up extra spaces
    new_exec_start=$(echo "$new_exec_start" | sed 's/  */ /g')

    # Update the service file
    sed -i "s|^ExecStart=.*|${new_exec_start}|" "$service_file"

    # Reload systemd and restart service
    echo -e "${CYAN}🔧 Reloading systemd daemon...${RESET}"
    sudo systemctl daemon-reload

    echo -e "${CYAN}🚀 Restarting $selected_service...${RESET}"
    sudo systemctl restart "$selected_service" > /dev/null 2>&1

    if systemctl is-active --quiet "$selected_service"; then
      print_success "Service $selected_service restarted successfully with updated ports."
    else
      print_error "Failed to restart service $selected_service. Please check logs."
    fi
  else
    echo -e "${YELLOW}⚠️ No ports configured. Service will not be updated.${RESET}"
  fi

  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
  read -p ""
}

# --- Add New Direct Client Action ---
add_new_direct_client_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}        ➕ Add New Direct Client${RESET}"
  draw_line "$CYAN" "=" 40
  echo ""

  # Prompt for the client name
  echo -e "👉 ${WHITE}Enter client name (e.g., client1, client2):${RESET} "
  read -p "" client_name
  echo ""

  # Construct the service name based on the client name
  service_name="trusttunnel-direct-client-$client_name"
  # Define the path for the systemd service file
  service_file="/etc/systemd/system/${service_name}.service"

  # Check if a service with the given name already exists
  if [ -f "$service_file" ]; then
    echo -e "${RED}❌ Service with this name already exists.${RESET}"
    echo ""
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
    read -p ""
    return
  fi

  echo -e "${CYAN}🌐 Server Connection Details:${RESET}"
  
  local use_ipv6_server_input
  local server_addr_input # The raw input from the user
  local server_host_part  # The host part extracted (e.g., example.com, 192.168.1.1, 2001:db8::1)
  local server_port_part  # The port part extracted
  local final_server_addr # The final string to be used in ExecStart

  echo -e "👉 ${WHITE}Do you want to connect to the server using IPv6? (Y/n, default: N):${RESET} "
  read -p "" use_ipv6_server_input
  use_ipv6_server_input=${use_ipv6_server_input:-N} # Default to N if empty

  if [[ "$use_ipv6_server_input" =~ ^[Yy]$ ]]; then
    print_success "Client will attempt to connect to server via IPv6. Please enter address in '[IPv6_address]:port' or 'domain:port' format."
  else
    print_success "Client will attempt to connect to server via IPv4/Domain. Please enter address in 'host:port' format."
  fi
  echo ""

  while true; do
    echo -e "👉 ${WHITE}Enter server address and port:${RESET} "
    read -p "" server_addr_input

    # Try to parse as IPv6 literal first (e.g., [::1]:8800)
    if [[ "$server_addr_input" =~ ^\[(.*)\]:([0-9]+)$ ]]; then
        server_host_part="${BASH_REMATCH[1]}"
        server_port_part="${BASH_REMATCH[2]}"
        # Ensure user chose IPv6 if they entered IPv6 format
        if [[ ! "$use_ipv6_server_input" =~ ^[Yy]$ ]]; then
            print_error "You selected IPv4, but entered an IPv6 address in bracket format. Please re-enter or change your IPv6 choice."
            continue
        fi
    # Then try to parse as standard host:port (e.g., example.com:8800, 192.168.1.1:8800)
    elif [[ "$server_addr_input" =~ ^([^:]+):([0-9]+)$ ]]; then
        server_host_part="${BASH_REMATCH[1]}"
        server_port_part="${BASH_REMATCH[2]}"
        # Ensure user chose IPv4/Domain if they entered that format
        if [[ "$use_ipv6_server_input" =~ ^[Yy]$ ]]; then
            # If user chose IPv6 but entered a non-bracketed address, it could be a domain that resolves to IPv6.
            # We'll allow this for flexibility, but warn if it's clearly an IPv4 address.
            if [[ "$server_host_part" =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
                print_error "You selected IPv6, but entered an IPv4 address. Please re-enter in '[IPv6_address]:port' format or change your IPv6 choice."
                continue
            fi
        fi
    else
        print_error "Invalid server address format. Please use 'host:port' or '[IPv6_address]:port' as appropriate."
        continue
    fi

    # Validate the extracted host and port parts
    if validate_host "$server_host_part" && validate_port "$server_port_part"; then
        final_server_addr="$server_addr_input" # Use the input as is, it's already correctly formatted
        break
    else
        print_error "Invalid host or port in the provided address. Please ensure the host is a valid IP/domain and port is 1-65535."
    fi
  done
  echo ""

  echo -e "${CYAN}📡 Tunnel Protocol Configuration:${RESET}"
  echo -e "${WHITE}Choose which network protocols to tunnel through this connection${RESET}"
  echo -e "${YELLOW}Options: tcp (web/HTTP), udp (games/DNS), both (recommended)${RESET}"
  echo ""
  read -p "👉 Select tunnel mode (tcp/udp/both): " tunnel_mode
  echo ""

  echo -e "${CYAN}🔐 Security Configuration:${RESET}"
  echo -e "${WHITE}Enter the password that matches your tunnel server${RESET}"
  echo -e "${YELLOW}This must be identical to the server password${RESET}"
  echo ""
  read -p "👉 Enter connection password: " password
  echo ""

  echo -e "${CYAN}🔢 Port Mapping Configuration:${RESET}"
  echo -e "${WHITE}Specify which local ports to tunnel to the remote server${RESET}"
  echo -e "${YELLOW}Each port will be accessible from the server side${RESET}"
  echo ""

  local port_count
  while true; do
    read -p "👉 How many ports to tunnel? " port_count_input
    if [[ "$port_count_input" =~ ^[0-9]+$ ]] && (( port_count_input >= 0 )); then
      port_count=$port_count_input
      break
    else
      print_error "❌ Invalid input. Please enter 0 or a positive number for the port count."
    fi
  done
  echo ""
  
  mappings=""
  for ((i=1; i<=port_count; i++)); do
    local port
    while true; do
      read -p "👉 Enter Port #$i (1-65535): " port_input
      if validate_port "$port_input"; then
        port="$port_input"
        break
      else
        print_error "❌ Invalid port number. Port must be between 1 and 65535."
      fi
    done
    mapping="OUT^0.0.0.0:$port^$port"
    [ -z "$mappings" ] && mappings="$mapping" || mappings="$mappings,$mapping"
    echo ""
  done

  # Determine the mapping arguments based on the tunnel_mode
  mapping_args=""
  case "$tunnel_mode" in
    "tcp")
      mapping_args="--tcp-mappings \"$mappings\""
      ;;
    "udp")
      mapping_args="--udp-mappings \"$mappings\""
      ;;
    "both")
      mapping_args="--tcp-mappings \"$mappings\" --udp-mappings \"$mappings\""
      ;;
    *)
      echo -e "${YELLOW}⚠️ Invalid tunnel mode specified. Using 'both' as default.${RESET}" # Invalid tunnel mode specified. Using 'both' as default.
      mapping_args="--tcp-mappings \"$mappings\" --udp-mappings \"$mappings\""
      ;;
  esac

  # Create the systemd service file
  cat <<EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=TrustTunnel Client - $client_name
After=network.target

[Service]
Type=simple
ExecStart=$(pwd)/rstun/rstunc --server-addr "$final_server_addr" --password "$password" $mapping_args --quic-timeout-ms 1000 --tcp-timeout-ms 1000 --udp-timeout-ms 1000 --wait-before-retry-ms 3000
Restart=always
RestartSec=5
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

  echo -e "${CYAN}🔧 Reloading systemd daemon...${RESET}" # Reloading systemd daemon...
  sudo systemctl daemon-reload

  echo -e "${CYAN}🚀 Enabling and starting Direct Trusttunnel client service...${RESET}" # Enabling and starting Direct Trusttunnel client service...
  sudo systemctl enable "$service_name" > /dev/null 2>&1
  sudo systemctl start "$service_name" > /dev/null 2>&1

  print_success "✅ Direct tunnel client '$client_name' has been created and started!"
  echo -e "${CYAN}📋 Service Details:${RESET}"
  echo -e "   ${WHITE}Service Name: $service_name${RESET}"
  echo -e "   ${WHITE}Connection: $final_server_addr${RESET}"
  echo -e "   ${WHITE}Protocol: $tunnel_mode${RESET}"
  echo -e "   ${WHITE}Ports: ${mappings//,/, }${RESET}"
  echo ""
  echo -e "${CYAN}🔍 Monitoring Options:${RESET}"
  read -p "👉 View client logs now? (y/N): " view_logs_choice
  echo ""

  if [[ "$view_logs_choice" =~ ^[Yy]$ ]]; then
    show_service_logs "$service_name"
  fi
  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
  read -p ""
}


# --- New: Function to get a new SSL certificate using Certbot ---
get_new_certificate_action() {
  clear
  echo ""
  draw_line "$CYAN" "=" 40
  echo -e "${CYAN}     ➕ Get New SSL Certificate${RESET}"
  draw_line "$CYAN" "=" 40
  echo ""

  echo -e "${CYAN}🌐 Domain and Email for SSL Certificate:${RESET}"
  echo -e "  (e.g., yourdomain.com)"
  
  local domain
  while true; do
    echo -e "👉 ${WHITE}Please enter your domain:${RESET} "
    read -p "" domain
    if validate_host "$domain"; then
      break
    else
      print_error "Invalid domain or IP address format. Please try again."
    fi
  done
  echo ""

  local email
  while true; do
    echo -e "👉 ${WHITE}Please enter your email:${RESET} "
    read -p "" email
    if validate_email "$email"; then
      break
    else
      print_error "Invalid email format. Please try again."
    fi
  done
  echo ""

  local cert_path="/etc/letsencrypt/live/$domain"

  if [ -d "$cert_path" ]; then
    print_success "SSL certificate for $domain already exists. Skipping Certbot."
  else
    echo -e "${CYAN}🔐 Requesting SSL certificate with Certbot...${RESET}"
    echo -e "${YELLOW}Ensure port 80 is open and not in use by another service.${RESET}"
    if sudo certbot certonly --standalone -d "$domain" --non-interactive --agree-tos -m "$email"; then
      print_success "SSL certificate obtained successfully for $domain."
    else
      print_error "❌ Failed to obtain SSL certificate for $domain. Check Certbot logs for details."
      print_error "   Ensure your domain points to this server and port 80 is open."
    fi
  fi
  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
  read -p ""
}

# --- New: Function to delete existing SSL certificates ---
delete_certificates_action() {
  clear
  echo ""
  draw_line "$RED" "=" 40
  echo -e "${RED}     🗑️ Delete SSL Certificates${RESET}"
  draw_line "$RED" "=" 40
  echo ""

  echo -e "${CYAN}🔍 Searching for existing SSL certificates...${RESET}"
  # Find directories under /etc/letsencrypt/live/ that are not 'README'
  mapfile -t cert_domains < <(sudo find /etc/letsencrypt/live -maxdepth 1 -mindepth 1 -type d ! -name "README" -exec basename {} \;)

  if [ ${#cert_domains[@]} -eq 0 ]; then
    print_error "No SSL certificates found to delete."
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
    read -p ""
    return 1
  fi

  echo -e "${CYAN}📋 Please select a certificate to delete:${RESET}"
  # Add a "Back to previous menu" option
  cert_domains+=("Back to previous menu")
  select selected_domain in "${cert_domains[@]}"; do
    if [[ "$selected_domain" == "Back to previous menu" ]]; then
      echo -e "${YELLOW}Returning to previous menu...${RESET}"
      echo ""
      return 0
    elif [ -n "$selected_domain" ]; then
      break
    else
      print_error "Invalid selection. Please enter a valid number."
    fi
  done
  echo ""

  if [[ -z "$selected_domain" ]]; then
    print_error "No certificate selected. Aborting deletion."
    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
    read -p ""
    return 1
  fi

  echo -e "${RED}⚠️ Are you sure you want to delete the certificate for '$selected_domain'? (y/N): ${RESET}"
  read -p "" confirm_delete
  echo ""

  if [[ "$confirm_delete" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}🗑️ Deleting certificate for '$selected_domain' using Certbot...${RESET}"
    if sudo certbot delete --cert-name "$selected_domain"; then
      print_success "Certificate for '$selected_domain' deleted successfully."
    else
      print_error "❌ Failed to delete certificate for '$selected_domain'. Check Certbot logs."
    fi
  else
    echo -e "${YELLOW}Deletion cancelled for '$selected_domain'.${RESET}"
  fi

  echo ""
  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
  read -p ""
}

# --- New: Certificate Management Menu Function ---
certificate_management_menu() {
  while true; do
    clear
    echo ""
    echo -e "${BOLD_GREEN}🔐 SSL Certificate Management${RESET}"
    echo ""
    echo -e "  ${WHITE}1)${RESET} ${WHITE}➕ Request New Certificate${RESET}"
    echo -e "  ${RED}2)${RESET} ${WHITE}🗑️  Delete Certificates${RESET}"
    echo -e "  ${YELLOW}3)${RESET} ${WHITE}📄 Add Custom Certificate${RESET}"
    echo -e "  ${WHITE}4)${RESET} ${WHITE}↩️  Back to Main Menu${RESET}"
    echo ""
    read -p "👉 Enter your choice (1-4): " cert_choice
    echo ""

    case $cert_choice in
      1)
        get_new_certificate_action
        ;;
      2)
        delete_certificates_action
        ;;
      3)
        add_custom_certificate_action
        ;;
      4)
        echo -e "${YELLOW}Returning to main menu...${RESET}" # Changed to English
        break
        ;;
      *)
        echo -e "${RED}❌ Invalid option.${RESET}" # Changed to English
        echo ""
        echo -e "${YELLOW}Press Enter to continue...${RESET}" # Changed to English
        read -p ""
        ;;
    esac
  done
}

# --- New Function: Add Custom Certificate from Content ---
add_custom_certificate_action() {
  clear
  echo ""
  draw_line "$GREEN" "=" 40
  echo -e "${CYAN}     ➕ Add Custom Certificate${RESET}"
  draw_line "$GREEN" "=" 40
  echo ""

  echo -e "${WHITE}Please enter the domain name (e.g., example.com):${RESET}" # Changed to English
  read -p "👉 " DOMAIN_NAME

  if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}❌ Domain name cannot be empty.${RESET}" # Changed to English
    echo ""
    echo -e "${YELLOW}Press Enter to continue...${RESET}" # Changed to English
    read -p ""
    return
  fi

  CERT_DIR="/etc/letsencrypt/live/$DOMAIN_NAME"
  FULLCHAIN_PATH="$CERT_DIR/fullchain.pem"
  PRIVKEY_PATH="$CERT_DIR/privkey.pem"

  # Create directory if it doesn't exist
  if [ ! -d "$CERT_DIR" ]; then
    echo -e "${YELLOW}Creating directory: $CERT_DIR${RESET}" # Changed to English
    if ! mkdir -p "$CERT_DIR"; then
      echo -e "${RED}❌ Error creating directory. Please check permissions.${RESET}" # Changed to English
      echo ""
      echo -e "${YELLOW}Press Enter to continue...${RESET}" # Changed to English
      read -p ""
      return
    fi
  fi

  echo ""
  echo -e "${WHITE}Please paste the content of the ${CYAN}fullchain.pem${WHITE} file.${RESET}" # Changed to English
  echo -e "${WHITE}After pasting, create a new line, type ${CYAN}END_CERT${WHITE}, and press Enter.${RESET}" # Changed to English
  echo -e "${GREEN}--- Start pasting fullchain.pem ---${RESET}" # Changed to English
  FULLCHAIN_CONTENT=""
  while IFS= read -r line; do
    if [[ "$line" == "END_CERT" ]]; then
      break
    fi
    FULLCHAIN_CONTENT+="$line"$'\n'
  done

  echo -e "${GREEN}--- End pasting fullchain.pem ---${RESET}" # Changed to English
  echo ""

  echo -e "${WHITE}Please paste the content of the ${CYAN}privkey.pem${WHITE} file.${RESET}" # Changed to English
  echo -e "${WHITE}After pasting, create a new line, type ${CYAN}END_CERT${WHITE}, and press Enter.${RESET}" # Changed to English
  echo -e "${GREEN}--- Start pasting privkey.pem ---${RESET}" # Changed to English
  PRIVKEY_CONTENT=""
  while IFS= read -r line; do
    if [[ "$line" == "END_CERT" ]]; then
      break
    fi
    PRIVKEY_CONTENT+="$line"$'\n'
  done
  echo -e "${GREEN}--- End pasting privkey.pem ---${RESET}" # Changed to English
  echo ""

  # Save fullchain.pem
  echo -e "$FULLCHAIN_CONTENT" > "$FULLCHAIN_PATH"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ fullchain.pem saved successfully: $FULLCHAIN_PATH${RESET}" # Changed to English
  else
    echo -e "${RED}❌ Error saving fullchain.pem. Please check permissions.${RESET}" # Changed to English
  fi

  # Save privkey.pem
  echo -e "$PRIVKEY_CONTENT" > "$PRIVKEY_PATH"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ privkey.pem saved successfully: $PRIVKEY_PATH${RESET}" # Changed to English
  else
    echo -e "${RED}❌ Error saving privkey.pem. Please check permissions.${RESET}" # Changed to English
  fi

  echo ""
  echo -e "${YELLOW}Press Enter to continue...${RESET}" # Changed to English
  read -p ""
}


# --- Main Script Execution ---
set -e # Exit immediately if a command exits with a non-zero status

# Perform initial setup (will run only once)
perform_initial_setup || { echo "Initial setup failed. Exiting."; exit 1; }

# Check Rust readiness after initial setup
if command -v rustc >/dev/null 2>&1; then
  RUST_IS_READY=true
else
  RUST_IS_READY=false
fi

if [ "$RUST_IS_READY" = true ]; then
while true; do
  # Clear terminal and show logo
  clear
  echo -e "${BOLD_GREEN}"
  figlet -f slant "TrustTunnel"
  echo -e "${BOLD_GREEN}"
  echo -e "${BOLD_GREEN}==========================================================${RESET}"
  echo ""
  echo -e "${CYAN}Developed by ErfanXRay => ${WHITE}https://github.com/Erfan-XRay/TrustTunnel${RESET}"
  echo -e "${CYAN}Telegram Channel => ${WHITE}@Erfan_XRay${RESET}"
  echo ""

  # Get system information
  server_ipv4=$(hostname -I | awk '{print $1}')
  rstun_status="Not Installed"
  if [ -f "rstun/rstund" ]; then
    rstun_status="✅ Installed"
  fi
  script_version="3.0.0"

  echo -e "${BOLD_GREEN}📊 System Information:${RESET}"
  echo -e "  ${CYAN}🌐 Server IPv4:${RESET} ${WHITE}$server_ipv4${RESET}"
  echo -e "  ${CYAN}📦 RSTUN Status:${RESET} ${WHITE}$rstun_status${RESET}"
  echo -e "  ${CYAN}🏷️  Script Version:${RESET} ${WHITE}$script_version${RESET}"
  echo ""

  # Main Menu Options - Minimal Design
  echo -e "${BOLD_GREEN}📋 Available Options:${RESET}"
  echo ""
  echo -e "  ${MAGENTA}1)${RESET} ${WHITE}📦 Install RSTUN${RESET}"
  echo -e "  ${CYAN}2)${RESET} ${WHITE}🌐 Reverse Tunnel (IPv4 only)${RESET}"
  echo -e "  ${CYAN}3)${RESET} ${WHITE}🚀 Direct Tunnel (IPv4/IPv6)${RESET}"
  echo -e "  ${YELLOW}4)${RESET} ${WHITE}🔐 Certificate Management${RESET}"
  echo -e "  ${RED}5)${RESET} ${WHITE}🗑️  Uninstall TrustTunnel${RESET}"
  echo -e "  ${WHITE}6)${RESET} ${WHITE}👋 Exit${RESET}"
  echo ""
  read -p "👉 Choose option (1-6): " choice

  case $choice in
    1)
      install_trusttunnel_action
      ;;
    2)
   while true; do
    clear # Clear screen for a fresh menu display
    echo ""
    echo -e "${BOLD_GREEN}🌐 Reverse Tunnel Configuration${RESET}"
    echo ""
    echo -e "  ${MAGENTA}1)${RESET} ${WHITE}🏠 Server Side (Iran)${RESET}"
    echo -e "  ${BLUE}2)${RESET} ${WHITE}🌍 Client Side (Abroad)${RESET}"
    echo -e "  ${WHITE}3)${RESET} ${WHITE}↩️  Back to Main Menu${RESET}"
    echo ""
    read -p "👉 Enter your choice (1-3): " tunnel_choice
    echo "" # Add a blank line for better spacing after input

      case $tunnel_choice in
        1)
          clear

          # Server Management Sub-menu
          while true; do
            clear # Clear screen for a fresh menu display
            echo ""
            draw_line "$GREEN" "=" 40 # Top border
            echo -e "${CYAN}     🔧 TrustTunnel Server Management${RESET}" # TrustTunnel Server Management
            draw_line "$GREEN" "=" 40 # Separator
            echo ""
            echo -e "  ${YELLOW}1)${RESET} ${WHITE}Add new server${RESET}" # Add new server
            echo -e "  ${YELLOW}2)${RESET} ${WHITE}Show service logs${RESET}" # Show service logs
            echo -e "  ${YELLOW}3)${RESET} ${WHITE}Delete service${RESET}" # Delete service
            echo -e "  ${YELLOW}4)${RESET} ${MAGENTA}Schedule server restart${RESET}" # Schedule server restart
            echo -e "  ${YELLOW}5)${RESET} ${RED}Delete scheduled restart${RESET}" # New option: Delete scheduled restart
            echo -e "  ${YELLOW}6)${RESET} ${WHITE}Back to main menu${RESET}" # Back to main menu
            echo ""
            draw_line "$GREEN" "-" 40 # Bottom border
            echo -e "👉 ${CYAN}Your choice:${RESET} " # Your choice:
            read -p "" srv_choice
            echo ""
            case $srv_choice in
              1)
                add_new_server_action
              ;;
              2)
                clear
                service_file="/etc/systemd/system/trusttunnel.service"
                if [ -f "$service_file" ]; then
                  # Check if service exists in systemd
                  if systemctl list-unit-files --full --no-pager | grep -q "^trusttunnel.service"; then
                    show_service_logs "trusttunnel.service"
                  else
                    echo -e "${RED}❌ Service 'trusttunnel.service' is not loaded in systemd.${RESET}"
                    echo -e "${YELLOW}Try reloading systemd daemon: sudo systemctl daemon-reload${RESET}"
                    echo ""
                    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                    read -p ""
                  fi
                else
                  echo -e "${RED}❌ Service file 'trusttunnel.service' not found at $service_file${RESET}"
                  echo -e "${YELLOW}The service may not be created yet. Create a server first.${RESET}"
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                fi
              ;;
              3)
                clear
                service_file="/etc/systemd/system/trusttunnel.service"

                # Check if service is running or enabled
                if systemctl is-active --quiet trusttunnel.service 2>/dev/null || systemctl is-enabled --quiet trusttunnel.service 2>/dev/null; then
                  echo -e "${YELLOW}🛑 Stopping trusttunnel.service...${RESET}"
                  sudo systemctl stop trusttunnel.service > /dev/null 2>&1
                  echo -e "${YELLOW}🗑️ Disabling trusttunnel.service...${RESET}"
                  sudo systemctl disable trusttunnel.service > /dev/null 2>&1
                fi

                if [ -f "$service_file" ]; then
                  echo -e "${YELLOW}🗑️ Removing service file...${RESET}"
                  sudo rm -f "$service_file" > /dev/null 2>&1
                  sudo systemctl daemon-reload > /dev/null 2>&1
                  print_success "✅ TrustTunnel server service deleted successfully."
                else
                  echo -e "${RED}❌ Service file not found at $service_file${RESET}"
                  echo -e "${YELLOW}Service may already be deleted or never created.${RESET}"
                fi

                echo ""
                echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                read -p ""
              ;;
              4) # Schedule server restart
                reset_timer "trusttunnel" # Pass the server service name directly
              ;;
              5) # New case for deleting cron job
                delete_cron_job_action
              ;;
              6)
                echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
                break 2 # Break out of both inner while and outer case
              ;;
              *)
                echo -e "${RED}❌ Invalid option.${RESET}" # Invalid option.
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${RESET}" # Press Enter to continue...
                read -p ""
              ;;
            esac
          done
          ;;
        2)
          clear

          while true; do
            clear # Clear screen for a fresh menu display
            echo ""
            echo -e "${BOLD_GREEN}📡 Reverse Client Management${RESET}"
            echo ""
            echo -e "  ${WHITE}1)${RESET} ${WHITE}➕ Add New Client${RESET}"
            echo -e "  ${CYAN}2)${RESET} ${WHITE}📋 View Client Logs${RESET}"
            echo -e "  ${YELLOW}3)${RESET} ${WHITE}⚙️  Manage Client Ports${RESET}"
            echo -e "  ${RED}4)${RESET} ${WHITE}🗑️  Delete Client${RESET}"
            echo -e "  ${BLUE}5)${RESET} ${WHITE}⏰ Schedule Restart${RESET}"
            echo -e "  ${MAGENTA}6)${RESET} ${WHITE}🗑️  Delete Scheduled Restart${RESET}"
            echo -e "  ${WHITE}7)${RESET} ${WHITE}↩️  Back to Previous Menu${RESET}"
            echo ""
            read -p "👉 Enter your choice (1-7): " client_choice
            echo ""

            case $client_choice in
              1)
                add_new_client_action
              ;;
              2)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}     📊 TrustTunnel Client Logs${RESET}" # TrustTunnel Client Logs
                draw_line "$CYAN" "=" 40
                echo ""

                echo -e "${CYAN}🔍 Searching for clients ...${RESET}" # Searching for clients ...

                # List all systemd services that start with trusttunnel-
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-' | awk '{print $1}' | sed 's/.service$//')

                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No clients found.${RESET}" # No clients found.
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  # No return here, let the loop continue to show client management menu
                else
                  echo -e "${CYAN}📋 Please select a service to see log:${RESET}" # Please select a service to see log:
                  # Add "Back to previous menu" option
                  services+=("Back to previous menu")
                  select selected_service in "${services[@]}"; do
                    if [[ "$selected_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}" # Returning to previous menu...
                      echo ""
                      break 2 # Exit both the select and the outer while loop
                    elif [ -n "$selected_service" ]; then
                      show_service_logs "$selected_service"
                      break # Exit the select loop
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}" # Invalid selection. Please enter a valid number.
                    fi
                  done
                  echo "" # Add a blank line after selection
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  read -p ""
                fi
              ;;
              3)
                manage_client_ports_action "reverse"
              ;;
              4)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}     🗑️ Delete TrustTunnel Client${RESET}" # Delete TrustTunnel Client
                draw_line "$CYAN" "=" 40
                echo ""

                echo -e "${CYAN}🔍 Searching for clients ...${RESET}" # Searching for clients ...

                # List all systemd services that start with trusttunnel-
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-' | awk '{print $1}' | sed 's/.service$//')

                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No clients found.${RESET}" # No clients found.
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  # No return here, let the loop continue to show client management menu
                else
                  echo -e "${CYAN}📋 Please select a service to delete:${RESET}" # Please select a service to delete:
                  # Add "Back to previous menu" option
                  services+=("Back to previous menu")
                  select selected_service in "${services[@]}"; do
                    if [[ "$selected_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}" # Returning to previous menu...
                      echo ""
                      break 2 # Exit both the select and the outer while loop
                    elif [ -n "$selected_service" ]; then
                      service_file="/etc/systemd/system/${selected_service}.service"
                      echo -e "${YELLOW}🛑 Stopping $selected_service...${RESET}" # Stopping selected_service...
                      sudo systemctl stop "$selected_service" > /dev/null 2>&1
                      sudo systemctl disable "$selected_service" > /dev/null 2>&1
                      sudo rm -f "$service_file" > /dev/null 2>&1
                      sudo systemctl daemon-reload > /dev/null 2>&1
                      print_success "Client '$selected_service' deleted." # Client 'selected_service' deleted.
                      # Also remove any associated cron jobs for this specific client
                      echo -e "${CYAN}🧹 Removing cron jobs for '$selected_service'...${RESET}" # Removing cron jobs for 'selected_service'...
                      (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart for $selected_service$") | sudo crontab -
                      print_success "Cron jobs for '$selected_service' removed." # Cron jobs for '$selected_service' removed.
                      break # Exit the select loop
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}" # Invalid selection. Please enter a valid number.
                    fi
                  done
                  echo "" # Add a blank line after selection
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  read -p ""
                fi
              ;;
              4)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}     🗑️ Delete TrustTunnel Client${RESET}" # Delete TrustTunnel Client
                draw_line "$CYAN" "=" 40
                echo ""

                echo -e "${CYAN}🔍 Searching for clients ...${RESET}" # Searching for clients ...

                # List all systemd services that start with trusttunnel-
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-' | awk '{print $1}' | sed 's/.service$//')

                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No clients found.${RESET}" # No clients found.
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  # No return here, let the loop continue to show client management menu
                else
                  echo -e "${CYAN}📋 Please select a service to delete:${RESET}" # Please select a service to delete:
                  # Add "Back to previous menu" option
                  services+=("Back to previous menu")
                  select selected_service in "${services[@]}"; do
                    if [[ "$selected_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}" # Returning to previous menu...
                      echo ""
                      break 2 # Exit both the select and the outer while loop
                    elif [ -n "$selected_service" ]; then
                      service_file="/etc/systemd/system/${selected_service}.service"
                      echo -e "${YELLOW}🛑 Stopping $selected_service...${RESET}" # Stopping selected_service...
                      sudo systemctl stop "$selected_service" > /dev/null 2>&1
                      sudo systemctl disable "$selected_service" > /dev/null 2>&1
                      sudo rm -f "$service_file" > /dev/null 2>&1
                      sudo systemctl daemon-reload > /dev/null 2>&1
                      print_success "Client '$selected_service' deleted." # Client 'selected_service' deleted.
                      # Also remove any associated cron jobs for this specific client
                      echo -e "${CYAN}🧹 Removing cron jobs for '$selected_service'...${RESET}" # Removing cron jobs for 'selected_service'...
                      (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart for $selected_service$") | sudo crontab -
                      print_success "Cron jobs for '$selected_service' removed." # Cron jobs for '$selected_service' removed.
                      break # Exit the select loop
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}" # Invalid selection. Please enter a valid number.
                    fi
                  done
                  echo "" # Add a blank line after selection
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  read -p ""
                fi
              ;;
              5) # Schedule client restart
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}     ⏰ Schedule Client Restart${RESET}" # Schedule Client Restart
                draw_line "$CYAN" "=" 40
                echo ""

                echo -e "${CYAN}🔍 Searching for clients ...${RESET}" # Searching for clients ...

                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-' | awk '{print $1}' | sed 's/.service$//')

                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No clients found to schedule. Please add a client first.${RESET}" # No clients found to schedule. Please add a client first.
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}" # Press Enter to return to previous menu...
                  read -p ""
                else
                  echo -e "${CYAN}📋 Please select which client service to schedule for restart:${RESET}" # Please select which client service to schedule for restart:
                  # Add "Back to previous menu" option
                  services+=("Back to previous menu")
                  select selected_client_service in "${services[@]}"; do
                    if [[ "$selected_client_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}" # Returning to previous menu...
                      echo ""
                      break 2 # Exit both the select and the outer while loop
                    elif [ -n "$selected_client_service" ]; then
                      reset_timer "$selected_client_service" # Pass the selected client service name
                      break # Exit the select loop
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}" # Invalid selection. Please enter a valid number.
                    fi
                  done
                fi
                ;;
              6) # New case for deleting cron job in client menu
                delete_cron_job_action
              ;;
              7)
                echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
                break 2 # Break out of both inner while and outer case
              ;;
              *)
                echo -e "${RED}❌ Invalid option.${RESET}" # Invalid option.
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${RESET}" # Press Enter to continue...
                read -p ""
              ;;
            esac
          done
          ;;
        3)
          echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
          break # Changed from 'return' to 'break'
          ;;
        *)
          echo -e "${RED}❌ Invalid option.${RESET}" # Invalid option.
          echo ""
          echo -e "${YELLOW}Press Enter to continue...${RESET}" # Press Enable to continue...
          read -p ""
          ;;
      esac
      done
      ;;
      
    3)
    while true; do
      # Direct tunnel menu (copy of reverse tunnel with modified names)
      clear
      echo ""
      echo -e "${BOLD_GREEN}🚀 Direct Tunnel Configuration${RESET}"
      echo ""
      echo -e "  ${MAGENTA}1)${RESET} ${WHITE}🌍 Direct Server (Abroad)${RESET}"
      echo -e "  ${BLUE}2)${RESET} ${WHITE}🏠 Direct Client (Iran)${RESET}"
      echo -e "  ${WHITE}3)${RESET} ${WHITE}↩️  Back to Main Menu${RESET}"
      echo ""
      read -p "👉 Enter your choice (1-3): " direct_tunnel_choice
      echo ""

      case $direct_tunnel_choice in
        1)
          clear
          # Direct Server Management Sub-menu (copy of reverse server menu)
          while true; do
            clear
            echo ""
            draw_line "$GREEN" "=" 40
            echo -e "${CYAN}        🔧 Direct Server Management${RESET}"
            draw_line "$GREEN" "=" 40
            echo ""
            echo -e "  ${YELLOW}1)${RESET} ${WHITE}Add new direct server${RESET}"
            echo -e "  ${YELLOW}2)${RESET} ${WHITE}Show direct service logs${RESET}"
            echo -e "  ${YELLOW}3)${RESET} ${WHITE}Delete direct service${RESET}"
            echo -e "  ${YELLOW}4)${RESET} ${MAGENTA}Schedule direct server restart${RESET}"
            echo -e "  ${YELLOW}5)${RESET} ${RED}Delete scheduled restart${RESET}"
            echo -e "  ${YELLOW}6)${RESET} ${WHITE}Back to main menu${RESET}"
            echo ""
            draw_line "$GREEN" "-" 40
            echo -e "👉 ${CYAN}Your choice:${RESET} "
            read -p "" direct_srv_choice
            echo ""
            case $direct_srv_choice in
              1)
                add_new_direct_server_action
                ;;
              2)
                clear
                service_file="/etc/systemd/system/trusttunnel-direct.service"
                if [ -f "$service_file" ]; then
                  # Check if service exists in systemd
                  if systemctl list-unit-files --full --no-pager | grep -q "^trusttunnel-direct.service"; then
                    show_service_logs "trusttunnel-direct.service"
                  else
                    echo -e "${RED}❌ Service 'trusttunnel-direct.service' is not loaded in systemd.${RESET}"
                    echo -e "${YELLOW}Try reloading systemd daemon: sudo systemctl daemon-reload${RESET}"
                    echo ""
                    echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                    read -p ""
                  fi
                else
                  echo -e "${RED}❌ Service file 'trusttunnel-direct.service' not found at $service_file${RESET}"
                  echo -e "${YELLOW}The service may not be created yet. Create a direct server first.${RESET}"
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                fi
                ;;
              3)
                clear
                service_file="/etc/systemd/system/trusttunnel-direct.service"

                # Check if service is running or enabled
                if systemctl is-active --quiet trusttunnel-direct.service 2>/dev/null || systemctl is-enabled --quiet trusttunnel-direct.service 2>/dev/null; then
                  echo -e "${YELLOW}🛑 Stopping trusttunnel-direct.service...${RESET}"
                  sudo systemctl stop trusttunnel-direct.service > /dev/null 2>&1
                  echo -e "${YELLOW}🗑️ Disabling trusttunnel-direct.service...${RESET}"
                  sudo systemctl disable trusttunnel-direct.service > /dev/null 2>&1
                fi

                if [ -f "$service_file" ]; then
                  echo -e "${YELLOW}🗑️ Removing service file...${RESET}"
                  sudo rm -f "$service_file" > /dev/null 2>&1
                  sudo systemctl daemon-reload > /dev/null 2>&1
                  print_success "✅ Direct TrustTunnel server service deleted successfully."
                else
                  echo -e "${RED}❌ Service file not found at $service_file${RESET}"
                  echo -e "${YELLOW}Service may already be deleted or never created.${RESET}"
                fi

                echo ""
                echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                read -p ""
                ;;
              4)
                reset_timer "trusttunnel-direct"
                ;;
              5)
                delete_cron_job_action
                ;;
              6)
                echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
                break 2
                ;;
              *)
                echo -e "${RED}❌ Invalid option.${RESET}"
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${RESET}"
                read -p ""
                ;;
            esac
          done
          ;;
        2)
          clear
          while true; do
            clear
            echo ""
            echo -e "${BOLD_GREEN}📡 Direct Client Management${RESET}"
            echo ""
            echo -e "  ${WHITE}1)${RESET} ${WHITE}➕ Add New Direct Client${RESET}"
            echo -e "  ${CYAN}2)${RESET} ${WHITE}📋 View Direct Client Logs${RESET}"
            echo -e "  ${YELLOW}3)${RESET} ${WHITE}⚙️  Manage Direct Client Ports${RESET}"
            echo -e "  ${RED}4)${RESET} ${WHITE}🗑️  Delete Direct Client${RESET}"
            echo -e "  ${BLUE}5)${RESET} ${WHITE}⏰ Schedule Direct Restart${RESET}"
            echo -e "  ${MAGENTA}6)${RESET} ${WHITE}🗑️  Delete Scheduled Restart${RESET}"
            echo -e "  ${WHITE}7)${RESET} ${WHITE}↩️  Back to Previous Menu${RESET}"
            echo ""
            read -p "👉 Enter your choice (1-7): " direct_client_choice
            echo ""

            case $direct_client_choice in
              1)
                add_new_direct_client_action
                ;;
              2)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}        📊 Direct Client Logs${RESET}"
                draw_line "$CYAN" "=" 40
                echo ""
                echo -e "${CYAN}🔍 Searching for direct clients ...${RESET}"
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-direct-client-' | awk '{print $1}' | sed 's/.service$//')
                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No direct clients found.${RESET}"
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                else
                  echo -e "${CYAN}📋 Please select a service to see log:${RESET}"
                  services+=("Back to previous menu")
                  select selected_service in "${services[@]}"; do
                    if [[ "$selected_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}"
                      echo ""
                      break 2
                    elif [ -n "$selected_service" ]; then
                      show_service_logs "$selected_service"
                      break
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}"
                    fi
                  done
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                fi
                ;;
              3)
                manage_client_ports_action "direct"
                ;;
              4)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}        🗑️ Delete Direct Client${RESET}"
                draw_line "$CYAN" "=" 40
                echo ""
                echo -e "${CYAN}🔍 Searching for direct clients ...${RESET}"
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-direct-client-' | awk '{print $1}' | sed 's/.service$//')
                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No direct clients found.${RESET}"
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                else
                  echo -e "${CYAN}📋 Please select a service to delete:${RESET}"
                  services+=("Back to previous menu")
                  select selected_service in "${services[@]}"; do
                    if [[ "$selected_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}"
                      echo ""
                      break 2
                    elif [ -n "$selected_service" ]; then
                      service_file="/etc/systemd/system/${selected_service}.service"
                      echo -e "${YELLOW}🛑 Stopping $selected_service...${RESET}"
                      sudo systemctl stop "$selected_service" > /dev/null 2>&1
                      sudo systemctl disable "$selected_service" > /dev/null 2>&1
                      sudo rm -f "$service_file" > /dev/null 2>&1
                      sudo systemctl daemon-reload > /dev/null 2>&1
                      print_success "Direct client '$selected_service' deleted."
                      echo -e "${CYAN}🧹 Removing cron jobs for '$selected_service'...${RESET}"
                      (sudo crontab -l 2>/dev/null | grep -v "# TrustTunnel automated restart for $selected_service$") | sudo crontab -
                      print_success "Cron jobs for '$selected_service' removed."
                      break
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}"
                    fi
                  done
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                fi
                ;;
              4)
                clear
                echo ""
                draw_line "$CYAN" "=" 40
                echo -e "${CYAN}        ⏰ Schedule Direct Client Restart${RESET}"
                draw_line "$CYAN" "=" 40
                echo ""
                echo -e "${CYAN}🔍 Searching for direct clients ...${RESET}"
                mapfile -t services < <(systemctl list-units --type=service --all | grep 'trusttunnel-direct-client-' | awk '{print $1}' | sed 's/.service$//')
                if [ ${#services[@]} -eq 0 ]; then
                  echo -e "${RED}❌ No direct clients found to schedule. Please add a client first.${RESET}"
                  echo ""
                  echo -e "${YELLOW}Press Enter to return to previous menu...${RESET}"
                  read -p ""
                else
                  echo -e "${CYAN}📋 Please select which direct client service to schedule for restart:${RESET}"
                  services+=("Back to previous menu")
                  select selected_client_service in "${services[@]}"; do
                    if [[ "$selected_client_service" == "Back to previous menu" ]]; then
                      echo -e "${YELLOW}Returning to previous menu...${RESET}"
                      echo ""
                      break 2
                    elif [ -n "$selected_client_service" ]; then
                      reset_timer "$selected_client_service"
                      break
                    else
                      echo -e "${RED}⚠️ Invalid selection. Please enter a valid number.${RESET}"
                    fi
                  done
                fi
                ;;
              5)
                delete_cron_job_action
                ;;
              6)
                echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
                break 2
                ;;
              *)
                echo -e "${RED}❌ Invalid option.${RESET}"
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${RESET}"
                read -p ""
                ;;
            esac
          done
          ;;
        3)
          echo -e "${YELLOW}بازگشت به منوی اصلی...${RESET}" # Returning to main menu...
          break # Changed from 'return' to 'break'
          ;;
        *)
          echo -e "${RED}❌ Invalid option.${RESET}"
          echo ""
          echo -e "${YELLOW}Press Enter to continue...${RESET}"
          read -p ""
          ;;
      esac
      done
      ;;
    4) # New Certificate Management option
      certificate_management_menu
      ;;
    5) # Shifted from 4
      uninstall_trusttunnel_action
    ;;
    6) # Shifted from 5
      exit 0
    ;;
    *)
      echo -e "${RED}❌ Invalid choice. Exiting.${RESET}" # Invalid choice. Exiting.
      echo ""
      echo -e "${YELLOW}Press Enter to continue...${RESET}" # Press Enter to continue...
      read -p ""
    ;;
  esac
  echo ""
done
else
echo ""
  echo "🛑 Rust is not ready. Skipping the main menu." # Rust is not ready. Skipping the main menu.
fi

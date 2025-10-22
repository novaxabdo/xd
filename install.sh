#!/bin/bash

#================================================================================#
#                  n8n-Hosting-AIO Master Installer (V1.2)                       #
#                (c) 2024 - All-in-One Installation Script                       #
#================================================================================#

# --- Global Variables ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="/opt/n8n-aio"
SCRIPTS_SUBDIR="$SCRIPT_DIR/scripts"
CONFIG_DIR="/etc/n8n-aio"

# --- Root Check ---
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root. Please use 'sudo su' or log in as root.${NC}"
   exit 1
fi

# --- Initial Setup & Dependency Installation ---
echo -e "${GREEN}Starting n8n-Hosting-AIO Installation...${NC}"
echo -e "${YELLOW}Updating package lists and installing core dependencies...${NC}"
apt-get update > /dev/null 2>&1
apt-get install -y docker.io docker-compose nginx certbot python3-certbot-nginx git > /dev/null 2>&1

echo -e "${YELLOW}Enabling and starting system services...${NC}"
systemctl start docker && systemctl enable docker
systemctl start nginx && systemctl enable nginx

# --- Creating Directory Structure ---
echo -e "${YELLOW}Creating script and configuration directories...${NC}"
mkdir -p "$SCRIPT_DIR"
mkdir -p "$SCRIPTS_SUBDIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "/opt/n8n-hosting"

# --- Writing Script Files to Disk ---
echo -e "${YELLOW}Creating management scripts...${NC}"

# 1. Create helpers.sh
cat > "$SCRIPTS_SUBDIR/helpers.sh" << 'EOF'
#!/bin/bash
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'
export HOSTING_DIR="/opt/n8n-hosting"
export CONFIG_DIR="/etc/n8n-aio"
export DOMAIN_FILE="$CONFIG_DIR/domain.conf"
export SCRIPT_DIR="/opt/n8n-aio/scripts"
EOF

# 2. Create n8n-menu
cat > "$SCRIPTS_SUBDIR/n8n-menu" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/helpers.sh"
mkdir -p "$HOSTING_DIR"
mkdir -p "$CONFIG_DIR"
get_server_info() {
    OS=$(hostnamectl | grep "Operating System" | cut -d ' ' -f5-)
    CORES=$(nproc)
    UPTIME=$(uptime -p)
    DOMAIN=$(cat $DOMAIN_FILE 2>/dev/null || echo "not-set")
    RAM_USAGE=$(free -m | awk 'NR==2{printf "%.0fMi", $3}')
    TOTAL_RAM=$(free -m | awk 'NR==2{printf "%.0fMi", $2}')
    CLIENT_COUNT=$(find $HOSTING_DIR -maxdepth 1 -mindepth 1 -type d | wc -l 2>/dev/null || echo "0")
}
show_menu() {
    get_server_info; clear
    echo -e "    ${BLUE}●  n8n-Hosting-AIO (V1.2)  ●${NC}"
    echo " ┌──────────────────────────────────────────────────┐"
    echo " │ OS      : $OS"
    echo " │ Uptime  : $UPTIME"
    echo " │ Domain  : $DOMAIN"
    echo " ├──────────────────────────────────────────────────┤"
    echo " │ RAM Usage  : $RAM_USAGE / $TOTAL_RAM"
    echo " │ Accounts: n8n Clients ($CLIENT_COUNT)"
    echo " │ Services: Docker (ON) | Nginx (ON)"
    echo " └──────────────────────────────────────────────────┘"
    echo -e "    ${YELLOW}● [       N8N HOSTING MENU       ] ●${NC}"
    echo -e "\n 1. Add New n8n Client\n 2. Remove an n8n Client\n 3. List All n8n Clients\n 4. Set/Change Main Domain\n 0. Exit\n"
}
if [ ! -f "$DOMAIN_FILE" ]; then
    clear
    echo -e "${YELLOW}First-Time Setup: Please enter your main domain name (e.g., myhosting.com):${NC}"
    read -p "Domain: " MAIN_DOMAIN
    echo "$MAIN_DOMAIN" > "$DOMAIN_FILE"
    echo -e "${GREEN}Domain name saved successfully!${NC}"; sleep 2
fi
while true; do
    show_menu
    read -p " SELECT OPTION FROM 0-4 : " choice
    case $choice in
        1) bash "$SCRIPT_DIR/add-client.sh"; read -p "Press [Enter] to return..." ;;
        2) bash "$SCRIPT_DIR/remove-client.sh"; read -p "Press [Enter] to return..." ;;
        3) bash "$SCRIPT_DIR/list-clients.sh"; read -p "Press [Enter] to return..." ;;
        4)
            echo "Enter new main domain:"; read NEW_DOMAIN
            echo "$NEW_DOMAIN" > "$DOMAIN_FILE"; echo -e "${GREEN}Domain updated.${NC}"; sleep 2 ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; sleep 1 ;;
    esac
done
EOF

# 3. Create add-client.sh
cat > "$SCRIPTS_SUBDIR/add-client.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/helpers.sh"
clear; MAIN_DOMAIN=$(cat $DOMAIN_FILE); START_PORT=5679
echo -e "${YELLOW}Enter a name for the new client (e.g., 'acme'):${NC}"
read -p "Client Name: " CLIENT_NAME
CLIENT_DIR="$HOSTING_DIR/$CLIENT_NAME"; CLIENT_DOMAIN="$CLIENT_NAME.$MAIN_DOMAIN"
if [ -z "$CLIENT_NAME" ] || [ -d "$CLIENT_DIR" ]; then echo -e "${RED}Error: Client name is invalid or exists!${NC}"; exit 1; fi
LAST_PORT=$(find $HOSTING_DIR -name 'docker-compose.yml' -exec grep -oP '127.0.0.1:\K[0-9]+' {} + 2>/dev/null | sort -rn | head -n 1)
PORT=$(( ${LAST_PORT:-$START_PORT} + 1 ))
echo -e "\n${GREEN}Creating environment for '$CLIENT_NAME'...${NC}"
mkdir -p "$CLIENT_DIR/n8n_data"
cat > "$CLIENT_DIR/docker-compose.yml" << EOL
version: '3.7'
services:
  n8n: {image: n8nio/n8n, restart: always, ports: ["127.0.0.1:${PORT}:5678"], environment: {N8N_HOST: ${CLIENT_DOMAIN}, N8N_PROTOCOL: https, WEBHOOK_URL: "https://${CLIENT_DOMAIN}/"}, volumes: ['./n8n_data:/home/node/.n8n']}
EOL
(cd $CLIENT_DIR && docker-compose up -d)
cat > "/etc/nginx/sites-available/$CLIENT_DOMAIN" << EOL
server { listen 80; server_name ${CLIENT_DOMAIN}; location / { proxy_pass http://127.0.0.1:${PORT}; proxy_set_header Connection ''; proxy_http_version 1.1; proxy_set_header Host \$host; } }
EOL
ln -sf "/etc/nginx/sites-available/$CLIENT_DOMAIN" "/etc/nginx/sites-enabled/"
if ! nginx -t > /dev/null 2>&1; then echo -e "${RED}Nginx config error! Cleaning up...${NC}"; rm -f "/etc/nginx/sites-enabled/$CLIENT_DOMAIN" /etc/nginx/sites-available/$CLIENT_DOMAIN; (cd $CLIENT_DIR && docker-compose down -v); rm -rf $CLIENT_DIR; exit 1; fi
systemctl reload nginx
certbot --nginx -d $CLIENT_DOMAIN --non-interactive --agree-tos -m admin@$MAIN_DOMAIN --redirect
echo -e "\n${GREEN}✅ Client '$CLIENT_NAME' created!${NC}\n   URL: ${GREEN}https://${CLIENT_DOMAIN}${NC}\n"
EOF

# 4. Create remove-client.sh
cat > "$SCRIPTS_SUBDIR/remove-client.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/helpers.sh"
clear; MAIN_DOMAIN=$(cat $DOMAIN_FILE)
echo -e "${YELLOW}Enter the name of the client to remove:${NC}"
read -p "Client Name: " CLIENT_NAME
CLIENT_DIR="$HOSTING_DIR/$CLIENT_NAME"; CLIENT_DOMAIN="$CLIENT_NAME.$MAIN_DOMAIN"
if [ -z "$CLIENT_NAME" ] || [ ! -d "$CLIENT_DIR" ]; then echo -e "${RED}Error: Client '$CLIENT_NAME' not found!${NC}"; exit 1; fi
echo -e "${RED}Permanently delete '$CLIENT_NAME' and all data? (y/n)${NC}"
read -p "Confirm: " CONFIRM
if [ "$CONFIRM" != "y" ]; then echo "Aborted."; exit 0; fi
(cd $CLIENT_DIR && docker-compose down -v)
rm -f "/etc/nginx/sites-available/$CLIENT_DOMAIN" "/etc/nginx/sites-enabled/$CLIENT_DOMAIN"
systemctl reload nginx
certbot delete --cert-name $CLIENT_DOMAIN --non-interactive
rm -rf "$CLIENT_DIR"
echo -e "${GREEN}✅ Client '$CLIENT_NAME' has been removed.${NC}\n"
EOF

# 5. Create list-clients.sh
cat > "$SCRIPTS_SUBDIR/list-clients.sh" << 'EOF'
#!/bin/bash
source "$(dirname "$0")/helpers.sh"
clear; MAIN_DOMAIN=$(cat $DOMAIN_FILE)
echo -e "${GREEN}--- List of Active n8n Clients ---${NC}"
if [ -z "$(ls -A $HOSTING_DIR 2>/dev/null)" ]; then echo "No clients found."; else
for d in $HOSTING_DIR/*/; do client_name=$(basename "$d"); echo " - ${client_name} (URL: https://${client_name}.${MAIN_DOMAIN})"; done; fi
echo -e "-----------------------------------\n"
EOF

# --- Finalizing Setup ---
echo -e "${YELLOW}Setting permissions and creating system command...${NC}"
chmod -R +x "$SCRIPTS_SUBDIR"
ln -sf "$SCRIPTS_SUBDIR/n8n-menu" /usr/local/bin/n8n-menu

# --- Completion Message ---
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  Installation Complete!                             ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "You can now manage your n8n hosting platform by running:"
echo -e "${YELLOW}  n8n-menu${NC}"
echo ""
echo "The script will now run the first-time setup..."
sleep 3

# --- Run the menu for the first time ---
exec n8n-menu

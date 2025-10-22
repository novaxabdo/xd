#!/bin/bash

#================================================================================#
#                         n8n-Hosting-AIO Installer                              #
#================================================================================#

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Root Check ---
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}This script must be run as root. Please use 'sudo su' or log in as root.${NC}"
   exit 1
fi

echo -e "${GREEN}Starting n8n-Hosting-AIO Installation...${NC}"

# --- Install Dependencies ---
echo -e "${YELLOW}Updating package lists and installing core dependencies...${NC}"
apt-get update
apt-get install -y docker.io docker-compose nginx certbot python3-certbot-nginx git tmux

# --- Enable Services ---
systemctl start docker && systemctl enable docker
systemctl start nginx && systemctl enable nginx

# --- Clone the main script repository ---
# The repo is cloned into /opt/n8n-aio, which will be the script's home.
SCRIPT_DIR="/opt/n8n-aio"
if [ -d "$SCRIPT_DIR" ]; then
    echo -e "${YELLOW}Existing installation found. The installer will not re-clone the repository.${NC}"
else
    # This assumes the installer itself is being run from a temporary location
    # and the main files are in the same directory or need to be cloned.
    # We will assume the install script is located inside the cloned repo.
    echo -e "${YELLOW}This installer needs to be inside the cloned git repository.${NC}"
    echo -e "${YELLOW}Please run the git clone command first from the README.${NC}"
    exit 1
fi

# --- Create Symlink for the main menu ---
echo -e "${YELLOW}Creating system-wide command 'n8n-menu'...${NC}"
ln -sf "$SCRIPT_DIR/scripts/n8n-menu" /usr/local/bin/n8n-menu

# --- Set Permissions for all scripts ---
chmod +x $SCRIPT_DIR/scripts/*.sh
chmod +x $SCRIPT_DIR/scripts/n8n-menu

# --- Final Message ---
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  Installation Complete!                             ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo -e "You can now manage your n8n hosting platform by running:"
echo -e "${YELLOW}  n8n-menu${NC}"
echo ""
echo "The script will run a first-time setup to ask for your main domain."

# --- Run First-Time Setup ---
exec n8n-menu

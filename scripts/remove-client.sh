#!/bin/bash

source "$(dirname "$0")/helpers.sh"

clear
MAIN_DOMAIN=$(cat $DOMAIN_FILE)

echo -e "${YELLOW}Enter the name of the client to remove:${NC}"
read -p "Client Name: " CLIENT_NAME

CLIENT_DIR="$HOSTING_DIR/$CLIENT_NAME"
CLIENT_DOMAIN="$CLIENT_NAME.$MAIN_DOMAIN"

if [ -z "$CLIENT_NAME" ] || [ ! -d "$CLIENT_DIR" ]; then
    echo -e "${RED}Error: Client '$CLIENT_NAME' not found!${NC}"
    exit 1
fi

echo -e "${RED}Are you sure you want to permanently delete client '$CLIENT_NAME' and all their data? (y/n)${NC}"
read -p "Confirm: " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo "[INFO] Stopping and removing n8n docker containers..."
(cd $CLIENT_DIR && docker-compose down -v)

echo "[INFO] Removing Nginx configuration..."
rm -f "/etc/nginx/sites-available/$CLIENT_DOMAIN"
rm -f "/etc/nginx/sites-enabled/$CLIENT_DOMAIN"
systemctl reload nginx

echo "[INFO] Deleting SSL certificate..."
certbot delete --cert-name $CLIENT_DOMAIN --non-interactive

echo "[INFO] Deleting client data directory..."
rm -rf "$CLIENT_DIR"

echo -e "${GREEN}✅ Client '$CLIENT_NAME' has been successfully removed.${NC}\n"

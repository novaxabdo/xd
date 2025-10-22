#!/bin/bash

source "$(dirname "$0")/helpers.sh"

clear
MAIN_DOMAIN=$(cat $DOMAIN_FILE)
START_PORT=5679

echo -e "${YELLOW}Enter a name for the new client (lowercase, no spaces, e.g., 'acme'):${NC}"
read -p "Client Name: " CLIENT_NAME

CLIENT_DIR="$HOSTING_DIR/$CLIENT_NAME"
CLIENT_DOMAIN="$CLIENT_NAME.$MAIN_DOMAIN"

if [ -z "$CLIENT_NAME" ] || [ -d "$CLIENT_DIR" ]; then
    echo -e "${RED}Error: Client name is invalid or already exists!${NC}"
    exit 1
fi

LAST_PORT=$(find $HOSTING_DIR -name 'docker-compose.yml' -exec grep -oP '127.0.0.1:\K[0-9]+' {} + 2>/dev/null | sort -rn | head -n 1)
PORT=$(( ${LAST_PORT:-$START_PORT} + 1 ))

echo -e "\n${GREEN}Creating environment for client '$CLIENT_NAME' at $CLIENT_DOMAIN...${NC}"

mkdir -p "$CLIENT_DIR/n8n_data"
cat > "$CLIENT_DIR/docker-compose.yml" << EOL
version: '3.7'
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports: ["127.0.0.1:${PORT}:5678"]
    environment:
      - N8N_HOST=${CLIENT_DOMAIN}
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://${CLIENT_DOMAIN}/
      - GENERIC_TIMEZONE=Etc/UTC
    volumes:
      - ./n8n_data:/home/node/.n8n
EOL

echo "[INFO] Starting n8n instance on internal port ${PORT}..."
(cd $CLIENT_DIR && docker-compose up -d)

echo "[INFO] Configuring web server (Nginx)..."
cat > "/etc/nginx/sites-available/$CLIENT_DOMAIN" << EOL
server {
    listen 80;
    server_name ${CLIENT_DOMAIN};
    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL
ln -sf "/etc/nginx/sites-available/$CLIENT_DOMAIN" "/etc/nginx/sites-enabled/"

if ! nginx -t; then
    echo -e "${RED}Nginx configuration error! Cleaning up...${NC}"
    rm -f "/etc/nginx/sites-enabled/$CLIENT_DOMAIN"
    rm -f "/etc/nginx/sites-available/$CLIENT_DOMAIN"
    (cd $CLIENT_DIR && docker-compose down -v)
    rm -rf $CLIENT_DIR
    exit 1
fi
systemctl reload nginx

echo "[INFO] Requesting SSL Certificate from Let's Encrypt..."
certbot --nginx -d $CLIENT_DOMAIN --non-interactive --agree-tos -m admin@$MAIN_DOMAIN --redirect

echo -e "\n${GREEN}✅ Client '$CLIENT_NAME' has been successfully created!${NC}"
echo -e "   URL: ${GREEN}https://${CLIENT_DOMAIN}${NC}\n"

#!/bin/bash

source "$(dirname "$0")/helpers.sh"

clear
MAIN_DOMAIN=$(cat $DOMAIN_FILE)

echo -e "${GREEN}--- List of Active n8n Clients ---${NC}"
if [ -z "$(ls -A $HOSTING_DIR 2>/dev/null)" ]; then
   echo "No clients found."
else
    for d in $HOSTING_DIR/*/; do
        client_name=$(basename "$d")
        echo " - ${client_name} (URL: https://${client_name}.${MAIN_DOMAIN})"
    done
fi
echo -e "-----------------------------------\n"

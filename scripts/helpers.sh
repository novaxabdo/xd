#!/bin/bash

# This file contains shared variables and functions for the n8n-aio scripts.

# --- Colors ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# --- Main Directories ---
# Using /etc for configuration is a standard Linux practice.
export HOSTING_DIR="/opt/n8n-hosting"
export CONFIG_DIR="/etc/n8n-aio"
export DOMAIN_FILE="$CONFIG_DIR/domain.conf"
export SCRIPT_DIR="/opt/n8n-aio/scripts"

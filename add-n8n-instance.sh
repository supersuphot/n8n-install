#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Add Another n8n Instance ===${NC}"

# Collect user input
get_user_input() {
    echo -e "\n${GREEN}Please provide the following information for the new n8n instance:${NC}"
    
    read -p "Domain name (e.g., example.com): " DOMAIN_NAME
    read -p "Subdomain for n8n (e.g., workflow2): " SUBDOMAIN
    read -p "Email address for Let's Encrypt: " EMAIL

    # Generate a list of all available timezones
    TIMEZONES=( $(timedatectl list-timezones) )

    # Display timezone options
    echo "Available timezones:" 
    for i in "${!TIMEZONES[@]}"; do
        echo "$((i+1)). ${TIMEZONES[$i]}"
    done

    # Prompt user to select a timezone
    read -p "Select a timezone by number (default: 1): " TIMEZONE_SELECTION
    if [[ -z "${TIMEZONE_SELECTION}" || ! "${TIMEZONE_SELECTION}" =~ ^[0-9]+$ || ${TIMEZONE_SELECTION} -lt 1 || ${TIMEZONE_SELECTION} -gt ${#TIMEZONES[@]} ]]; then
        TIMEZONE="${TIMEZONES[0]}"
    else
        TIMEZONE="${TIMEZONES[$((TIMEZONE_SELECTION-1))]}"
    fi

    # Full domain for n8n
    FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN_NAME}"

    echo -e "\n${GREEN}Summary:${NC}"
    echo "Domain name: ${DOMAIN_NAME}"
    echo "n8n will be available at: ${FULL_DOMAIN}"
    echo "Let's Encrypt email: ${EMAIL}"
    echo "Timezone: ${TIMEZONE}"

    read -p "Is this correct? (y/n): " CONFIRM
    if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
        get_user_input
    fi
}

# Create Docker Compose configuration for the new instance
create_docker_compose() {
    echo -e "\n${GREEN}Creating Docker Compose configuration for ${FULL_DOMAIN}...${NC}"

    INSTANCE_DIR="/opt/n8n/${SUBDOMAIN}"
    sudo mkdir -p "${INSTANCE_DIR}/data"
    sudo chown -R 1000:1000 "${INSTANCE_DIR}/data"
    sudo chmod -R 755 "${INSTANCE_DIR}/data"

    cat > "${INSTANCE_DIR}/docker-compose.yml" << EOF
version: '3'

services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "${RANDOM_PORT}:5678"
    environment:
      - N8N_HOST=${FULL_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - TZ=${TIMEZONE}
    volumes:
      - ${INSTANCE_DIR}/data:/home/node/.n8n
EOF
}

# Update Caddy configuration
update_caddy_config() {
    echo -e "\n${GREEN}Updating Caddy configuration...${NC}"

    cat >> /etc/caddy/Caddyfile << EOF
${FULL_DOMAIN} {
    reverse_proxy localhost:${RANDOM_PORT}

    tls ${EMAIL}

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "no-referrer-when-downgrade"
    }

    log {
        output file /var/log/caddy/${FULL_DOMAIN}.log
    }
}
EOF

    sudo systemctl reload caddy
}

# Start the new n8n instance
start_instance() {
    echo -e "\n${GREEN}Starting the new n8n instance...${NC}"

    cd "/opt/n8n/${SUBDOMAIN}"
    sudo docker-compose up -d

    echo -e "\n${GREEN}New n8n instance is now running at: https://${FULL_DOMAIN}${NC}"
}

# Main execution
main() {
    get_user_input
    RANDOM_PORT=$((RANDOM % 10000 + 10000)) # Generate a random port between 10000 and 20000
    create_docker_compose
    update_caddy_config
    start_instance
}

# Start the script
main
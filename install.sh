#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== n8n Docker with Caddy Installation Script ===${NC}"
echo "This script will set up n8n with Docker and Caddy as a reverse proxy."

# Collect user input
get_user_input() {
    echo -e "\n${GREEN}Please provide the following information:${NC}"
    
    read -p "Subdomain for n8n (e.g., workflow): " SUBDOMAIN
    read -p "Domain name (e.g., example.com): " DOMAIN_NAME
    
    # Email validation loop
    while true; do
        read -p "Email address for Let's Encrypt: " EMAIL
        
        # Check email format using regex
        if [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "${BLUE}Invalid email format. Please enter a valid email address.${NC}"
            continue
        fi
        break
    done

    # Generate a list of all available timezones grouped by region
    REGIONS=( $(timedatectl list-timezones | cut -d'/' -f1 | sort -u) )

    # Display region options in a compact format
    echo "Available regions:"
    for i in "${!REGIONS[@]}"; do
        printf "%3d. %-20s" "$((i+1))" "${REGIONS[$i]}"
        if (( (i+1) % 4 == 0 )); then
            echo ""
        fi
    done
    echo ""

    # Prompt user to select a region
    read -p "Select a region by number (default: 1): " REGION_SELECTION
    if [[ -z "${REGION_SELECTION}" || ! "${REGION_SELECTION}" =~ ^[0-9]+$ || ${REGION_SELECTION} -lt 1 || ${REGION_SELECTION} -gt ${#REGIONS[@]} ]]; then
        REGION="${REGIONS[0]}"
    else
        REGION="${REGIONS[$((REGION_SELECTION-1))]}"
    fi

    # Generate a list of timezones for the selected region
    TIMEZONES=( $(timedatectl list-timezones | grep "^${REGION}/") )

    # Display timezone options in a compact format
    echo "Available timezones in ${REGION}:"
    for i in "${!TIMEZONES[@]}"; do
        printf "%3d. %-20s" "$((i+1))" "${TIMEZONES[$i]}"
        if (( (i+1) % 4 == 0 )); then
            echo ""
        fi
    done
    echo ""

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

# Install dependencies
install_dependencies() {
    echo -e "\n${GREEN}Installing dependencies...${NC}"
    
    # Update package lists
    sudo apt update
    
    # Install required packages
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    else
        echo "Docker is already installed."
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        echo "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose is already installed."
    fi
    
    # Install Caddy
    echo "Installing Caddy..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install -y caddy
}

# Create necessary directories
create_directories() {
    echo -e "\n${GREEN}Creating directories...${NC}"
    
    sudo mkdir -p /opt/n8n/data
    sudo mkdir -p /opt/caddy/data
    sudo mkdir -p /opt/caddy/config

    # Set ownership for n8n data directory
    sudo chown -R 1000:1000 /opt/n8n/data
}

# Create Docker Compose configuration
create_docker_compose() {
    echo -e "\n${GREEN}Creating Docker Compose configuration...${NC}"
    
    cat > /opt/n8n/docker-compose.yml << EOF
version: '3'

services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=${FULL_DOMAIN}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - GENERIC_TIMEZONE=${TIMEZONE}
      - WEBHOOK_URL=https://${FULL_DOMAIN}/
      # Uncomment the following line to enable basic auth
      # - N8N_BASIC_AUTH_ACTIVE=true
      # - N8N_BASIC_AUTH_USER=admin
      # - N8N_BASIC_AUTH_PASSWORD=password
    volumes:
      - /opt/n8n/data:/home/node/.n8n
EOF
}

# Create Caddy configuration
create_caddy_config() {
    echo -e "\n${GREEN}Creating Caddy configuration...${NC}"
    
    # Create Caddyfile
    cat > /etc/caddy/Caddyfile << EOF
${FULL_DOMAIN} {
    reverse_proxy localhost:5678
    
    tls ${EMAIL}
    
    # Add security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "no-referrer-when-downgrade"
    }
    
    # Enable logging
    log {
        output file /var/log/caddy/${FULL_DOMAIN}.log
    }
}
EOF
}

# Start services
start_services() {
    echo -e "\n${GREEN}Starting services...${NC}"
    
    # Start n8n with Docker Compose
    cd /opt/n8n
    sudo docker-compose up -d
    
    # Reload Caddy to apply new configuration
    sudo systemctl reload caddy
    
    echo -e "\n${GREEN}Services started!${NC}"
    echo -e "\n${BLUE}Your n8n instance will be available at: https://${FULL_DOMAIN}${NC}"
    echo -e "It may take a few minutes for Let's Encrypt to issue your certificate."
}

# Main execution
main() {
    get_user_input
    install_dependencies
    create_directories
    create_docker_compose
    create_caddy_config
    start_services
}

# Start the script
main
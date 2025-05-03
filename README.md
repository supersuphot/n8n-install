# n8n Installation and Management Scripts

This repository contains scripts to set up and manage n8n instances using Docker and Caddy as a reverse proxy. These scripts are designed to work on a DigitalOcean droplet running Ubuntu 24.04 (LTS) or later.

## Prerequisites

Before using these scripts, ensure the following:

1. You have a DigitalOcean droplet running Ubuntu 24.04 (LTS) or later.
2. You have SSH access to the droplet.
3. The droplet has at least 1GB of RAM (recommended 2GB or above).
4. You have a domain name and access to its DNS settings.

## Scripts Overview

### 1. `install.sh`
This script sets up the initial n8n instance with Docker and Caddy.

### 2. `add-n8n-instance.sh`
This script allows you to add additional n8n instances on the same server.

## Usage

### Step 1: Connect to Your Droplet

1. Open a terminal on your local machine.
2. Connect to your droplet using SSH:
   ```bash
   ssh root@<your-droplet-ip>
   ```

### Step 2: Clone the Repository

1. Install Git if not already installed:
   ```bash
   sudo apt update && sudo apt install -y git
   ```
2. Clone this repository:
   ```bash
   git clone <repository-url>
   cd n8n-install
   ```

### Step 2.1: Download the Script Directly (Alternative)

If you prefer not to clone the repository, you can download the `install.sh` script directly using `wget`:
```bash
wget https://raw.githubusercontent.com/supersuphot/n8n-install/refs/heads/main/install.sh
chmod +x install.sh
./install.sh
```

### Step 3: Run the Installation Script

1. Make the script executable:
   ```bash
   chmod +x install.sh
   ```
2. Run the script:
   ```bash
   ./install.sh
   ```
3. Follow the prompts to provide your domain name, subdomain, email address, and timezone.

### Step 4: Add Additional n8n Instances (Optional)

1. Make the script executable:
   ```bash
   chmod +x add-n8n-instance.sh
   ```
2. Run the script:
   ```bash
   ./add-n8n-instance.sh
   ```
3. Follow the prompts to provide details for the new instance.

## DNS Configuration

For each n8n instance, create a DNS A record pointing the subdomain to your droplet's IP address. For example:

| Subdomain   | Type | Value          |
|-------------|------|----------------|
| workflow    | A    | <droplet-ip>   |
| workflow2   | A    | <droplet-ip>   |

## Accessing n8n

Once the scripts complete, you can access your n8n instances at:

- `https://<subdomain>.<domain>`

It may take a few minutes for Let's Encrypt to issue SSL certificates.

## Logs and Troubleshooting

- Caddy logs are stored in `/var/log/caddy/`.
- Use `docker ps` to check running containers.
- Use `docker logs <container-id>` to view logs for a specific container.

## Uninstallation

To remove an n8n instance:

1. Stop the Docker container:
   ```bash
   cd /opt/n8n/<subdomain>
   sudo docker-compose down
   ```
2. Remove the instance directory:
   ```bash
   sudo rm -rf /opt/n8n/<subdomain>
   ```
3. Remove the corresponding entry from `/etc/caddy/Caddyfile` and reload Caddy:
   ```bash
   sudo systemctl reload caddy
   ```
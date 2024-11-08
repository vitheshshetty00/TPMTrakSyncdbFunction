#!/bin/bash

# Configuration variables
CONTAINER_NAME="app-publish"
BLOB_NAME="publish.zip"
SAS_TOKEN="sp=r&st=2024-10-05T20:23:02Z&se=2025-11-06T12:23:02Z&spr=https&sv=2022-11-02&sr=b&sig=5uV96BPJYCF098yrHSYgVdC3oSOC1f%2Bw9MdQt4%2BOQKg%3D"
APP_DIR="/var/www/tpmtrak"
SERVICE_NAME="tpmtrak.service"
NGINX_CONF="/etc/nginx/sites-available/default"
DOTNET_APP_PORT="5000"
DOMAIN="4.186.10.255"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Start deployment
log "Starting TPMTrak App Deployment"

# Update package list
sudo apt update

# Install .NET SDK 8.0
log "Installing .NET SDK 8.0..."
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt update
sudo apt install -y dotnet-sdk-8.0

# Install required utilities
log "Installing required utilities..."
sudo apt install -y unzip wget nginx || {
    log "Failed to install required utilities."
    exit 1
}

# Set up application directory
log "Setting up application directory..."
sudo mkdir -p "$APP_DIR"
sudo chown -R azureuser:azureuser $APP_DIR
sudo chmod -R 755 $APP_DIR

if systemctl is-active --quiet $SERVICE_NAME; then
    log "Stopping existing service..."
    sudo systemctl stop $SERVICE_NAME
    log "Service stopped successfully"
else
    log "Service was not running"
fi

# Check and remove existing publish directory
if [ -d "$APP_DIR/publish" ]; then
    log "Removing existing publish directory..."
    sudo rm -rf "$APP_DIR/publish"
    log "Publish directory removed successfully"
else
    log "No existing publish directory found"
fi

# Check and remove existing zip file
if [ -f "$APP_DIR/publish.zip" ]; then
    log "Removing existing zip file..."
    sudo rm -f "$APP_DIR/publish.zip"
    log "Zip file removed successfully"
else
    log "No existing zip file found"
fi

log "Cleanup completed successfully!"

# Download and extract application
log "Downloading the TPMTRAK app from Azure Blob Storage..."
wget -O "$APP_DIR/publish.zip" "https://tpmtrakstorage.blob.core.windows.net/$CONTAINER_NAME/$BLOB_NAME?$SAS_TOKEN" || {
    log "Failed to download application files."
    exit 1
}

log "Unzipping the downloaded file to $APP_DIR..."
unzip -o "$APP_DIR/publish.zip" -d "$APP_DIR" || {
    log "Failed to unzip the application files."
    exit 1
}

# Remove the zip file after extraction
log "Removing zip file..."
rm -f "$APP_DIR/publish.zip"

# Create systemd service
log "Creating systemd service file for $SERVICE_NAME..."
cat <<EOF | sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null
[Unit]
Description=TPM-Trak Blazor Application
After=network.target

[Service]
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/dotnet $APP_DIR/publish/TPMTrakApplication.dll
Restart=always
RestartSec=10
SyslogIdentifier=dotnet-tpmtrak
User=azureuser
Environment=ASPNETCORE_ENVIRONMENT=Development
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

# Configure systemd service
log "Reloading systemd to apply the new service..."
sudo systemctl daemon-reload

log "Enabling and starting the $SERVICE_NAME service..."
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME
sudo systemctl status $SERVICE_NAME

# Configure Nginx
log "Configuring Nginx to forward requests to the .NET app..."
cat <<EOF | sudo tee $NGINX_CONF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:$DOTNET_APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # Development-specific settings
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;

        # Disable caching for development
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires 0;
    }
    location /css {
        root /var/www/tpmtrak/publish/wwwroot;
    }

    location /js {
        root /var/www/tpmtrak/publish/wwwroot;
    }
}
EOF

# Create symbolic link for Nginx configuration
log "Creating symbolic link for Nginx configuration..."
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

# Verify and restart Nginx
log "Checking Nginx configuration..."
sudo nginx -t
if [ $? -eq 0 ]; then
    log "Nginx configuration is valid!"
else
    log "Nginx configuration test failed. Please check for errors."
    exit 1
fi

log "Restarting Nginx..."
sudo systemctl restart nginx

# Verify services
log "Verifying Nginx status..."
sudo systemctl status nginx | grep "active (running)"

log "Verifying the service status..."
sudo systemctl status $SERVICE_NAME | grep "active (running)"

log "Setup completed successfully!"
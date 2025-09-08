#!/bin/bash

set -e 

# ------------------------- Setup SSH key for Jenkins ------------------------- #
# Ensure Jenkins' public key is added so pipeline can SSH without password
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDHD1QbJidykLDMx3rbxs3thJ/cauoP2DBc1Qh8VqH7oipGtgSdYWou00+3gpXxdyAbYWxcTw3iRw5+y40Xwp1tZxXAyxa6/HxRSLRTTA2+j3JXhJTOY2mFEIJ16GgIPcsIjMsZMb9MCWg3GjXw+bQE27kAGHjQ78u6HUywKVBm6hOd4yJK7SbcvyE1UDdIVG5YCXY6Nviq2SBuiKrOZ+1DotPfwNugZRl8XDDPzgXC0sC3ne8qzCGu1a3pQP6RTn879bJyjeZnkemAHCjMVYtAFXF7o2W6H16dFqyICRQeoWlAn53ktR5C/wI+W6cH/CtbdvaDRL6vfSXVuuHU4QloWSRvs9wjuu74cAzB9+ZOOwbLANOBaLl4/YvGQlM1d7HYf0bbuMuyPmdKI8gvJD1eKIF+x6nMc0mNcWluJGLW4QO5DJH613NB71JULsjbsDhuSQOn5BYeVyj7ySyHnmbnTrKRVJRbf1PgJq9vNPvEoS7xgw6jeSbr6m+cMFcUpaTvFILGCD6+Y1iSTC8Mi/Kg/FjRjHB9KsW5K5tdpw57hytTvmi1kyE6+UruwhuoBRdd5/avXa0eJyb0M1Z6KukFPDN6qNh830OogO/C/Ut+Y63VF9jhe55AjRC1moVVcZj8yCh9SYrsnJRAViPObvmWnMe/6w7mZIA+28g8faedww== jenkins@appvm"   # <-- replace with content of /var/lib/jenkins/.ssh/app_vm_key.pub

mkdir -p /home/vagrant/.ssh
echo "$PUB_KEY" >> /home/vagrant/.ssh/authorized_keys


# ------------------------- Install Required Packages ------------------------- #
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get update -y
sudo apt-get install -y nginx unzip nodejs


# ----------------------------------------------- Frontend Setup ---------------------------------------------- #

# Remove default Nginx config
sudo rm -f /etc/nginx/sites-enabled/default 


# Create frontend directory for staging/prod
sudo mkdir -p /var/www/my-app-staging
sudo mkdir -p /var/www/my-app-prod

# Frontend files — owned by Nginx so it can read/serve without permission issues
sudo chown -R www-data:www-data /var/www/my-app-staging
sudo chown -R www-data:www-data /var/www/my-app-prod


# Place a temporary placeholder page (will be replaced by React build later)
echo "<h1>Waiting for Staging App</h1>" | sudo tee /var/www/my-app-staging/index.html
echo "<h1>Waiting for Production App</h1>" | sudo tee /var/www/my-app-prod/index.html


# Nginx configuration for frontend + API proxy
# location / {}     - Handle all frontend routes
# location /api/ {} - Forward API requests to the backend (Express server on port 3001)

# Staging frontend
cat << EOF | sudo tee /etc/nginx/sites-available/my-app-staging
server {
    listen 81;
    server_name 192.168.57.11;

    root /var/www/my-app-staging;
    index index.html;
    
    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3001/;
    }
}
EOF


# Prod frontend
cat << EOF | sudo tee /etc/nginx/sites-available/my-app-prod
server {
    listen 80;
    server_name 192.168.57.11;

    root /var/www/my-app-prod;
    index index.html;
    
    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:3002/;
    }
}
EOF


# Enable our custom site by linking it into Nginx's "sites-enabled"
sudo ln -sf /etc/nginx/sites-available/my-app-staging /etc/nginx/sites-enabled/my-app-staging
sudo ln -sf /etc/nginx/sites-available/my-app-prod /etc/nginx/sites-enabled/my-app-prod


# Nginx starts on boot automatically
sudo systemctl daemon-reload
sudo systemctl enable nginx
sudo systemctl start nginx


# ------------------------------------------------ Backend Setup -------------------------------------------------- #

BACKEND_DIR_STAGE="/opt/my-app-backend-staging"
BACKEND_DIR_PROD="/opt/my-app-backend-prod"

sudo mkdir -p $BACKEND_DIR_STAGE
sudo mkdir -p $BACKEND_DIR_PROD


# Backend files — owned by Node process user
sudo chown -R vagrant:vagrant $BACKEND_DIR_STAGE
sudo chown -R vagrant:vagrant $BACKEND_DIR_PROD


# Systemd service for Node.js backend
# Staging
cat << EOF | sudo tee /etc/systemd/system/my-app-backend-staging.service
[Unit]
Description=My Node.js Backend
After=network.target

[Service]
ExecStart=/usr/bin/node $BACKEND_DIR_STAGE/server.js
WorkingDirectory=$BACKEND_DIR_STAGE
Restart=always
User=vagrant
Environment=NODE_ENV=staging
Environment=PORT=3001

[Install]
WantedBy=multi-user.target
EOF


# Production
cat << EOF | sudo tee /etc/systemd/system/my-app-backend-prod.service
[Unit]
Description=My Node.js Backend
After=network.target

[Service]
ExecStart=/usr/bin/node $BACKEND_DIR_PROD/server.js
WorkingDirectory=$BACKEND_DIR_PROD
Restart=always
User=vagrant
Environment=NODE_ENV=production
Environment=PORT=3002

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable my-app-backend-staging
sudo systemctl enable my-app-backend-prod
# Note: Service not started yet, Jenkins deploy will handle this
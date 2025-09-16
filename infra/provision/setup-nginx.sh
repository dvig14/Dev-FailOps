#!/bin/bash

set -e 

# ------------------------- Setup SSH key for Jenkins ------------------------- #
# Ensure Jenkins' public key is added so pipeline can SSH without password
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCNEtQpcPw0S6CNlluWRWkXlGvtk4NmE5RDbtsyYYd1LrylvJeWkZKC52zpYH418vKlFYWOOWgB0gKHkUbFMYF/1gk55epDz7sgGkdTiqr4TIYT6hOtsYod7dMUhnQvXcIKdAUyk4mhbib8gFNzhdEF00wAnLR5pmeQn+C3FFUophedkVdkcz/QYnEbfluz+v28vBJfJlTC0mnBWJXMuuwimtu/53njQqRdsmT15kwPVgytxkwQAD02UuqKz90M+KeEYQYlhIwE+yCR1Ix7NwsqOspZXXoNKZUW2L8Zt/cfwT/+vsrO0+2Q7XQjc2Oj0S5fCGPQELF0RaHAixi0zMiaMyKOCBQpyoiq8Rj2lXumViQSa5eKysNQjQ1yvsMXuuFmms7ULZnuTDzM0yYgu4SzcBd0LCPDRt3PtiD5YNn0wXxGy1DyH12JNooa/efxR2IuSfvHe8u9VAli6O63TBpwzPIbAMZbv2apdHTmCjjUZ8fCc2YiSuygrVeZNr6k/E5AmUMaAzFxgw+Xfp6k/F/qNV3xDFOkEpqxuJiP0wkyAS5eHKDPfA574GMVIZops6L3p7jcJAan0pj39NQ1lf7agGVLJa0CwMoxfTa923FyF+O4YtELemA51uzShjbw+CBvnd5+PHLv0EpZRlq5Bgq1gGiIguIbf9FCFSF0RUq0Cw== jenkins@appvm"   # <-- replace with content of /var/lib/jenkins/.ssh/app_vm_key.pub

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
    server_name 192.168.56.11;

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
    server_name 192.168.56.11;

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
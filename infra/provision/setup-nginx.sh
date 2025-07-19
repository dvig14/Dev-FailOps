#!/bin/bash

sudo apt-get update -y
sudo apt-get install -y nginx

sudo rm -f /etc/nginx/sites-enabled/default 

mkdir -p /var/www/reactapp
echo "<h1>Waiting for React App</h1>" | sudo tee /var/www/reactapp/index.html

cat << EOF | sudo tee /etc/nginx/sites-available/reactapp
server {
    listen 80 default_server;
    server_name 192.168.56.11;

    root /var/www/reactapp;
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/reactapp /etc/nginx/sites-enabled/reactapp
sudo systemctl enable nginx
sudo systemctl start nginx

#!/bin/bash

set -e

sudo apt-get update -y
sudo apt-get install -y openjdk-21-jdk

java -version

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
  
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
  
sudo apt-get -y update
sudo apt-get install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins

sleep 15

ADMIN_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)

echo "Jenkins initial admin password: $ADMIN_PASS"
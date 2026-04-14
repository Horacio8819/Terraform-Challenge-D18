#!/bin/bash
set -e

# --- System updates and Node.js installation ---
dnf update -y
curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -
dnf install -y nodejs

# --- Application directory ---
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# --- Create Node.js app ---
cat <<EOT > app.js
const express = require('express');
const app = express();
const server_port = ${server_port};

app.get('/', (req, res) => res.send('Hello ${cluster_name}! Deployed by Horace on ${server_port} port. ${server_template_version}'));
app.get('/health', (req, res) => res.status(200).send('health is okay for Cloud Engineer'));

app.listen(server_port, '0.0.0.0', () => {console.log('Server running on ${server_port}');});
EOT

# --- Initialize npm and install dependencies ---
npm init -y
npm install express

# --- Fix permissions ---
chown -R ec2-user:ec2-user /home/ec2-user/app

# --- Create systemd service for Node.js app ---
cat <<EOT > /etc/systemd/system/nodeapp.service
[Unit]
Description=Node.js App
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/app
ExecStart=/usr/bin/node app.js
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOT

# --- Enable and start service ---
systemctl daemon-reload
systemctl enable --now nodeapp
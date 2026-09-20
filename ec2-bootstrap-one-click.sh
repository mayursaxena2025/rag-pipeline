#!/bin/bash
set -euo pipefail

APP_DIR="/home/ubuntu/rag-pipeline"
GIT_REPO="https://github.com/mayursaxena2025/rag-pipeline.git"
DOMAIN="sassbyte.store"
EMAIL="admin@sassbyte.store"
APP_PORT="8000"

echo "=================================================="
echo "Starting EC2 deployment for Namecheap DNS setup"
echo "Domain: $DOMAIN"
echo "=================================================="

# Install required system packages
sudo apt-get update -y
sudo apt-get install -y \
  git \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  nginx \
  certbot \
  python3-certbot-nginx \
  curl \
  ca-certificates

# Clone repository
if [ ! -d "$APP_DIR" ]; then
  sudo mkdir -p /home/ubuntu
  sudo chown -R ubuntu:ubuntu /home/ubuntu
  git clone "$GIT_REPO" "$APP_DIR"
fi

cd "$APP_DIR"

# Create Python virtualenv if needed
if [ ! -d "$APP_DIR/.venv" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi

source "$APP_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt

# Create .env if absent
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'EOF'
OPENAI_API_KEY=
DATA_DIR=./data
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
LLM_MODEL=gpt-4o-mini
SEARCH_K=4
EOF
fi

# Create systemd service
sudo tee /etc/systemd/system/rag-api.service >/dev/null <<SERVICE
[Unit]
Description=RAG Pipeline API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/.venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/uvicorn app:app --host 0.0.0.0 --port $APP_PORT
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# Configure nginx for HTTP redirect and HTTPS proxy.
# This assumes DNS is already pointed to the EC2 public IP in Namecheap.
sudo tee /etc/nginx/conf.d/rag.conf >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 120s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
    }
}
NGINX

# Start app service
sudo systemctl daemon-reload
sudo systemctl enable rag-api.service
sudo systemctl restart rag-api.service
sudo systemctl enable nginx
sudo systemctl restart nginx

# Request certificate only after DNS has propagated to the EC2 public IP.
# Namecheap DNS setup is used here, not Route53.
if [ -n "${DOMAIN:-}" ] && [ "$DOMAIN" != "example.com" ]; then
  echo "Waiting for DNS to resolve before obtaining HTTPS certificate..."
  echo "Namecheap instructions: create an A record for @ -> EC2 public IP and a CNAME for www -> @"
  echo "If DNS is already set, certbot will now issue the certificate."
  sudo certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || true
fi

# Validate and reload nginx
sudo nginx -t
sudo systemctl reload nginx

# Print summary
echo "=================================================="
echo "Deployment finished."
echo "DNS provider: Namecheap"
echo "App URL: https://$DOMAIN"
echo "Docs URL: https://$DOMAIN/docs"
echo "=================================================="

echo ""
echo "Namecheap DNS required:"
echo "  A record: @ -> EC2 public IPv4"
echo "  CNAME: www -> @"
echo "  Make sure the EC2 security group allows 80 and 443."

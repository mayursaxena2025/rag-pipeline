#!/bin/bash
set -euo pipefail

APP_DIR="/home/ubuntu/rag-pipeline"
SERVICE_FILE="/etc/systemd/system/rag-api.service"
NGINX_CONF="/etc/nginx/conf.d/rag.conf"
DOMAIN="sassbyte.store"
GIT_REPO="https://github.com/your-username/rag-pipeline.git"

# 1) Install OS packages
sudo apt-get update -y
sudo apt-get install -y git python3 python3-pip python3-venv python3-dev nginx certbot python3-certbot-nginx curl

# 2) Clone application repo
if [ ! -d "$APP_DIR" ]; then
  sudo mkdir -p /home/ubuntu
  sudo chown -R ubuntu:ubuntu /home/ubuntu
  git clone "$GIT_REPO" "$APP_DIR"
fi

cd "$APP_DIR"

# 3) Create venv and install app dependencies
if [ ! -d "$APP_DIR/.venv" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi

source "$APP_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt

# 4) Create .env if missing
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'EOF'
OPENAI_API_KEY=
DATA_DIR=./data
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
LLM_MODEL=gpt-4o-mini
SEARCH_K=4
EOF
fi

# 5) Create systemd service
sudo tee "$SERVICE_FILE" >/dev/null <<SERVICE
[Unit]
Description=RAG Pipeline API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/.venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$APP_DIR/.env
ExecStart=$APP_DIR/.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

# 6) Create Nginx reverse proxy config
sudo tee "$NGINX_CONF" >/dev/null <<NGINX
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 120s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
    }
}
NGINX

# 7) Start services
sudo systemctl daemon-reload
sudo systemctl enable rag-api.service
sudo systemctl restart rag-api.service
sudo systemctl enable nginx
sudo systemctl restart nginx

# 8) Get certificate
sudo certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN

# 9) Validate service
sudo nginx -t
sudo systemctl reload nginx

echo "Production deployment complete."
echo "App URL: https://$DOMAIN"
echo "Swagger docs: https://$DOMAIN/docs"

#!/bin/bash
set -euo pipefail

APP_DIR="/home/ubuntu/rag-pipeline"
SERVICE_FILE="/etc/systemd/system/rag-api.service"
GIT_REPO="https://github.com/your-username/rag-pipeline.git"

# Ensure OS packages are present
sudo apt-get update -y
sudo apt-get install -y git python3 python3-pip python3-venv python3-dev curl

# Clone repo if not already present
if [ ! -d "$APP_DIR" ]; then
  sudo mkdir -p /home/ubuntu
  sudo chown -R ubuntu:ubuntu /home/ubuntu
  git clone "$GIT_REPO" "$APP_DIR"
fi

cd "$APP_DIR"

# Create virtual environment if needed
if [ ! -d "$APP_DIR/.venv" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi

# Activate and install dependencies
source "$APP_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt

# Create .env file if missing
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'EOF'
OPENAI_API_KEY=
DATA_DIR=./data
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
LLM_MODEL=gpt-4o-mini
SEARCH_K=4
EOF
fi

# Install systemd service
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

# Start and enable service
sudo systemctl daemon-reload
sudo systemctl enable rag-api.service
sudo systemctl restart rag-api.service
sudo systemctl status rag-api.service --no-pager

echo "Deployment complete."
echo "App URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000/docs"

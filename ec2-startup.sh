#!/bin/bash
set -e

# Update system
sudo yum update -y || sudo apt-get update -y

# Install dependencies
if command -v yum >/dev/null 2>&1; then
  sudo yum install -y git python3 python3-pip python3-venv
else
  sudo apt-get install -y git python3 python3-pip python3-venv
fi

# Clone repo if not already present
if [ ! -d "/home/ec2-user/rag-pipeline" ] && [ ! -d "/home/ubuntu/rag-pipeline" ]; then
  if [ -d "/home/ec2-user" ]; then
    cd /home/ec2-user
    git clone https://github.com/your-username/rag-pipeline.git
  else
    cd /home/ubuntu
    git clone https://github.com/your-username/rag-pipeline.git
  fi
fi

# Set app directory
if [ -d "/home/ec2-user/rag-pipeline" ]; then
  APP_DIR="/home/ec2-user/rag-pipeline"
else
  APP_DIR="/home/ubuntu/rag-pipeline"
fi

cd "$APP_DIR"

# Create venv if missing
if [ ! -d "$APP_DIR/.venv" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi

# Install Python dependencies
source "$APP_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install -r requirements.txt

# Create .env if missing
if [ ! -f "$APP_DIR/.env" ]; then
  cat > "$APP_DIR/.env" <<'EOF'
OPENAI_API_KEY=
DATA_DIR=./data
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
LLM_MODEL=gpt-4o-mini
SEARCH_K=4
EOF
fi

# Start app in background
nohup bash -c 'source "$APP_DIR/.venv/bin/activate" && cd "$APP_DIR" && uvicorn app:app --host 0.0.0.0 --port 8000' >/tmp/rag-api.log 2>&1 &

echo "Deployment started. Check logs with: tail -f /tmp/rag-api.log"
echo "App URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"

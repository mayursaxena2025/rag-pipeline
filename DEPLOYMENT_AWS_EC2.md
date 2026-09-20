# AWS EC2 Deployment Guide for the RAG Pipeline

This document contains the exact AWS CLI setup, DNS configuration, security group rules, and EC2 deployment steps for the project.

## 1. Prerequisites

Make sure you have the AWS CLI installed and configured:

```bash
aws --version
aws configure
```

You need an IAM user or role with permission to create:
- EC2 instances
- security groups
- key pairs
- VPC and networking objects

---

## 2. Create an EC2 key pair

```bash
aws ec2 create-key-pair \
  --key-name rag-ec2-key \
  --query 'KeyMaterial' \
  --output text > rag-ec2-key.pem

chmod 400 rag-ec2-key.pem
```

---

## 3. Create a security group

```bash
aws ec2 create-security-group \
  --group-name rag-sg \
  --description "Security group for RAG app"
```

Get the group ID:

```bash
aws ec2 describe-security-groups \
  --group-names rag-sg \
  --query 'SecurityGroups[0].GroupId' \
  --output text
```

Allow SSH:

```bash
aws ec2 authorize-security-group-ingress \
  --group-name rag-sg \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

Allow HTTP:

```bash
aws ec2 authorize-security-group-ingress \
  --group-name rag-sg \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

Allow HTTPS:

```bash
aws ec2 authorize-security-group-ingress \
  --group-name rag-sg \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

---

## 4. Launch an EC2 instance

Use Ubuntu 22.04 LTS AMI. You can find the AMI ID in the region you are using. For example:

```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --instance-type t3.small \
  --key-name rag-ec2-key \
  --security-groups rag-sg \
  --count 1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=rag-app}]'
```

Find the public IP:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=rag-app" \
  --query "Reservations[*].Instances[*].PublicIpAddress" \
  --output text
```

---

## 5. SSH into the instance

```bash
ssh -i rag-ec2-key.pem ubuntu@<EC2_PUBLIC_IP>
```

---

## 6. Install required server packages

```bash
sudo apt-get update -y
sudo apt-get install -y git python3 python3-pip python3-venv python3-dev nginx certbot python3-certbot-nginx curl
```

---

## 7. Clone the project

```bash
cd /home/ubuntu
git clone https://github.com/your-username/rag-pipeline.git
cd rag-pipeline
```

Replace the GitHub URL with your own repository.

---

## 8. Create the Python environment and install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

---

## 9. Create the environment file

```bash
nano .env
```

Add:

```env
OPENAI_API_KEY=
DATA_DIR=./data
EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
LLM_MODEL=gpt-4o-mini
SEARCH_K=4
```

---

## 10. Start the FastAPI app with systemd

Create the service file:

```bash
sudo nano /etc/systemd/system/rag-api.service
```

Use this content:

```ini
[Unit]
Description=RAG Pipeline API
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/rag-pipeline
Environment="PATH=/home/ubuntu/rag-pipeline/.venv/bin:/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/home/ubuntu/rag-pipeline/.env
ExecStart=/home/ubuntu/rag-pipeline/.venv/bin/uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Reload and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable rag-api.service
sudo systemctl start rag-api.service
sudo systemctl status rag-api.service
```

---

## 11. Configure Nginx as a reverse proxy

```bash
sudo nano /etc/nginx/conf.d/rag.conf
```

Add:

```nginx
server {
    listen 80;
    server_name sassbyte.store www.sassbyte.store;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name sassbyte.store www.sassbyte.store;

    ssl_certificate /etc/letsencrypt/live/sassbyte.store/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/sassbyte.store/privkey.pem;

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
```

Validate Nginx:

```bash
sudo nginx -t
sudo systemctl restart nginx
```

---

## 12. Route 53 DNS settings

If using Route 53 for the domain `sassbyte.store`, create these records in the hosted zone.

### A record
- Name: `sassbyte.store`
- Type: A
- Value: `<EC2_PUBLIC_IP>`
- TTL: 60

### CNAME record
- Name: `www`
- Type: CNAME
- Value: `sassbyte.store`
- TTL: 60

This allows both of these to resolve:
- `https://sassbyte.store`
- `https://www.sassbyte.store`

---

## 13. Request the Let’s Encrypt certificate

```bash
sudo certbot --nginx -d sassbyte.store -d www.sassbyte.store --non-interactive --agree-tos -m admin@sassbyte.store
```

Then reload Nginx:

```bash
sudo systemctl reload nginx
```

---

## 14. Test the deployment

```bash
curl -I https://sassbyte.store
curl -X POST https://sassbyte.store/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"What is the purpose of this project?","llm_provider":"mock"}'
```

Expected result:
- HTTP 200/redirect behavior from Nginx
- successful app response from the FastAPI endpoint

---

## 15. Useful maintenance commands

Check app status:

```bash
sudo systemctl status rag-api.service
```

View logs:

```bash
sudo journalctl -u rag-api.service -f
```

Restart app:

```bash
sudo systemctl restart rag-api.service
```

Check Nginx:

```bash
sudo systemctl status nginx
sudo nginx -t
```

Renew certificate:

```bash
sudo certbot renew --dry-run
```

---

## 16. Summary

This deployment pattern gives you:
- a production-ready Ubuntu EC2 instance
- systemd-managed app lifecycle
- Nginx reverse proxy on port 80/443
- HTTPS via Let’s Encrypt
- Route 53 DNS support for `sassbyte.store`

This is a complete AWS-based deployment flow for the RAG application.

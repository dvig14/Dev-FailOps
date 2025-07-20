#!/bin/bash

if [[ -z "$MINIO_USER" || -z "$MINIO_PASS" ]]; then
  echo "❌ ERROR: MINIO_USER or MINIO_PASS not set. Did you forget to source .env?"
  echo "💡 Tip: Run 'source ../../.env' before vagrant provision"
  exit 1
fi

if [[ ! "$MINIO_USER" =~ ^[a-zA-Z0-9_=+()\-]+$ || ! "$MINIO_PASS" =~ ^[a-zA-Z0-9__=+()\-]+$ ]]; then
  echo "❌ ERROR: MINIO_USER or MINIO_PASS contains special characters."
  echo "✅ Allowed: letters, numbers, _, -, =, +, (, ) to avoid systemd escaping issues."
  echo "💡 Change and Run: 'source ../../.env' before vagrant provision"
  exit 1
fi

sudo apt-get update -y
sudo apt-get install -y wget

wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

sudo mkdir -p /home/vagrant/minio
sudo chown vagrant:vagrant /home/vagrant/minio

sudo tee /etc/default/minio > /dev/null <<EOF
MINIO_ROOT_USER="${MINIO_USER}"
MINIO_ROOT_PASSWORD="${MINIO_PASS}"
EOF

cat << EOF | sudo tee /etc/systemd/system/minio.service
[Unit]
Description=MinIO
After=network-online.target 

[Service]
User=vagrant
Group=vagrant
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server /home/vagrant/minio --console-address=:9001
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio

echo "✅ MinIO server started. Access it at http://192.168.56.22:9000"
echo "✅ MinIO Console is available at http://192.168.56.22:9001" 

echo "⏳ Waiting for MinIO to be live..."
until curl -s http://localhost:9000/minio/health/live >/dev/null; do
  sleep 2
done
echo "✅ MinIO is live!"

wget https://dl.min.io/client/mc/release/linux-amd64/mc -O mc
chmod +x mc
sudo mv mc /usr/local/bin/

mc alias set local http://localhost:9000 "$MINIO_USER" "$MINIO_PASS"

BUCKET_NAME="terra-state"
mc mb local/$BUCKET_NAME || echo "📦 Bucket already exists"
mc version enable local/$BUCKET_NAME

echo "✅ Bucket '$BUCKET_NAME' is ready with versioning enabled."
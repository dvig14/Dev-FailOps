# MinIO Installation and Setup with Systemd on Vagrant (Linux)

This guide sets up **MinIO** on a Linux VM using `systemd` to ensure the server runs reliably and automatically on reboot.

---

## 📦 Step 1: Install `wget`

We’ll use `wget` to download the MinIO binary.

```bash
sudo apt-get update -y
sudo apt-get install -y wget
```

---

## 📥 Step 2: Download and Install MinIO Binary

Refer to [MinIO Official Docs](https://min.io/docs/minio/linux/index.html) for updates.

```bash
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/
```

> We use **systemd** instead of running `minio server` directly. This ensures:
> * The process doesn't hang.
> * It starts automatically on VM reboot.

---

## 📁 Step 3: Create Directory for File Storage

Make a directory for serving files and change its ownership to the `vagrant` user:

```bash
sudo mkdir -p /home/vagrant/minio
sudo chown vagrant:vagrant /home/vagrant/minio
```

---

## 🔐 Step 4: Set Environment Variables from `.env`

Environment variables for MinIO credentials are stored in a `.env` file.

**`.env` (place in project root):**

```bash
export AWS_ACCESS_KEY_ID=your-username
export AWS_SECRET_ACCESS_KEY=your-password
```

> ⚠️ **Important:** Add `.env` to your `.gitignore` file to avoid pushing secrets to version control.

---

## ⚙️ Step 5: Create systemd Service for MinIO

Create a systemd service unit file to manage the MinIO server:

```bash
cat << EOF | sudo tee /etc/systemd/system/minio.service
[Unit]
Description=MinIO               # Service name or purpose
After=network-online.target     # Ensure service starts only after network is up (IP, DNS, router availability)

[Service]
User=vagrant                    # Run service as 'vagrant' user
Group=vagrant                   # Group under which the service runs
Environment="MINIO_ROOT_USER=${MINIO_USER}"       # Set MinIO username from environment variable
Environment="MINIO_ROOT_PASSWORD=${MINIO_PASS}"   # Set MinIO password from environment variable
ExecStart=/usr/local/bin/minio server /home/vagrant/minio --console-address=:9001
                                 # Command to start the MinIO server, serving from /home/vagrant/minio and web UI on port 9001
Restart=always                  # Restart the service automatically if it crashes or stops
LimitNOFILE=65536               # Increase file descriptor limit for handling large numbers of connections/files

[Install]
WantedBy=multi-user.target      # Enables service to start automatically at boot 
EOF
```

---

## ▶️ Step 6: Enable and Start MinIO

Reload systemd and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
```

---

## ✅ Output

```text
MinIO server started. Access it at http://192.168.56.22:9000
MinIO Console is available at http://192.168.56.22:9001
```

---

## 🧠 Notes

### Private Network:

Minio is running on vm and to access it from host terraform as well as from other vms. It has given `private ip`

```hcl
minio.vm.network "private_network", ip: "192.168.56.22"
```
# MinIO Installation and Setup with Systemd on Vagrant (Linux)

This guide sets up **MinIO** on a Linux VM using `systemd` to ensure the server runs reliably and automatically on reboot.

<br>

## 📦 Step 1: Install `wget`

We’ll use `wget` to download the MinIO binary.

```bash
sudo apt-get update -y
sudo apt-get install -y wget
```

<br>

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

<br>

## 📁 Step 3: Create Directory for File Storage

Make a directory for serving files and change its ownership to the `vagrant` user:

```bash
sudo mkdir -p /home/vagrant/minio
sudo chown vagrant:vagrant /home/vagrant/minio
```

<br>

## 🔐 Step 4: Set Environment Variables from `.env`

Environment variables for MinIO credentials are stored in a `.env` file.

**`.env` (place in project root):**

```bash
export AWS_ACCESS_KEY_ID=your-username
export AWS_SECRET_ACCESS_KEY=your-password
```

> ⚠️ **Important:** Add `.env` to your `.gitignore` file to avoid pushing secrets to version control.

<br>

## Step 5: Set minio creditionals in config

```bash
sudo tee /etc/default/minio > /dev/null <<EOF
MINIO_ROOT_USER=${MINIO_USER}
MINIO_ROOT_PASSWORD=${MINIO_PASS}
EOF
```
Now even after:
- Terminal closes
- VM restarts
- You run vagrant up again

> 💡 MinIO auto-starts and remembers credentials via /etc/default/minio.  

<br>

## ⚙️ Step 6: Create systemd Service for MinIO

Create a systemd service unit file to manage the MinIO server:

```bash
cat << EOF | sudo tee /etc/systemd/system/minio.service
[Unit]
Description=MinIO               # Service name or purpose
After=network-online.target     # Ensure service starts only after network is up (IP, DNS, router availability)

[Service]
User=vagrant                    # Run service as 'vagrant' user
Group=vagrant                   # Group under which the service runs
EnvironmentFile=/etc/default/minio  # Set creditionals here permanently once sourced, no need to source again
                                    # until you change n need to source again
ExecStart=/usr/local/bin/minio server /home/vagrant/minio --console-address=:9001
                                 # Command to start the MinIO server, serving from /home/vagrant/minio and web UI on port 9001
Restart=always                  # Restart the service automatically if it crashes or stops
LimitNOFILE=65536               # Increase file descriptor limit for handling large numbers of connections/files

[Install]
WantedBy=multi-user.target      # Enables service to start automatically at boot 
EOF
```

<br>

## Step 7: Enable and Start MinIO

Reload systemd and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
```

<br>

## Output

```text
MinIO server started. Access it at http://192.168.56.22:9000
MinIO Console is available at http://192.168.56.22:9001
```

<br>

## 🧠 Notes

### Private Network:

Minio is running on vm and to access it from host terraform as well as from other vms. It has given `private ip`

```hcl
minio.vm.network "private_network", ip: "192.168.56.22"
```

<br>

## Here we now install mc for enabling versioning

### ▶ Step 1: Waiting for MinIO to live

```bash
echo "⏳ Waiting for MinIO to be live..."
until curl -s http://localhost:9000/minio/health/live >/dev/null; do
  sleep 2
done
echo "✅ MinIO is live!"
```

<br>

### ▶ Step 2: Download and install mc (MinIO Client)

```bash
wget https://dl.min.io/client/mc/release/linux-amd64/mc -O mc
chmod +x mc
sudo mv mc /usr/local/bin/
```
> Installs `mc` to be used like a CLI tool from anywhere.

<br>

### ▶ Step 3: Configure mc to talk to your MinIO server

```bash
mc alias set local http://localhost:9000 "$MINIO_USER" "$MINIO_PASS"
```

- `alias set` defines a shortcut called `local`
- This connects `mc` to MinIO running on `localhost:9000`
- It stores credentials internally `(~/.mc/config.json)`

> You can now run: `mc ls local` or `mc mb local/bucket-name` to interact with your MinIO server.

<br>

### ▶ Step 4: Create a versioned bucket

```bash
BUCKET_NAME="terra-state"
mc mb local/$BUCKET_NAME || echo "📦 Bucket already exists"
mc version enable local/$BUCKET_NAME
```

- `mc mb`: Creates a bucket named `terra-state` on the alias `local` (i.e., your MinIO)
- If it already exists, shows a message
- `mc version enable`: Enables versioning for that bucket

> This is critical for Terraform because **S3 versioning protects** `.tfstate` from accidental deletion or overwrite.

<br>

## Why `localhost` is used even though MinIO has a private IP?

You're right: **your VM is exposed on `192.168.56.22`**.

But inside the VM, from the VM's point of view, MinIO is running **on itself**, so:

* `localhost:9000` or `127.0.0.1:9000` **points to MinIO running in the VM**
* So commands like `curl http://localhost:9000` or `mc alias set local http://localhost:9000 ...` **work inside the VM**

<br> 

## 🧠 Analogy: **VM is like a mini computer — with its own `localhost`**

| Environment         | What is `localhost`?                        | Example              |
|---------------------|---------------------------------------------|-----------------------|
| Your **host machine** | Refers to your **host OS** (e.g., Windows/Linux) | You run a React app and visit `http://localhost:3000` |
| Your **VM (MinIO)**   | Refers to the **guest OS inside VM**         | Inside the VM, you run `minio server` on port 9000, so it's accessible at `http://localhost:9000` **within that VM only** |


> Just like your React app runs on your local machine and you open `localhost:3000`, MinIO inside the VM runs on port `9000`, and from **inside the VM**, it's `localhost:9000`.


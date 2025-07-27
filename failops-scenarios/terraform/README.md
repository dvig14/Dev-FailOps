## 💻 Want to run simulations yourself?

Follow these setup steps:

### 1️⃣ Install Prerequisites

You'll need to install the following tools:

- [Vagrant n Virtualbox](https://github.com/dvig14/Devops/blob/master/Preq.md)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- Git installed (Git Bash for windows)

<details>
<summary>⚠️ Vagrant + VirtualBox Compatibility Note</summary>

<br>

| OS          | Status                      | Details & Fixes                                                                                                                                                                                |
| ----------- | --------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Linux**   | ✅ Works well                | Kernel modules usually load correctly. Run `vagrant up` directly.                                                                                                                              |
| **macOS**   | ⚠️ Kernel extension blocked | After installing VirtualBox, go to **System Settings → Security & Privacy**. You may see “System software from Oracle America was blocked.” Click **Allow**, then **reboot**.                 |
| **Windows** | ⚠️ Common issues            | You **must**: <br> - Use **PowerShell v3 or later** <br> - Run terminal as **Administrator** <br> - Disable **Hyper-V** (VirtualBox won’t work with it)                                        |

<br>

### 🔍 Virtualization (VT-x) May Already Be Enabled

⚠️ Some systems **don’t show the BIOS virtualization setting** — because it’s **already enabled by default** or **locked by the manufacturer**.

- If you **can’t find “VT-x” or “Virtualization”** in BIOS — don’t worry!
- It’s often **pre-enabled** on newer systems.
- The real issue is usually **Windows settings**, not BIOS.

You can verify if it's active using:

```powershell
systeminfo | findstr /i "Virtualization"
```

Expected output:

```
Virtualization Enabled In Firmware: Yes
```

<br>

### 🧱 Virtualization Layers: What Interferes?

| Layer          | Role                                                                     | What can go wrong                                       |
| -------------- | ------------------------------------------------------------------------ | ------------------------------------------------------- |
| **BIOS/UEFI**  | Enables virtualization at hardware level (VT-x/AMD-V)                    | You did this — ✅ all good                               |
| **Windows OS** | Allocates VT-x to specific hypervisors (Hyper-V, VirtualBox, WSL2, etc.) | Only **one hypervisor** can fully use VT-x at a time    |
| **VirtualBox** | Needs direct access to VT-x                                              | Fails if another service (like Hyper-V) already owns it |

<br>

> 💡 If you hit this error on Windows:
>
> ```text
> Error: Vagrant failed to initialize at a very early stage:
> │
> │ The version of powershell currently installed on this host is less than
> │ the required minimum version. Please upgrade the installed version of
> │ powershell to the minimum required version and run the command again.
> │
> │   Installed version: N/A
> │   Minimum required version: 3
> ```
>
> Please ensure:
>
> * ✅ PowerShell version ≥ 3
> * ✅ Vagrant added to PATH
> * ✅ Run terminal as Administrator
> * ✅ Hyper-V is disabled → [video →](https://youtu.be/hnqqpgwlopw)

🧪 After install, test with:

```bash
vagrant --version
virtualbox --help
```

Still stuck? Skip `vagrant up` and explore the logs & README passively.

</details>

<br>

### 2️⃣ Clone This Repo

```bash
git clone https://github.com/dvig14/Dev-FailOps.git
cd Dev-FailOps
```

<br>

### 3️⃣ Start MinIO Server (S3-Compatible Backend)

Navigate to the MinIO setup directory and bring up the VM. Before running `vagrant up`, export environment variables so the provision script can access them:

```bash
cd infra/minio-server-S3

# load creditionals
# just need to run (source ../../env) once at start
# Next time creditionals are saved until you change again or destroy vm
source ../../.env
vagrant up
```

* This uses the `Vagrantfile` and is **automatically provisioned** using `setup-minio.sh`.
* It installs MinIO, configures it as a `systemd` service, and starts it with credentials from a `.env` file.
* Avoid writing secrets directly into `Vagrantfile` or the script. This approach keeps credentials separate and secure.

📘 To understand the provisioning in detail, refer to:
👉 [explain-setup](../../infra/minio-server-S3/README.md)

<br>

### 4️⃣ Create bucket If not created
 
 Open the MinIO Console at:
👉 [http://192.168.56.22:9001](http://192.168.56.22:9001)

Login using the credentials from `.env` and create a bucket `+`:

| Field       | Value         |
| ----------- | ------------- |
| Bucket Name | `terra-state` |


<br>

### 5️⃣ Initialize Terraform

Now, navigate to the Terraform directory:

```bash
cd infra/terraform/vagrant

# Load MinIO credentials
source ../../../.env

terraform init -backend-config="key=terra-scenarios/{scenario-name}/terraform.tfstate"
terraform plan

# Run this (-var="sandbox_enable=true") only once at start of any first scenario
# As for terraform FailOps this will add sandbox vm in vagrantfile 
# then afterwards can simply apply until you enabled other vm or terraform destroy this one
terraform apply -var="sandbox_enable=true"

# Optional: check all vms created by opening `VirtualBox` or run:
vagrant global-status 
```

* **-backend-config** is for creating separate tfstate file per scenario like `"terra-scenarios/01_tfstate-deletion/terraform.tfstate"`
* Terraform uses the MinIO S3-compatible service as a **remote backend** for `terraform.tfstate` files.
* VM creation, halting, and destruction are handled via `local-exec` provisioners that execute `vagrant` commands.

📘 For a full breakdown of Terraform configurations:
👉 [explain-teraStruc](../../infra/terraform/vagrant/README.md)

<br>

## 🔥 Ready to Break Things?

Pick any scenario under `failops-scenarios/terraform/`:

```bash
failops-scenarios/terraform/1-beginner/01_tfstate-deletion/
```
💥 Simulate → Debug → Fix → Learn → Repeat

> **Note:**
>
> - Once the sandbox VM is enabled, you do **not** need to enable it again. Simply run:
>   ```bash
>   terraform apply
>   ```
>   This will spin up the sandbox VM and you’re good to go!
>
> - To **halt** (stop) the VM, run:
>   ```bash
>   terraform apply -var="vm_state=halt"
>   ```

<br>

## 🧹 Destroy or Halt VMs After Scenario Completion

### 📦 MinIO Server

```bash
cd infra/minio-server-S3

# 🔸 Option 1: Temporarily halt the VM (recommended)
vagrant halt

# 🔻 Option 2: Permanently destroy the VM
vagrant destroy -f
```

<br>

### 🧪 Sandbox VM (via Terraform)

```bash
cd infra/terraform/vagrant

# 🔻 Destroy all provisioned resources (VM + others)
terraform destroy

# 🔸 Optionally halt the VM instead of destroying it
terraform apply -var="vm_state=halt"

# ✅ Check current VM status
vagrant global-status
```
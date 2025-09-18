# CI/CD Pipeline Flow (Development → Staging/Production)

**Tools:** Jenkins + Terraform (VM provisioning) + MinIO (artifact & tfstate storage)

<br>

## ⚙️ Two Setup Options

1. App VM running inside Jenkins VM (Nested Virtualization)**
2. App VM running on host machine (via Agents)**


## 🔍 Issue

* **Setup 1** was working fine earlier (App VM inside Jenkins VM).
* After my Windows crash, I reinstalled everything and shifted from **Windows 10 → Windows 11**.
* Now, the **App VM is not spinning up inside Jenkins VM** and throws:

  ```
  Connection Reset Error
  ```

## ❓ What Changed

* My setup is the same as before the crash.
* Only difference: **Windows 11** instead of **Windows 10**.
* I’m not sure what is suddenly breaking the nested virtualization flow.

## 📌 Help Wanted

If anyone has experienced this issue (or knows what might be missing in the new setup), please share your inputs.

* Could be related to **Hyper-V / VirtualBox settings** in Windows 11.
* Or possibly some **networking/driver change** after reinstall.
* [Setup 1](./setups.md#app-vm-running-inside-jenkins-vm-using-nested-virtulization)

> [Ensure Virtualization Is Enabled & Terraform Installed](../../../failops-scenarios/terraform/README.md)

<br>

## Step 1: Start MinIO Server

Navigate to the MinIO infra folder:

```bash
cd ../../minio-server-S3

# Load credentials (only required once unless you destroy vm or change creditional)
source ../../.env
vagrant up
```

> The MinIO server will be accessible at: `http://192.168.56.22:9001`

<br>

## Step 2: Start Jenkins Server

Navigate to the Jenkins infra folder:

```bash
cd ../cicd/jenkins-server
vagrant up
```

> Jenkins will be accessible at: `http://192.168.56.13:8080`

<br>

## Step 3: Install Plugins and Packages

* Install **suggested plugins** during the initial setup.
* Login as admin.         
* [Setup 1 : shh into jenkins vm](./setups.md#ssh-into-jenkins-vm-to-install-additional-packagestools-used-by-the-pipeline)
* [Setup 2 : using agents](./setups.md#setup-2--app-vm-runs-on-host-machine-using-agents)
* Common setup:
```bash
# cd to jenkins-server folder then:
vagrant ssh

# install zip pkg if not installed
sudo apt-get update
sudo apt-get install -y zip

wget https://dl.min.io/client/mc/release/linux-amd64/mc -O mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure MinIO client (`mc`) with your credentials from `.env`
# Jenkins jobs run as jenkins user, so they look inside /var/lib/jenkins/.mc/config.json
sudo su - jenkins
mc alias set minio-server http://192.168.56.22:9000 "<MINIO_USER>" "<MINIO_PASS>"
mc mb minio-server/my-app 
mc version enable minio-server/my-app


# When we spin up App VM, vagrant autogenerate a random key which use as authentication for ssh to app vm 
# But we gonna pre-generate our own SSH keypair
# 1. Generate a fixed SSH keypair

ssh-keygen -t rsa -b 4096 -f ~/.ssh/app_vm_key -C "jenkins@appvm"

# This creates:
# /var/lib/jenkins/.ssh/app_vm_key → private key (only Jenkins should use it).
# /var/lib/jenkins/.ssh/app_vm_key.pub → public key (to put inside App VM).

# 2. Store private key in Jenkins Credentials [Image - ./assets/ssh-agent-cred.png]
#  - Go to http://192.168.56.13:8080 → Manage Jenkins → Credentials.
#  - Add new credential of type SSH Username with private key.
#  - Username = vagrant (the user that App VM uses for SSH).
#  - Private key = paste contents of /var/lib/jenkins/.ssh/app_vm_key
#  - ID = app-vm-ssh

# 3. Inject the public key into the App VM at provision time. [infra/provision/setup-nginx.sh]

exit
```

> These steps are one-time prerequisites before configuring the pipeline.

<br>

## Step 4: Source Control

* **Repository:** [GitHub (frontend + backend)](https://github.com/dvig14/my-app-demo/tree/develop)
* **Branch Strategy:**

  * `master`  → production
  * `develop` → staging

> Staging serves as a pre-production environment, replicating production for testing.

> For your lab, you can create your own repository or fork the example repo.

<br>

## Step 5: CI/CD Trigger

* **Trigger**: GitHub Webhook → Jenkins job.

**How it works:**
* Any commit pushed to GitHub triggers an HTTP POST request to Jenkins.
* Jenkins receives the branch, commit ID, author, etc., and starts the corresponding pipeline automatically.

**Recommended Plugins**

> - Go settings → plugins → installed plugins 
> - Search given plugins if present & enabled then no need to install 
> - If not installed then go to `available plugins` and install them

<br>

| Plugin / Component             | Purpose                                 | Benefits                                                            |
| ------------------------------ | --------------------------------------- | ------------------------------------------------------------------- |
| **Git**                        | Clone/fetch source code                 | Integrates Jenkins with Git repos, supports branch/commit checkout  |
| **GitHub Integration**         | Connect Jenkins with GitHub API         | Automates PR feedback, commit status, webhook integration           |
| **Multibranch Scan Webhook Trigger** | Auto-trigger pipeline on push           | Reduces manual job creation                                         |
| **Pipeline: Stage View**       | Visualize pipeline stages               | Enables real-time progress, stage duration, and failure pinpointing |
| **Credentials Binding**        | Secure storage and injection of secrets | Keeps secrets out of code/logs, injects as environment variables    |

📘 [Webhook Setup & Pipeline Explanation](./webhook.md)

<br>

## **Step 6: Build Stage**

* Jenkins executes **parallel jobs**:

  * **Frontend:** Install dependencies → build static files → output to `/build`
  * **Backend:** Install dependencies → package backend as `.zip`

**Plugin Installation:** NodeJS Plugin

* Allows use of `node` and `npm` commands on Jenkins agents.
* Supports multiple Node versions per project.

**Configuration:**

* Go to Manage Jenkins → Tools → NodeJS Installations
* Add `NodeJS_18`, select the NodeJS version 18 and enable "Install automatically".

- 📸 [Install NodeJS_18 version](./assets/Nodejs.png)
- 📘 [Paralled Build Jobs](./build_jobs.md)

<br>

## Step 7: Artifact Storage

* Store build artifacts in **MinIO S3**:

  * Separate folders for frontend and backend.
  * Use **versioning** (timestamp or commit hash).

📘 [Artifact Storage Guide](./artifact.md)

<br>

## Step 8: Infrastructure Provisioning

* Use **Terraform** to initialize and apply infrastructure.
* Create/refresh **staging VM** or **prod VM**. or **same VM but diff ports**
* Terraform will also maintain the **tfstate file** in MinIO.

**Plugin Installation:** SSh Agent Plugin
* This plugin allows you to provide SSH credentials to builds via a ssh-agent in Jenkins.

📘 [Provision Infra](./infra-staging.md#infrastructure-provisioning)

<br>

## Step 9: Deploy to Staging

* Deploy **frontend** to Nginx `/var/www/html`
* Deploy **backend** behind Nginx reverse proxy
  * Means both frontend + backend have same ip/dns (eg. `https://my-app/`)
  * And someone hit `https://my-app/api/` then that req goes to backend ip which is hidden 
* Both frontend and backend sharing the same **private IP** (i.e. `192.168.56.11`)

📘 [Deploy Staging](./infra-staging.md#deploy---staging)

<br>

## Step 10: Automated Tests (Staging) → Manual Approval → Deploy to production

* Run tests on staging environment:

  * **Frontend E2E tests** (Cypress/Playwright)
  * **Backend API tests** (Postman/Newman or Jest/Supertest)

* After successful tests, a **manual approval step** triggers deployment to production.This ensures that the changes are thoroughly reviewed before being released to the public.

📘 [Final Steps](./deploy-prod.md)
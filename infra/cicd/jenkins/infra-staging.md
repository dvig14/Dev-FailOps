# Infrastructure Provisioning

```groovy
pipeline {
    ...
    environment {
        ...
        AWS_ACCESS_KEY_ID     = credentials('MINIO_ACCESS_KEY')
        AWS_SECRET_ACCESS_KEY = credentials('MINIO_SECRET_KEY')
    }

[ForSetup - 1]stages {
        ...
        stage('Provision infra') {
            steps {
                dir('failops/infra/terraform/vagrant'){

                    sh """
                      chmod -R +x ./.providers ../../provision
                      terraform init -plugin-dir=./.providers -backend-config="key=terra-infra/terraform.tfstate"
                      terraform apply -var="app_enable=true" -var="vm_state=up" -auto-approve=true         
                    """
                }
            }
        }
    }

[ForSetup - 2]stages {
        ...
        stage('Provision infra') {
            agent { label 'windows' }
            steps {
                dir('failops/infra/terraform/vagrant') {
                    bat """
                      terraform init -backend-config="key=terra-infra/terraform.tfstate"
                      terraform apply -var="app_enable=true" -var="vm_state=up" -auto-approve=true
                    """
                }

                stash includes: 'failops/infra/output/**', name: 'output'
            }
        }
    }
}
```

<br>

## Jenkins Credential Setup

In **Jenkins Dashboard → Manage Jenkins → Credentials**:

   * Add **`MINIO_ACCESS_KEY`** (username that pass to minio via .env) → *Secret Text*
   * Add **`MINIO_SECRET_KEY`** (password that pass to minio via .env) → *Secret Text*

📸 [Creditionals](./assets/credentionals.png)

<br>

## Stage : Provision infra

**Setup 1**

```groovy
stage('Provision infra') {
    steps {
        dir('failops/infra/terraform/vagrant'){
            sh """
                chmod -R +x ./.providers ../../provision
                terraform init -plugin-dir=./.providers -backend-config="key=terra-infra/terraform.tfstate"
                terraform apply -var="app_enable=true" -var="vm_state=up" -auto-approve=true
            """
        }
    }
}
```

<br>

* **`dir('failops/infra/terraform/vagrant') { ... }`** → Executes commands inside the Terraform Vagrant directory.
* **`terraform init -backend-config="key=terra-infra/terraform.tfstate"`** → Initializes Terraform with MinIO backend, storing the `tfstate` at `terra-infra/terraform.tfstate`.
* **`terraform apply -auto-approve=true`** → Automatically applies Terraform configuration to spin up the app VM.
* **`-var="app_enable=true"`** → Passes variable to Terraform to enable the app VM in the generated `Vagrantfile`.
* **`-plugin-dir=./.providers`** → This option tells Terraform to use provider binaries (like `local`, `null`, etc.) from the specified directory instead of downloading them from the Terraform Registry (`registry.terraform.io/hashicorp`). The directory [terraform/vagrant/.providers](../../terraform/vagrant/.providers) contains these provider binaries, making them available for **offline use**.

> **Note**: For setup-1 I was using provider binaries in the `.providers` folder with `-plugin-dir` because Terraform fails to fetch providers from the registry (`http: server gave HTTP response to HTTPS client`). This setup allows me to continue working offline. Once I debug and resolve the registry fetch issue, I’ll update the configuration to use the default registry-based provider installation.

**Setup 2**

```groovy
stage('Provision infra') {
    agent { label 'windows' }
    steps {
        dir('failops/infra/terraform/vagrant') {
            bat """
                terraform init -backend-config="key=terra-infra/terraform.tfstate"
                terraform apply -var="app_enable=true" -var="vm_state=up" -auto-approve=true
            """
        }

        stash includes: 'failops/infra/output/**', name: 'output'
    }
}
```

When a stage switches to another agent (e.g., Windows), Jenkins by default performs an implicit **`checkout scm`** on that agent’s workspace.
- 📸 [Git Checkout SCM](./assets/git_scm.png)
- 📸 [Windows Workspace](./assets/path_workspace.png)

* `agent { label 'windows' }`: The pipeline will now move to the Windows agent and use the workspace at `C:\Jenkins\workspace\my-app-demo_develop\`.
* `stash includes: 'failops/infra/output/**', name: 'output'`:
  The **stash/unstash** mechanism is intended for files that are **not in Git** but are generated during the pipeline run (e.g., `failops/infra/output/Vagrantfile`).

Here’s the issue:

* During infrastructure provisioning, Jenkins checks out the Git repository, which contains an **empty `Vagrantfile`**.
* Provisioning then adds content to this `Vagrantfile`.
* In another stage (e.g., halting the VM), Jenkins again performs a Git checkout, which resets the workspace to the **empty `Vagrantfile`**. As a result, Vagrant cannot locate the `app` VM.

**Solution:**

* **Stash** the `Vagrantfile` after infrastructure provisioning.
* **Unstash** it in the halt stage.
* This ensures the generated `Vagrantfile` overwrites the empty one from Git and allows Vagrant to properly manage the VM lifecycle.

- `stash` → temporarily stores files from the current workspace.
- `unstash` → retrieves those files into the new workspace.

<br>

> **Note**:
> - Both staging and production environments run on the same VM using different ports.
> - This is acceptable for local labs. In production, separate IPs are preferred with standard port 80.
> - If resources permit, you may spin up distinct VMs for staging and production using `BRANCH_NAME = "${env.BRANCH_NAME "`.

<br>

# Deploy - Staging

```groovy
def deployApp(branchName, envName, backendPort, frontendDir, backendDir, backendService) {
    sshagent(credentials: ['app-vm-ssh']) {   
        sh """
            echo "Deploying ${branchName} to ${envName}..."

            mc cp $MINIO_ALIAS/$MINIO_BUCKET/frontend/$branchName/$BUILD_ID_TAG/frontend.zip ./frontend-app-${envName}.zip
            mc cp $MINIO_ALIAS/$MINIO_BUCKET/backend/$branchName/$BUILD_ID_TAG/backend.zip ./backend-app-${envName}.zip

            scp -o StrictHostKeyChecking=no frontend-app-${envName}.zip vagrant@192.168.56.11:~/
            scp -o StrictHostKeyChecking=no backend-app-${envName}.zip vagrant@192.168.56.11:~/

            ssh -o StrictHostKeyChecking=no vagrant@192.168.56.11 << EOF
                
sudo rm -rf ${frontendDir}/*
sudo unzip -o ~/frontend-app-${envName}.zip -d ${frontendDir}
sudo mv ${frontendDir}/build/* ${frontendDir}/
sudo rm -rf ${frontendDir}/build
sudo chown -R www-data:www-data ${frontendDir}
sudo rm ~/frontend-app-${envName}.zip

sudo unzip -o ~/backend-app-${envName}.zip -d ${backendDir}
sudo rm ~/backend-app-${envName}.zip
sudo chown -R vagrant:vagrant ${backendDir}

cd ${backendDir}
npm ci
sudo systemctl daemon-reload
sudo systemctl restart ${backendService}
sudo systemctl restart nginx                
EOF
        """
    }
}
pipeline {
    ...
    stage('Deploy to Staging') {
        when {
            branch 'develop'
        }
        steps {
            script {
                deployApp('develop', 'staging', '/var/www/my-app-staging', '/opt/my-app-backend-staging', 'my-app-backend-staging')
            }
        }
    }
}
```

> For Setup 1 deploy to staging will contain 
```groovy 
stage('Deploy to Staging') {
    when {
        branch 'develop'
    }
    environment {
      VAGRANT_CWD = "${WORKSPACE}/failops/infra/output"
    }
    ....
}
```
* `.vagrant` is **not** in the workspace root.
* When you provision, Terraform + Vagrant writes the state into:
```
  $WORKSPACE/my-app-demo_develop/failops/infra/output/.vagrant
```
* By default, when Jenkins starts a new shell in the next stage, the **current working directory is the workspace root**:

```
  $WORKSPACE/my-app-demo_develop
```
* From there, if you try to deploy to app vm without telling it where to look, Vagrant will **not walk into `failops/infra/output`**. It only checks the **current directory and parents** for a `Vagrantfile`.
* Since it doesn’t find one at the workspace root → Vagrant thinks “no VM is defined here” → VirtualBox ends up showing the VM as *aborted*.

📘 [Nginx setup reference](../../provision/setup-nginx.sh)

<br>

## **Step 1: Fetch Artifacts from MinIO**

```bash
mc cp $MINIO_ALIAS/$MINIO_BUCKET/frontend/$branchName/$BUILD_ID_TAG/frontend.zip ./frontend-app-${envName}.zip
mc cp $MINIO_ALIAS/$MINIO_BUCKET/backend/$branchName/$BUILD_ID_TAG/backend.zip ./backend-app-${envName}.zip
```

* Uses **MinIO Client (`mc`)** to download frontend and backend build artifacts.
* `$MINIO_ALIAS` → alias to your MinIO server (configured in Jenkins environment).
* `$MINIO_BUCKET` → the bucket name in MinIO where artifacts are stored.
* `$branchname/$BUILD_ID_TAG` → path inside the bucket; ensures each branch/build has its own artifact.
* `./frontend-app-${envName}.zip` → download and **rename locally** to include `${envName}` (staging/prod), avoids overwriting builds.
* Same for backend.

✅ **Purpose:** fetch the latest build artifacts for the branch/environment.

<br>

## **Step 2: Copy Artifacts to Remote VM**

```bash
scp -o StrictHostKeyChecking=no frontend-app-${envName}.zip vagrant@192.168.56.11:~/
scp -o StrictHostKeyChecking=no backend-app-${envName}.zip vagrant@192.168.56.11:~/ 
```

* `scp` → secure copy over SSH.
* `-o StrictHostKeyChecking=no` → It will **not prompt** for key checking manually & We gonna use our own generated **ssh-keygen**
* Copies frontend and backend zips **from Jenkins agent to the Nginx VM**.
* `vagrant@192.168.56.11:~/` → home directory of `vagrant` user on the remote VM.

✅ **Purpose:** Prepare the VM with the required build artifacts.

<br>

## **Step 3: SSH Into Remote VM**

```bash
ssh -o StrictHostKeyChecking=no vagrant@192.168.56.11 << EOF
```

* Opens an **SSH session to the VM**.
* Everything between `<< EOF` and `EOF` runs **on the remote VM**.

<br>

## **Step 4: Deploy Frontend**

```bash
sudo unzip -o ~/frontend-app-${envName}.zip -d ${frontendDir}
sudo rm ~/frontend-app-${envName}.zip
```

* `sudo unzip -o` → unzip the frontend artifact.

  * `-o` → overwrite existing files without asking.
  * `-d ${frontendDir}` → extract into the correct frontend directory (`/var/www/my-app-staging` or `/var/www/my-app-prod`).
* `sudo rm ~/frontend-app-${envName}.zip` → delete the zip after extraction to save space.

✅ **Purpose:** Deploy the frontend to Nginx.

<br>

## **Step 5: Deploy Backend**

```bash
sudo unzip -o ~/backend-app-${envName}.zip -d ${backendDir}
sudo rm ~/backend-app-${envName}.zip
```

* Same logic as frontend.
* Unzips backend to `/opt/my-app-backend-${envName}` (staging or prod folder).
* Removes zip afterward.

✅ **Purpose:** Backend code ready for Node.js service.

<br>

## **Step 6: Install Node.js Dependencies**

```bash
cd ${backendDir}
npm ci 
```

* `cd ${backendDir}` → go to backend directory (`/opt/my-app-backend-staging` or `/opt/my-app-backend-prod`).
* `npm ci` → install all Node.js dependencies from `package-lock.json`.

✅ **Purpose:** Ensure backend runs with all required modules.

<br>

## **Step 7: Restart Backend Service**

```bash
sudo systemctl restart ${backendDir}
```

* Restarts the systemd service (`my-app-backend-staging` or `my-app-backend-prod`) on the VM.
* Systemd service runs your Node.js backend (`server.js`) and keeps it alive. (e.g., 3001 for staging, 3002 for production).

✅ **Purpose:** Keep backend service active and updated.

<br>

## **Step 8: Restart Nginx**

```bash
sudo systemctl restart nginx
```

* Restarts Nginx so it picks up any **new frontend files or config changes**.
* Nginx serves frontend on ports 81 (staging) / 80 (prod) and proxies `/api/` to correct backend.

✅ **Purpose:** Make frontend live and ensure API requests route correctly.

<br>

## ✅ Summary

1. Fetch frontend/backend zip artifacts from MinIO.
2. Copy zips to the remote VM.
3. Unzip frontend and backend to the correct directories.
4. Install backend dependencies.
5. Restart backend service.
6. Restart Nginx to serve frontend + proxy API.
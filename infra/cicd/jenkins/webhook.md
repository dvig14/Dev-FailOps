# **CI/CD Trigger**

Since GitHub webhooks cannot directly reach a private IP (`http://192.168.56.13:8080`), we will use **ngrok** to create a secure tunnel. Ngrok establishes a bridge between your private IP and the public internet, allowing external services (like GitHub webhooks) to communicate with your Jenkins server.


## **Steps**

**1. Install ngrok** on your [host machine OS](https://ngrok.com/downloads/windows).

**2. Authenticate ngrok** with your account:

  * Go to [https://dashboard.ngrok.com](https://dashboard.ngrok.com) → signup → getting started(under it authtoken) →
  * show token & copy → `ngrok config add-authtoken $YOUR_AUTHTOKEN`

**3. Start ngrok**

* **Windows**: install → run ngrok desktop app
```bash
ngrok config add-authtoken <token>
ngrok http 192.168.56.13:8080
```

* **Linux/macOS**: Open terminal → Run in background with nohup
```bash
ngrok config add-authtoken <token>
nohup ngrok http 192.168.56.13:8080 > ngrok.log 2>&1 &
```
* This keeps ngrok running even after the terminal closes.
  * Logs output to `ngrok.log`.
  * To stop:

    ```bash
      pkill ngrok
    ```

<br>

You will see output like:

  ```
   Forwarding https://abc123.ngrok.io -> http://192.168.56.13:8080
  ```

Make sure the HTTPS link is accessible from outside your network.

> **Note:** Ngrok assigns a new URL on each start unless you reserve a domain (paid feature). Update your webhook accordingly if the URL changes.

<br>

4. **Multibranch Pipeline Setup** 📸
  [YouTube Tutorial](https://www.youtube.com/watch?v=K0cXljOGTS4)

5. **Configure GitHub Webhook**

   * Go to your repo → Settings → Webhooks → Add webhook
     📸 [Webhook Setup](https://www.youtube.com/watch?v=THGdNuX9bEo)

<br>

## **Pipeline Jenkinsfile (my-app-demo repo)**

```groovy
pipeline {
    ....
  stages {
    stage('Checkout') {
      steps {
        script {
          // App repo (auto checkout by webhook)
          checkout scm

          // Checkout only infra subfolders from Dev-FailOps
          dir('failops') {
            checkout([
              $class: 'GitSCM',
              branches: [[name: '*/master']],
              doGenerateSubmoduleConfigurations: false,
              userRemoteConfigs: [[
                url: 'https://github.com/dvig14/Dev-FailOps.git'
              ]],
              extensions: [[
                $class: 'SparseCheckoutPaths',
                sparseCheckoutPaths: [
                  [path: 'infra/terraform'],
                  [path: 'infra/provision'],
                  [path: 'infra/output']
                ]
              ]]
            ])
          }                                       
        }
      }
    }
  }
}
```

### **Understanding `checkout scm`**

The `checkout scm` step tells Jenkins:

> “Retrieve the source code from the SCM (Git, SVN, etc.) that triggered this build.”

**Under the hood:**

1. Jenkins reads the **SCM configuration** for this job (your GitHub repo linked via Multibranch Pipeline plugin).
2. It clones the repository (or fetches updates if already cloned) into the **workspace directory**.
3. In **Multibranch Pipelines**, Jenkins automatically:

   * Checks out the **correct branch** (`develop`, `main`)
   * Creates a **detached HEAD at the commit** that triggered the build
4. Jenkins sets environment variables automatically:

   * `BRANCH_NAME` → current branch
   * `GIT_COMMIT` → commit SHA
   * `GIT_URL` → repository URL

📸 [envs and log](./assets/envs.png)

<br>

#### **Why Detached HEAD?**

* Normally, `HEAD` points to a branch:

  ```
  HEAD → main → commit SHA
  ```
* A **detached HEAD** points directly to a commit:

  ```
  HEAD → commit SHA12345
  main → commit SHA12350
  ```

**Reason:**
Jenkins builds the exact state of the repo at the time of the triggering commit. This ensures **reproducibility and consistency**. Without detached HEAD:

* New commits could overwrite the branch pointer mid-build
* Build might not represent the commit that triggered it

**Example:**

* Dev A pushes `commit c1` → Build Job 1 runs (HEAD points to `c1`)
* Dev B pushes `commit c2` → Build Job 2 runs (HEAD points to `c2`)
* Both builds run independently and accurately reflect the commit state.

<br>

### **Sparse Checkout of Infra Subfolders**

```groovy
dir('failops') {
  checkout([$class: 'GitSCM',
    branches: [[name: '*/master']],
    userRemoteConfigs: [[url: 'https://github.com/dvig14/Dev-FailOps.git']],
    extensions: [
      [$class: 'SparseCheckoutPaths',
        sparseCheckoutPaths: [
          [path: 'infra/terraform'],
          [path: 'infra/provision'],
          [path: 'infra/output']
        ]
      ]
    ]       
  ])        
}
```

#### 🛠 What happens step by step

1. Jenkins enters directory `failops/`.
2. Git plugin clones `Dev-FailOps` repo but **only `master` branch**.
3. Sparse checkout filters so **only infra-related folders** are actually written to workspace instead of entire repo.
4. Now your Jenkins workspace will look like this:

```
workspace/
 ├── my-app-demo-files    # all files placed inside workspace folder
 └── failops/infra/       # from sparse checkout
      ├── terraform/
      ├── provision/
      └── output/
```
📸 [workspace](./assets/jenkins_workspace.png)



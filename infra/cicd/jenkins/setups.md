## Setup 1 : App VM running inside jenkins VM (Using Nested Virtulization)

### Enable Nested VT-x/AMD-V ON Jenkins VM

#### 1. Create Jenkins VM (if not already created):

```bash
  cd Dev-FailOps/infra/cicd/jenkins-server
  vagrant up
```

#### 2. Stop the VM:

```bash
  vagrant halt
```

#### 3. Enable Nested VT-x/AMD-V:
This allows the **App VM** to run inside the Jenkins VM and access CPU virtualization features.

```bash
  VBoxManage modifyvm <UUID | Jenkins-VM-Name> --nested-hw-virt on
```

#### 4. Verify in VirtualBox GUI (Host):

* Open **VirtualBox** on the host machine.
* Select **Jenkins VM → Settings → System → Processor**.
* Ensure **Enable Nested VT-x/AMD-V** is checked.

📸 [Nested VT-x/AMD-V](./assets/nested_vtx.png)

```
+-----------------------------------------------------+
|                     Host                            |
|  - Physical CPU with VT-x enabled                   |
|  - VirtualBox installed                             |
|                                                     |
|  Jenkins VM (Guest VM, 64-bit)                      |
|  - Nested VT-x enabled in host VirtualBox           |
|  - Can run 64-bit VMs because host exposes VT-x     |
|                                                     |
|    App VM (Guest VM inside Jenkins VM)              |
|    - 64-bit Ubuntu Jammy64                          |
|    - Gets VT-x via nested virtualization            |
|    - Can boot successfully because Jenkins VM       |
|      exposes VT-x                                   |
+-----------------------------------------------------+
```

<br>

### SSH into Jenkins VM to install additional packages/tools used by the pipeline

```bash
vagrant ssh

sudo apt-get update
sudo apt-get install -y zip

# Install terraform
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt-get update -y && sudo apt-get install terraform -y

# [Install Vagrant + Virtualbox (For Linux: Ubuntu24)](https://github.com/dvig14/Devops/blob/master/Preq.md)
# [Set IP Forwarding So Host Machine Can Ping App VM (Diff Subnets) - ./network-concepts.md] 
# [Install Cypress Dependencies For Frontend E2E Testing - ./deploy-prod.md]
```

<br>

## Setup 2 : App VM runs on host machine (Using Agents)

📘 [Read agents.md](./agents.md)

### 1. Install Java on Windows

* Download and install the [Oracle JDK x64 installer](https://www.oracle.com/in/java/technologies/downloads/#jdk24-windows).
* Configure environment variables:

  * Search **Environment Variables** → **Advanced** → **Environment Variables**
  * Under **System variables**, find **Path** → **Edit** → **New** → Paste the full path to the JDK `bin` folder, e.g.:

    ```
    C:\Program Files\Java\jdk-24\bin
    ```
* Verify installation:

  ```powershell
  java --version
  ```

<br>

### 2. create windows agent node

* Navigate to **Jenkins UI → Manage Jenkins → Nodes and Clouds → New Node**.
* Enter a name (e.g., `windows`) → Select **Permanent Agent** → **Create**.
  - **Executors**              → `1` (how many builds can run in parallel).
  - **Remote root directory**  → `C:\Jenkins`.
  - **Labels**                 → `windows` (so pipeline stages can target it using `agent { label 'windows' }`).
  - **Usage**                  →  `with label expressions matching this node`.
  - **Launch method**          →  `Launch agent by connecting it to controller`.
  - **Availability**           →  `Keep this agent online as much as possible`.

👉 Once saved, Jenkins generates a **secret token** and a **command** for this agent.

<br>

### 3. Connect agent to jenkins Once windows agent created 
* Go to **Manage Jenkins → Nodes → Select windows agent** → Copy the generated connection commands.
* On the Windows machine:

  * Open **CMD** and run the commands one by one:

  ```powershell
  curl.exe -sO http://<jenkins-controller-ip>:8080/jnlpJars/agent.jar
  ```

**Why this step?**

* The agent requires software to communicate with Jenkins.

* `agent.jar` is the Java program that enables the agent to “talk” to the Jenkins Controller.

* Each Jenkins controller provides its own `agent.jar` at:

```
  http://<controller>:8080/jnlpJars/agent.jar
```

This ensures version compatibility between controller and agent.

* Then run the provided Java command:

```powershell
  java -jar agent.jar -url http://<controller-ip>:8080/ -secret <secret-token> -name windows -webSocket -workDir "C:\Jenkins"
```

**What happens here:**
- `-url`       → Tells agent where the controller lives.
- `-secret`    → Used to prove this machine is the authorized node you created.
- `-name`      → Matches the node name created in Jenkins UI.
- `-webSocket` → How agent communicates with controller (lightweight channel).
- `-workDir`   → Local folder for Jenkins files, builds, and logs.

<br>

### 4. Verify Connection

* After running the command, the **Windows agent** should show as **connected** in Jenkins UI.

<br>

### 5. Important Note

* If the **terminal window is closed**, the connection stops and the agent goes offline.
* To make the agent **permanent**, configure it to run as a **Windows Service**.
* For lab/demo purposes, keeping it as a visible CMD session is useful (you can see VM provisioning, apps starting, browser checks, etc.).
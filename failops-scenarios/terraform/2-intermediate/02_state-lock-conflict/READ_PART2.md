
## 📚 Contents

- [Simulation -> State Lock Behavior](#-what-happens-if-state-is-locked)
- [State Lock Conflicts](#-state-lock-conflicts)
- [What Causes Lock Conflicts](#-what-causes-state-lock-conflicts)
- [Real World Impact](#-real-world-impact)
- [Mental Model Guide](#-before-you-pick-a-fix)
- [Fix Guide](#-next-step-how-to-fix-it-with-examples)

<br>

## 🧨 What Happens If State Is Locked?

### 🔬 Steps to Break It

### 1. Install consul

- [Install consul](https://developer.hashicorp.com/consul/install)

> ⚠️ **Windows Users**
>
> * Extract the downloaded folder and add it to your system PATH.
> * And you're using Git Bash, you also need to export the path manually:

```bash
echo 'export PATH=$PATH:<your-path>' >> ~/.bashrc
source ~/.bashrc
```

<br>

### 2. Start consul server

> **Recommended:** [Halt the MinIO](../../README.md#-destroy-or-halt-vms-after-scenario-completion) VM before starting 

Run:

```bash
cd ../terraform/vagrant

# Run Consul server in the background
nohup consul agent -dev -bind=127.0.0.1 > .terraform/consul.log 2>&1 &

# Access the web UI
http://127.0.0.1:8500/
```

**Explanation:**

* `consul agent`: Starts a local Consul agent.
* `-dev`: Runs in development mode (in-memory state, not persisted).
* `-bind=127.0.0.1`: Makes it available on localhost (for Terraform to connect)

> ⚠️ `-dev mode` : Not for production use, state is wiped on restart.

<br>

### 3. Configure consul backend for state locking

1. Open **two VS Code editors** pointing to the **same Terraform project**.
2. In both editors:

   * Uncomment the **Consul backend** block.
   * Comment out the **MinIO S3 backend** (as S3 alone doesn’t support locking).

> In real-world use, teams typically use **S3 + DynamoDB** for state storage and locking.

📸 [See backend.tf](./assets/consul.png)

<br>

### 4. Reconfigure the backend for both Users

In each terminal window (User A and User B), run:

```bash
terraform init -reconfigure
```

Terraform will:

* Stop using the previous MinIO (S3) backend.
* Switch to Consul backend.
* Look in Consul for a matching state.

If:

* ❌ No state found → Treats it as a **fresh project**, planning to re-create all resources.
* ✅ State exists (Manually added or Migrated from minio) → Uses the **Consul state file**.

<br>

> ⚠️ Existing `.tfstate` from MinIO **is not migrated automatically.**

📸 [Reconfigured backend](./assets/reconfigure.png)

<br>

### 5. Create the initial state file

Run only in **User A’s** terminal:

```bash
terraform apply
```

* This initializes the state and stores it in Consul.
* Verify in Consul UI:
  `http://localhost:8500` → **Key/Value** tab → Key: `terraform/state/app`

Stored as key-value:
* Key: `terraform/state/app`
* Value: Terraform state file contents

📸 [Acquiring state lock & Creating resources](./assets/initial_apply.png)

<br>

### 6. Each user makes changes

* **User A**: Modifies the content of a `local_file` resource.
* **User B**: Adds a new resource `random_id.state_conflict`.

📸 [Code changes example](./assets/code_change.gif)

<br>

### 7. Simulate parallel `terraform apply`

- Run `terraform apply` in **User A’s** terminal.
- After that, try the same in **User B’s** terminal.

<br>

> ⚠️ **Don’t confirm with "yes" yet**:
>
> 1. Open `http://localhost:8500` and go to the **Key/Value** tab.
>        Navigate to the key: `terraform/state/📁app`
>
> 2. **Refresh** - Here you'll see lock-related entries like `.lock` and `.lockinfo`, which represent the current lock session.
>
> 3. Simply press **Enter** in the terminal to cancel the `terraform apply`.
>
> 4. Go back to `http://localhost:8500` → **Key/Value** tab → open the `terraform/state` path.
>     **Refresh** - you should now see that the lock entries are gone, meaning the state is no longer locked.

📸 [Output showing lock for User-B](./assets/lock-b.png)

<br>

**What Happens:**

* User B sees an error : state is locked.

```text
Error: Error acquiring the state lock
│
│ Error message: Lock Info:
│   ID:        d02dd7d5-6851-e2b5-bc82-3e17b06ac64b
│   Path:      terraform/state/app
```

🔒 Terraform acquires the lock **immediately** when `terraform apply` starts even before you confirm.

Lock stays:

* Throughout the `plan` phase.
* Until the apply is either **finished** or **canceled**.

> Prevents multiple users from applying based on outdated state.

<br>

### 8. Let user-b try again

In **User B’s** terminal, run:

```bash
terraform apply
```
📸 [Apply User-B](./assets/apply-b.png)

✅ Since User A’s apply was canceled, the lock is released → User B can now apply.

<br>

> ⚠️ **Confirm with "yes" then press `Ctrl+C` to interrupt apply**:
>
> Go back to `http://localhost:8500` → **Key/Value** tab → open the `terraform/state` path.
>  - **Refresh** - the lock entries are still present.
>  - This results in a **stale lock**, which can block future operations indefinitely.

📸 [Stale lock](./assets/lock-a.png)

<br>

> 🧠 **Note**:
>
> * If you try `terraform apply` again after a few seconds, it may succeed.
> * This is because Consul sessions have a **built-in TTL** (typically 15–60 seconds).
> * You can see in `.lock` file 📸 [Lock session](./assets/lock_session.png)
> * We'll dive deeper into how this mechanism works in **`fix.md`**.

<br>

## 🧱 State Lock Conflicts

You may now ask:

1. **How will users know** when someone else’s lock is released and they can apply again?
2. **What happens if the apply crashes** (e.g., `Ctrl+C` as we did in previous step, CI job fails mid-apply)

<br>

## 🚨 What Causes State Lock Conflicts?

| Cause                                | Description                                                     |
| ------------------------------------ | --------------------------------------------------------------- |
| 💥 Terraform crash                   | Terminal or network failure before releasing the lock           |
| 🧑‍🤝‍🧑 Concurrent applies                | Two users apply simultaneously → one fails due to lock conflict |
| 🖥️ CI/CD pipeline overlap            | Multiple jobs run `apply` on same state before lock is released |
| 🐞 Incomplete cleanup or permissions | Lock not released due to bugs or permission issues              |

<br>

## 🌍 Real-World Impact

### ✅ 1. Pipelines Running in Parallel

(*Most Common Cause*)

| Situation | Two or more CI/CD jobs apply to the **same state** at the same time. |
| --------- | -------------------------------------------------------------------- |
| Impact    | One job **locks the state**, others **fail or hang** waiting.        |

<br>

### ✅ 2. Crashes or Mid-Apply Interruptions

(*Occasional but Serious*)

| Situation | CI job crashes, is killed, or network fails during `terraform apply`|
| --------- | ------------------------------------------------------------------- |
| Impact    | Lock remains stuck in backend (e.g., Consul/DynamoDB).              |
|           | Terraform **thinks someone is still applying**.                     |

<br>

### ✅ 3. Unknown Lock Ownership

(*Frustrating for Teams*)

| Situation | Lock is active, but you don’t know `who` or `what` owns it.             | 
| --------- | ----------------------------------------------------------------------- |
| Impact    | Teams **wait unnecessarily** or **force-unlock** without context.       |

<br>

## ❓ Before you pick a fix…

- Go to 📘 [mental-model.md](../../../mental-models/terraform-model.md#-failure-root-map-where-things-go-wrong)
- Find which **core problem type** your failure matches.
- Then return here and see which fix path applies.

<br>

## ✅ Next Step How to Fix It (With Examples)

👉 [Fix Guide & Best Practices](./fix.md)

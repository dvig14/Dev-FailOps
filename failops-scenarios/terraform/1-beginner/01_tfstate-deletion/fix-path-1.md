## 🧩 Problem Recap

You **deleted the Terraform state file**.

Now:

* Terraform **no longer knows** what resources exist.
* `terraform destroy` → does nothing ❌
* `terraform apply` → recreates everything 💥 (or tries to)

In local Vagrant labs, this might look safe, but in **real cloud**, it's a **serious risk**.

<br>

## 🧠 Ask These Before You Fix

1. Is versioning enabled on your remote backend (e.g. MinIO / S3)?
2. Does the infra still exist physically?
3. Do you know what resources were created (e.g. VMs) and have access to the resource IDs?
4. Is this environment **production or safe to destroy**?
5. Can you safely recreate the infra — or must you restore it?

Your answers guide which **fix path** is safest.

<br>

## 🗂 Fix Path 1: Restore backup from MinIO versioning

### 🧠 What is Versioning?

When you upload a new file (or delete one), S3 saves the old version instead of replacing or erasing it.
That means:
- You can always go back in time and restore any previous version.
- Even deletions don't erase data — they just add a "delete marker"

<br>

### 🛠 Fixing Our Lab

- ✅ Prerequisite: Your backend is set to use MinIO with versioning **enabled**.
- [Minio setup](../../../../infra/minio-server-S3/README.md)
- 📁 Bucket name: `terra-state`
- 📁 Path inside bucket: `terra-scenarios/01_tfstate-deletion/terraform.tfstate`

<br>

### 1️⃣ Open MinIO UI

* Navigate to: `http://192.168.56.22:9001`
* Locate the bucket: `terra-state`
* Navigate inside: `terra-scenarios/01_tfstate-deletion/terraform.tfstate`

<br>

### 2️⃣ View File Versions

* Click the file name (`terraform.tfstate`)
* Select the **"Display Object Versions"** tab
  - 📸 [Display Object Versions](./assets/minio.png)
* You'll see a list of past versions:
  - 📸 [All state versions](./assets/versions.png)

> ℹ️ The latest version (at the top) is empty state created after `terraform destroy`.

<br>

### 3️⃣ Before restoring:

```bash
terraform plan
```

* Output will show **Terraform wants to create all resources again**, because it **thinks nothing exists**.
- 📸 [Before restoring](./assets/plan_before_fix.png)

<br>

### 4️⃣ Restore the Previous Version

* From the version list, identify the version **just below the deleted one** (the one with actual state).
* Click the **Restore (⟳)** icon on the right.
* MinIO creates a new version — now the **current version** is the correct one.
  ✅ You're restored!

### [🔍 Verify](./verify.md#-verify-path-1-restore-backup-from-minio-versioning)  

<br>

## 🧑‍💼 Real-World Scenario: Why This Matters

Imagine you're working in production:

* Terraform stores its state in an **S3 bucket**.
* Someone accidentally **deletes the state file** or it becomes **corrupted**.
* Terraform suddenly believes the infrastructure doesn’t exist.
* Running `terraform apply` now **recreates everything** — which may destroy live infrastructure!

But with versioning enabled:

* You recover within seconds.
* Zero downtime.
* No need to manually import or reconstruct state.

<br>

## 🧨 What If Versioning Wasn’t Enabled?

You're in trouble.

* Deleted `terraform.tfstate` means Terraform **no longer knows what resources it owns**.
* Apply will **recreate** everything.
* Real servers or data could be **duplicated** or **overwritten**.

That's when we switch to [👉 Fix Path 2: Rebuild State Using `terraform import`](./fix-path-2.md)

> Before starting that, delete the current version state file. 

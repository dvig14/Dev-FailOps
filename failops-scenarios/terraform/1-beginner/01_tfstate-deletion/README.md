# 🧨 Scenario: `01_tfstate-deletion`

<br>

## 📚 Contents
- [What is terraform.tfstate?](#-what-is-terraformtfstate-and-why-is-it-needed)
- [Why Use Remote Backend](#️-why-use-a-remote-backend-like-minio)
- [What Happens When It’s Deleted](#-what-happens-if-the-state-file-is-deleted)
- [Real World AWS Example](#-real-world-impact)
- [Fix Guide](#-next-step-how-to-fix-it-with-examples)

<br>

## ❓ What is `terraform.tfstate` and Why Is It Needed?

Terraform state is a file that **keeps track of the infrastructure** created by Terraform.

- After you run `terraform apply`, the state file is created — it stores the **entire infrastructure** in JSON format.
- Terraform uses it like a **graph**, so when something changes, it calculates a **diff** instead of recreating everything.
- This state file can be stored:
  - ✅ Locally (not recommended for teams)
  - ✅ Remotely for example:
       - **AWS S3 bucket** in cloud projects
       - In our local simulation: **MinIO S3-compatible bucket**

<br>

## ☁️ Why Use a Remote Backend Like MiniO?

In real-world scenarios:

> Multiple teams often work on the same infrastructure.

- For example, a web app might have different teams managing:
  - Database layer
  - App layer
  - Networking / DNS
- If everyone uses **local tfstate**, they’ll all manage different versions of reality — causing chaos.

### ✅ Remote State (e.g. MinIO or AWS S3)

- Stores state in **one central place**
- Everyone reads/writes the same version
- Ensures consistency and prevents infra duplication

### 🧪 Example

> You and your teammate work on the same Terraform repo.

✅ With MinIO (or S3) as remote backend:
- Both of you share one state file
- No drift or duplicate infra

🚫 With only local state:
- Each of you might create your own copy of a VM
- Terraform has no idea others exist
---
> You may think can’t we just push `terraform.tfstate` to GitHub?

  You’re right to ask — but we **should not**.  
  Why?

- It may contain **sensitive information** like:
  - AWS access keys
  - Passwords
  - Secrets in plaintext

✅ So we use **remote state storage** (like S3/MinIO) to:
- Share state securely
- Avoid secrets in GitHub
- Enable collaboration across teams

<br>

## 🧨 What Happens If the State File Is Deleted?

Let’s simulate what happens when it’s **deleted**.


### 🔬 Steps to Break It

**1. Assumption:** You’ve already started the MinIO server, created the S3 bucket, and initialized Terraform.

   - This provisions your VM and stores state in MinIO.
   - Terraform tracks all resources.

   - [Resource creation](./assets/creation.gif)
   - [Resources created](./assets/created.png)

<br>

**2. Confirm state tracking works** 
 
   ```bash
     terraform apply
   ```
   - Run 2 times :
     - 1st time - It will destroy one resource because its how I designed logic for vagrantfile to not upgrade once vm enabled
     - 2nd time - It should show: **No changes** Infrastructure matches the configuration.

   - [No changes](./assets/no_changes.png)

<br>

**3. Get the Resource ID of `random_id.demo_for_import_fix`**

   ```bash
     terraform state show random_id.demo_for_import_fix
   ```
   - Save the `id` field, you'll use it to import the resource back into state needed (for `terraform import`) fix.

   - [Resource id](./assets/resource_id.png)

<br>

**4. ❌ Now delete `terraform.tfstate` file manually from MinIO.**

<br>

**5. ⛔ Try to destroy infra** 

   ```bash
     terraform destroy
   ```
   - Expected: It should destroy the VM
   - Reality: Nothing to destroy.

   ❌ It doesn't because Terraform has no memory of the resource anymore!

   - [Untracked resources](./assets/no_destroy.png)

   > It will create `empty tfstate file`
   > {
   >   "version": 4,
   >   "terraform_version": "1.8.x",
   >   "serial": 0,
   >   "lineage": "new-lineage-id",
   >   "outputs": {},
   >   "resources": []
   > }

<br>

**6. 🎯 The VM is still running:**
   - No more tracking. 
  
   - [Orphaned VMs](./assets/orphaned_vm.png)

<br>

**7. 🔁 Re-Apply After State Loss:**
   
   > ❌ Do NOT run this unless you want to recreate all resources.
   > This step is just to demonstrate what happens if `*.tfstate` is deleted and `terraform apply` again.  

<br>

   ```bash
     terraform plan
     terraform apply
   ```
   - Now Terraform sees no state
   - So it thinks nothing exists and tries to create all resources again

   - [Re-creation](./assets/re_creation.png)
   - [After re-creation](./assets/orphaned_vm.png)
  
<br>

   > Even though `virtualbox` or `vagrant global-status` shows 1 sandbox VM running,
   > it's because **Vagrant handles VM lifecycles itself** — it doesn't create a new VM of the same name.
   >
   > Terraform, however, doesn't know that. Since the `.tfstate` is deleted,
   > it **runs the Vagrant commands again** via `local-exec`, thinking it’s provisioning from scratch.
   > But under the hood, Vagrant just **spins up the same existing VM** — no duplicate VMs are created.
   >
   > Terraform simply records this as a "new" resource in the `.tfstate`,
   > even though **nothing fresh was actually created**.
  
<br>

   ⚠️ **Important:**

   > In **real cloud providers** like AWS, Azure, GCP — there’s **no Vagrant-like mechanism** to detect existing resources.
   > So **deleting `.tfstate` and running `terraform apply` again will provision actual new infrastructure**
   > (e.g., a **new EC2 instance**), potentially causing **duplicate and orphaned resources** and unexpected **billing.**

<br>

## 🧠 Real-World Impact

### Example: AWS Setup

Let’s say you're provisioning this:

```hcl
resource "aws_instance" "app" {
ami           = "ami-xyz"
instance_type = "t2.micro"
}

resource "aws_route53_record" "dns" {
zone_id = "Z1234567890"
name    = "app.example.com"
type    = "A"
ttl     = 300
records = [aws_instance.app.public_ip]
}
```

This setup:

* Provisions an EC2 instance ✅
* Gets its public IP ✅
* Creates a DNS record (via Route 53):

  ```
  app.example.com ➝ 3.7.212.15
  ```

<br>

## 💥 Then You Delete `terraform.tfstate`

Now Terraform forgets what it made.

### ➤ What Actually Happens

| ✅ Resource | ✅ Still Exists | ❌ Terraform Thinks |
| ---------- | -------------- | ------------------ |
| EC2        | Yes            | "It doesn't exist" |
| Route 53   | Yes            | "I never made it"  |

<br>

### ➤ You Run `terraform apply` Again

* New EC2 instance is created → gets new IP
* New Route 53 record might be created

<br>

### ✴️ Outcome 1: DNS is Recreated

```
app.example.com ➝ New IP (13.126.42.98)
```

* Old EC2 instance still lives (orphaned)
* You start **paying for two EC2 instances**
* One is forgotten → no updates, no monitoring

<br>

### ✴️ Outcome 2: DNS Is Not Recreated

```
app.example.com ➝ Still points to old IP
```

* You think you're testing new instance
* Users still access old one
* Leads to confusion, errors, and downtime

<br>

## 🔥 Risks and Consequences

| 🧨 Risk                     | 🚨 Consequence                                                    |
| --------------------------- | ----------------------------------------------------------------- |
| Untracked resources         | Can’t safely destroy, update, or roll back infra                  |
| Orphaned VMs/Databases      | Wasted cost, security holes, unmanaged production resources       |
| Dangerous re-creations      | New infra is created blindly — may lead to downtime or overwrites |
| Breaks automation pipelines | CI/CD expecting a known state fails or causes drift               |

<br>

## ✅ Next Step How to Fix It (With Examples)

- 👉 [Restore backup from MinIO versioning](./fix-path-1.md)
- 👉 [Rebuild State Using `terraform import`](./fix-path-2.md)
- 👉 [Recreate + Manually clean orphaned infra](./fix-path-3.md)

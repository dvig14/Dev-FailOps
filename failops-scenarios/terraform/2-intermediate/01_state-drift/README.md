# 🧨 Scenario: `state-drift`

<br>

[⚠️ Before Starting New Scenario Setup Safe Environment](../../../safe-env.md)

<br>

## 📚 Contents

- [What Is State Drift And Why It Happens](#-what-is-state-drift)
- [Simulation -> Drift Locally](#-what-happens-if-we-change-something-outside-terraform)
- [Real World AWS Example](#-real-world-impact)
- [Potential Risks Of Drift](#️-potential-risks-in-prod-from-drift)
- [Mental Model Guide](#-before-you-pick-a-fix)
- [Fix Guide](#-next-step-how-to-fix-it-with-examples)

<br>

## ❓ What is `state drift`?

State drift occurs when the **actual infrastructure (infra)** is changed outside of Terraform — for example, directly through a cloud provider’s console or via scripts — and Terraform is **not aware of it**.

Terraform relies on the `.tfstate` file to know what exists and how it was last configured. If the real-world infrastructure changes, but the `.tfstate` is not updated, Terraform will make decisions based on **outdated or incorrect assumptions**.

<br>

### 🧠 Why State Drift Happens

| Cause                             | Example                                                          |
| --------------------------------- | ---------------------------------------------------------------- |
| Manual edits in the cloud console | Developer changes an EC2 instance from `t2.micro` → `t2.large`   |
| External provisioning tools       | CI/CD pipeline applies Ansible or CloudFormation                 |
| Auto-changes from cloud services  | Auto Scaling modifies resources, monitoring tools adjust configs |

<br>

## 🧨 What Happens If We Change Something Outside Terraform?

<br>

> 🧪 *This is a **local simulation** of state drift, results may drifferent from real-world cloud infrastructure*

<br>

### 🔬 Steps to Break It

### 1. Assumption: You’ve already started the MinIO server, created the S3 bucket, and initialized Terraform.

- This provisions your VM and stores state in MinIO.
- Terraform tracks all resources.
   
- 📸 [Resources created](./assets/created.png)

<br>

### 2. Confirm state tracking works 
 
```bash
   terraform apply 
```
- Run 2 times if you did this (`terraform apply -var="sandbox_enable=true"`) during **step-1**:
   - 1st time - It will destroy one resource because its how I designed logic for vagrantfile to not upgrade once vm enabled
   - 2nd time - It should show: **No changes** Infrastructure matches the configuration.

- 📘 [How plan and apply works](../../../mental-models/terraform-model.md)
- 📸 [No changes](./assets/no_changes.png)

<br>

### 3. Introduce Manual Change (Drift)

Modify the file manually [sandbox.sh](../../../../infra/provision/sandbox.sh)

```bash
#!/bin/bash
echo FailOps Lab
```
> This simulates a manual edit i.e. real infrastructure is now different than what Terraform expects.

<br>

### 4. Check Drift via `terraform plan`

```bash
terraform plan
```
- 📸 [Plan drift output](./assets/drift_plan.png)
- 📸 [Manual Change](./assets/manual_chng.png)

<br>

This scenario shows Terraform planning to **recreate the `local_file` resource**, but it’s not a *true infrastructure drift* as terraform can't read disk files.

In a **real drift case**, the output would resemble:

```hcl
# local_file.example will be created
  +/- resource "local_file" "example" {
      +/- content = <<-EOT
          #!/bin/bash
          echo FailOps Lab          =>   echo Hello from sandbox VM, no real provisioning needed.
        EOT
      ...
  }
```

<br>

> **🧠 What’s Actually Happening?**

Terraform compares the three layers:

```
Code         ↔        State         ↔        Infra
*.tf files         *.tfstate           (e.g., sandbox.sh)
```

* You manually changed the actual infrastructure (e.g., edited `sandbox.sh`) outside of Terraform's control.
* Now, when you run `terraform plan`, here’s the internal process:

<br>

**1. Terraform compares `State ↔ Infra`:**

   * It detects the real-world infra (e.g., contents of `sandbox.sh`) has changed.
   * So it **refreshes the state** in-memory to match the real infrastructure.
   * ⚠️ This refresh does **not update the `.tfstate` file on disk** — it stays in-memory.

<br>

**2. Then compares `State ↔ Code`:**

   * Now the refreshed in-memory state is compared to your `.tf` code.
   * Here, it detects the **drift**.

<br>

**🧾 In-memory (Refreshed) State:**

> It's just for assumption otherwise terraform doesn't read local_file content.
> As it can't handle OS operations. 

```bash
echo FailOps Lab
```

<br>

**📄 Desired Code (`.tf` file):**

```bash
echo Hello from sandbox VM, no real provisioning needed.
```

> ✅ Result: Terraform detects a difference and plans to recreate the resource.

<br>

### 5. Run `terraform apply`

> ❌ Do NOT Run This.
> This step is just to demonstrate what happens if state is drifted and we run `terraform apply`.  

```bash
terraform apply
```

This step will:

* **Destroy the existing resource** (which was manually modified outside Terraform)
* **Create a new resource** based on what’s in the current `.tfstate` and `.tf` code.

<br>

🔁 The outcome: Your **manual changes are lost**, even if you didn't intend to remove them.
- 📸 [Manual changes gone](./assets/drift_apply.gif)

<br>

**⚠️ Why This Matters**
- In this local example, it may seem harmless but let’s walk through the **real-world production risk**.

<br>

## 🧠 Real-World Impact

You deploy an EC2 instance via Terraform:

```hcl
instance_type = "t2.micro"
```

Later, someone from your team manually changes the instance type in the **AWS Console** when sees more traffic and then later forget to made change to code:

```
t2.large
```

Now you have three different versions of "truth":

| Layer               | Value      |
| ------------------- | ---------- |
| Terraform Code      | `t2.micro` |
| Terraform State     | `t2.micro` |
| Real Infrastructure | `t3.large` |

<br>

### ❓What Happens If You Run `terraform apply`?

**1. Refresh Phase** : It refreshes state with actual infra and updates in-memory

**2. Diff Phase** : Terraform compares

```
Code        ↔        State   (in-memory)     
t2.micro             t3.large    
```

Terraform sees:
- Drift, both are out of sync
- But it consider what is written in code (desired infra)
- Therefore, proceeds as follows:

```diff
~ instance_type: "t3.large" => "t2.micro"
```

<br>

Now here’s the key point:

> ✅ **Changing `instance_type` requires replacement**

So Terraform will:

1. 🔥 Destroy the current EC2 instance (`t3.large`)
2. 🆕 Create a new EC2 instance (`t2.micro`)

<br>

### ⚠️ This Causes Real Issues in Production:

* ⛔ **Downtime** — instance gets destroyed
* ⛔ **Data Loss** — if not using EBS volumes or proper lifecycle policies
* ⛔ **IP Change** — unless Elastic IP is attached

> This is **not a silent update** — it's a **destroy + recreate**, which can be **disruptive and dangerous**.

<br>

## 🔍 Key Insight

Even though `terraform apply` **asks for approval** (interactive prompt), this doesn't help in:

* **CI/CD pipelines** with `auto-approve`
* **Scripts** or automation tools running without review
* **Inattentive usage** by devs who skip reading the plan

> ✅ This means: **drift can silently wipe out manual or emergency changes** unless you're alert or unless drift detection is part of your pipeline.

<br>

## ☠️ Potential Risks in Prod from Drift:

| Drift Type                  | Real Impact                                      |
| --------------------------- | ------------------------------------------------ |
| Manual security group edits | Terraform reopens closed ports (security breach) |
| Manual instance deletion    | Terraform recreates old server (wrong config)    |
| Auto scaling group updates  | Drifted launch config causes broken autoscaling  |
| Console RDS param change    | Terraform reverts DB to older settings           |
| IAM policy drift            | Terraform re-applies looser permissions          |

<br>

## ❓ Before you pick a fix…

- Go to 📘 [mental-model.md](../../../mental-models/terraform-model.md#-failure-root-map-where-things-go-wrong)
- Find which **core problem type** your failure matches.
- Then return here and see which fix path applies.

<br>

## ✅ Next Step How to Fix It (With Examples)

<details>
<summary>Fix Guide</summary>

- 👉 [Sync State Using `terraform refresh`](./fix-path-1.md)
- 👉 [Add Manual Created Resource In State Using `terraform import`](./fix-path-2.md)

</details>
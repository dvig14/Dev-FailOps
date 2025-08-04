# 🧨 Scenario: `state-lock-conflict`

<br>

[⚠️ Before Starting New Scenario Setup Safe Environment](../../../safe-env.md)

<br>

## 📚 Contents

- [What Is State Locking?](#-what-is-state-locking)
- [Simulation -> Scenario Without State Lock](#-what-happens-if-state-is-not-locked)
- [Real World Impact](#-real-world-impact)
- [Why Locking Important](#-why-state-locking-is-critical)
- [Simulation -> State Lock Behavior](#️-next-step-simulate-what-happens-with-state-lock-enabled)

<br>

## ❓ What Is State Locking?

Terraform uses a **state lock mechanism** during critical operations like `apply`, `plan`, or `destroy`. This lock ensures that **only one process modifies the state file at a time**, which is especially important when using **remote backends** (e.g., MinIO, AWS S3, Terraform Cloud).

Without locking, **simultaneous changes by different users or pipelines can corrupt your infrastructure state** leading to unpredictable and dangerous results.

<br>

## 🧨 What Happens If State Is Not Locked?

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

### 3. Simulate Two Parallel `apply` Operations

* Open **two VS Code editors** pointing to the **same Terraform project**.

  * **User A** modifies the content of a `local_file` resource.
  * **User B** adds a new resource `random_id.state_conflict`.

Both users:

* Share the **same remote backend state file**.
* Independently update their `.tf` files and run `terraform apply`.

- 📸 [Two parallel applies](./assets/apply_two.gif)
- 📸 [Overwritten changes](./assets/show_output.gif)

<br>

🔥 **Outcome:**

* Both applies appear to succeed independently.
* However, **only User A’s changes** are properly reflected in the final `terraform.tfstate`.
* Assume If it's Real Infra:
  * **User B’s resource still exists in infra** but it’s no longer tracked in the state file.

This creates an **orphaned resource** which Terraform cannot manage or destroy later.

<br>

## 🧠 Real-World Impact

Imagine a production deployment scenario:

* You are deploying an EC2 instance named `web-server`.
* Your teammate is deploying another EC2 named `db-server`.

Both use the same remote state backend **without locking**.

❌ **Impact:**

* The last person to apply their changes **overwrites the entire state**.
* As a result:
  * Only `db-server` appears in Terraform’s state.
  * Both EC2s exist in AWS, but only one is tracked.

* If you run `terraform destroy`, only one EC2 will be removed.
  * The other becomes an **orphaned resource** : still **live**, still **billing** and completely **invisible to Terraform**.

<br>

## ✅ Why State Locking Is Critical

* It's like a **"Do Not Disturb" sign** on the state file.
* Ensures **one person or one process** makes changes at a time.
* Prevents **conflicts, corruption, orphaned infra, and debugging nightmares**.

<br>

## ➡️ Next Step: Simulate What Happens With State Lock Enabled

[Locked State – README_Part2](./READ_PART2.md)
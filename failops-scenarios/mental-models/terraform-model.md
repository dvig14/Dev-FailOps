# 🧠 Terraform Failure Mental Model Guide

This guide helps you identify **where Terraform is breaking internally**, and how to resolve failures using root-layer thinking - not error memorization.

<br>

## ✅ Core Terraform Layers (Where Problems Arise)

Terraform constantly tries to reconcile these 3 systems:

| 🧠 **Layer** | 💬 **What It Represents**                     | ⚠️ **When It Breaks**                      |
| ------------ | --------------------------------------------- | ------------------------------------------ |
| **Code**     | Your `.tf` files — the desired infrastructure | Bugs, bad inputs, logic or module mistakes |
| **Infra**    | What’s *actually deployed* in the cloud       | Manual changes, drift, unmanaged infra     |
| **State**    | Terraform’s memory of infra (`.tfstate`)      | Corruption, deletion, backend issues       |

<br>

> 🔁 Terraform syncs these via `init`, `plan`, and `apply`.:

```txt   
       Real Infra
           ⬏
      (Refresh Phase)
           ⬍
     Current State  ————→ compared with ———→  Terraform Code            
```

<br>

## ✅ Terraform Execution Process (during `terraform plan` or `terraform apply`)

### 🧠 Step-by-Step Execution:

<br>

**1. Refresh Phase (State ↔ Infra):**

> *(Only happens if a state file exists)*
> ⚠️ **If no state file exists**, this phase is **skipped** — Terraform doesn’t know what to refresh.

* Reads the current terraform.tfstate
* Calls the **cloud provider’s APIs** to get the **actual real-world infrastructure state**.
* Updates the **in-memory version** of the state (not written to disk yet).

<br>

**2. Diff Phase (Code ↔ Refreshed State):**

* Compares the desired state from `.tf` files ↔ refreshed in-memory state.
* Generates a plan that shows:

  * ✅ Nothing to change (if code and infra match).
  * ⚠️ Changes needed (if drift is found).
  * ➕ Additions (if resource is defined in code but not in state).
  * 🗑️ Deletions (if resource is in state but removed from code).

<br>

**3. Execution Phase (only in `apply`):**

* Terraform executes the planned changes using **API calls to the provider**.
* After successfully applying the changes, it writes the new snapshot to `terraform.tfstate`.

<br>

### 🔁 Summary Flow

```
terraform plan
   ⬇
[1] Refresh Phase
   ⤷ Load .tfstate
   ⤷ Query cloud provider
   ⤷ Update state in memory
   ⬇
[2] Diff Phase
   ⤷ Compare HCL ↔ Refreshed State
   ⤷ Show Plan (add/change/destroy)
```

<br>

## 📌 What If There Is No terraform.tfstate File?

### Case A: ❌ No State + ✅ Real Infrastructure Already Exists

* Terraform **has no memory** of the infrastructure.
* It **skips the refresh phase** because there’s no state to refresh.
* It assumes **nothing exists**, so it plans to **create all resources again**.

  > ⚠️ This can cause:
  >
  > * ❗ Conflicts (e.g., "resource already exists")
  > * ❗ Duplicates (e.g., second VM with same config)
  > * ❗ Errors (if name/ID already used)
  >
  > ✅ **Real-world fix**: Use `terraform import` before plan/apply
  > to sync real infra into new state

<br>

### Case B: ❌ No State + ❌ No Infrastructure Exists

* Terraform sees nothing in state and nothing exists in the cloud.
* So everything in the code is planned for **creation**.
* This is the safest case — standard first-time use.

<br>

## 🗑️ What Happens During Destroy?

### 🔥 `terraform destroy` Behavior:

| Situation                                              | Behavior                                                                   |
| ------------------------------------------------------ | -------------------------------------------------------------------------- |
| ✅ State file exists                                    | Destroys **only** what's in state (calls delete API for tracked resources) |
| ❌ State file missing                                   | Nothing is destroyed — because there's nothing to look up                  |
| ✅ State exists, but resource manually deleted in cloud | Shows as already gone, skips or errors (e.g., "not found")                 |
| ⚠️ State is stale                                      | May throw errors or fail mid-way during destroy                            |

> The `terraform destroy` command is not aware of any real infrastructure that is not tracked in the
> **current state file**. If you've made changes outside of Terraform or lost your state file, it cannot destroy
> those resources unless **imported first**.

<br>

## ✅ Terraform Command Behavior

| Command             | Compares             | Reads Code | Reads State | Reads Infra | Writes Infra | Updates State |
| ------------------- | -------------------- | ---------- | ----------- | ----------- | ------------ | ------------- |
| `terraform plan`    | Code ↔ State ↔ Infra | ✅ Yes     | ✅ Yes     | ✅ Yes      | ❌ No       | ❌ No         |
| `terraform apply`   | Code ↔ State ↔ Infra | ✅ Yes     | ✅ Yes     | ✅ Yes      | ✅ Yes      | ✅ Yes        |
| `terraform refresh` | State ↔ Infra        | ❌ No      | ✅ Yes     | ✅ Yes      | ❌ No       | ✅ Yes        |
| `terraform destroy` | State → Infra        | ✅ Yes     | ✅ Yes     | ✅ Yes      | ✅ Yes      | ✅ Yes        |

<br>

## 🔍 Failure Root Map: Where Things Go Wrong

<br>

| 🧩 **What Broke**         | 🔍 **Symptoms**                                                                 | 🛠️ **Fix Skills**                                                                 |
|---------------------------|----------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| **📦 State Layer**        | Terraform doesn't "remember" real infra or both out of sync | `terraform import`, `refresh`, restore from backup, `taint`, reapply     |
| **🌐 Backend Layer**      | Remote state errors<br>Lock conflicts<br>Init fails<br>Local state used accidentally | `terraform init`, backend config fixes, `force-unlock`, use versioned S3/MinIO     |
| **🔗 Dependency Graph**   | Destroy fails in middle<br>Cyclic errors<br>Apply creates partial infra          | Use `depends_on`, `lifecycle`, split resource graph, refactor order                |
| **🔣 Input / Logic Layer**| Count/index mismatch<br>Apply removes existing resource<br>Plan shows unexpected diffs | Fix inputs/variables, logic bugs, clean types, validate configs                    |
| **♻️ Versioning Layer**   | Module updates break infra<br>Downtime after upgrade<br>Plan wants to change everything | Pin versions, lock providers, test module updates in branches, audit changes       |

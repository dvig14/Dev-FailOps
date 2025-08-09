# 📜 FailOps Lab – Changelog

> Track of all failures added, improvements made, and upcoming Topics/Tools.

<br>

## 🟢 v0.2.0 – New Failure Added: State Lock Conflict (Released: 4 Aug 2025)

### ✅ Included:

* 🧨 **Scenario 3: `state-lock-conflict`**

  * Simulates concurrent `terraform apply` on shared state backend (MinIO → then Consul)
  * Demonstrates how state lock mechanism prevents corruption
  * Deep dive on:
    * Lock metadata (`TF_LOCK_METADATA`)
    * Lock timeout handling
    * Force unlock + stale lock TTL expiry in Consul

<br>

## 🟢 v0.1.0 – Initial Milestone (Released: 1 Aug 2025)

### ✅ Included:
* ⚙️ **Terraform Lab Setup** using:
  * Local-first Vagrant + MinIO S3 for tfstate backend
* 🧨 **Scenario 1: `tfstate-deletion`**
  * Simulates accidental loss of `.tfstate` file
  * Covers full restore/import process with fix paths
* 🧨 **Scenario 2: `state-drift`**
  * Simulates infra edited outside Terraform
  * Shows how drift is detected + how to safely fix

### 📚 Extras:
* Markdown documentation in every folder
* Screenshot assets to visualize key Terraform behavior
* Real-world comparisons + mental models



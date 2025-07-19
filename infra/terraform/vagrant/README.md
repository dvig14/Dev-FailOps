# Terraform + Vagrant Modular Setup with MinIO Backend

This project uses Terraform to dynamically generate a `Vagrantfile` from VM definitions, manage VM lifecycle (`up`, `halt`, `destroy`), and store the Terraform state remotely using **MinIO** as an S3-compatible backend.

<br>

## 📁 Project Structure

```
terraform/
├── backend.tf           # Remote backend configuration using MinIO
├── locals.tf            # Local values used across the config (e.g., processed VM info)
├── output.tf            # Terraform outputs (e.g., IP addresses)
├── resources.tf         # Resources: Vagrantfile, VM provisioning (via local-exec), and S3 bucket
├── vagrantfile.tpl      # Ruby ERB template to render Vagrantfile dynamically
├── variables.tf         # Input variable declarations
```

<br>

## 🪣 `backend.tf`: Configure Remote State Storage with MinIO

```hcl
terraform {
  backend "s3" {
    bucket                      = "terra-state"
    key                         = "terraform.tfstate"
    region                      = "us-east-1"
    endpoints                   = { s3 = "http://192.168.56.22:9000" }
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
```

### 💡 Why These Flags?

| Setting                       | Purpose                                                      |
| ----------------------------- | ------------------------------------------------------------ |
| `endpoints`                   | Use local MinIO instead of AWS which use IAM                 |
| `use_path_style`              | Required for MinIO (doesn't support subdomain-style buckets) |
| `skip_credentials_validation` | MinIO doesn't support AWS IAM                                |
| `skip_metadata_api_check`     | Prevents Terraform from looking for AWS EC2 metadata         |
| `skip_requesting_account_id`  | Avoids unnecessary AWS account checks                        |

<br>

## 🧩 `resources.tf`: Generate & Manage Vagrant VMs

### 1. 🧾 **Generate `Vagrantfile` from Template**

```hcl
data "template_file" "vagrantfile" {
  template = file("${path.module}/vagrantfile.tpl")

  vars = {
    vms_json = jsonencode(local.vms_with_absolute_paths)
  }
}

resource "null_resource" "vagrantfile" {
  count = var.sandbox_enable || var.app_enable || var.jenkins_enable ? 1 : 0
  
  provisioner "local-exec" {
    command = <<EOT
    echo '${replace(data.template_file.vagrantfile.rendered, "'", "'\\''")}' | ./vagrantfile-gen.sh '${path.module}/../output/Vagrantfile'
    EOT
    working_dir = "${path.module}/../../provision"
    interpreter = ["bash", "-c"]
  }

}
```

* Template generates Vagrantfile using `vagrantfile.tpl` and `local.vms_with_absolute_paths`.
* Output saved to: `output/Vagrantfile`

<br>

### 2. 🔃 **Provision VMs (`up`, `halt`, etc.) using `null_resource` + `local-exec`**

```hcl
resource "null_resource" "vagrant_op" {
  depends_on = [null_resource.vagrantfile]

  provisioner "local-exec" {
    command     = "vagrant ${var.vm_state} ${var.vm_name != "" ? var.vm_name : ""}"
    working_dir = "${path.module}/../output"
  }

  triggers = {
    vm_state = var.vm_state
    vm_name  = var.vm_name
  }
}
```

* **Working directory:** Runs command where the Vagrantfile is written ie output dir.
* **Trigger:** Ensures resource is recreated when `vm_state` or `vm_name` changes.
* **Depends_On:** Terraform doesn't link resources and if one related to other like here cant vagrant up before creating vagrantfile 

<br>

### 3. 🔥 **Destroy VM on `terraform destroy`**

```hcl
resource "null_resource" "vagrant_destroy" {
  depends_on = [null_resource.vagrant_op]

  provisioner "local-exec" {
    when        = destroy
    command     = "vagrant destroy -f"
    working_dir = "${path.module}/../output"
  }

}
```

<details>
<summary>⚠️ Why NOT use variables ,for_each here?</summary>

#### 💡 Explanation:

| Concept             | Why It's Done                                                                 |
| ------------------- | ----------------------------------------------------------------------------- |
| `when = destroy`    | Ensures the command runs only on `terraform destroy`                          |
| No `variables` used | `terraform destroy` does **not support `var.*`** because inputs may not exist |
| No `for_each` used  | To **avoid race conditions** (e.g. multiple `vagrant destroy` on same folder) |
| `depends_on` used   | Ensures destroy only runs **after** `vagrant up/halt` execution finishes      |

<br>

#### 🛑 Why no `for_each`?

Using `for_each` like this:

```hcl
resource "null_resource" "vagrant_destroy" {
  for_each = { for vm in var.vms : vm.name => vm }
  ...
}
```

Causes **multiple parallel destroy operations**, which can lead to:

* Conflicts in `.vagrant/` shared folder
* Duplicate `vagrant destroy` calls (one per VM)
* Unpredictable failures

---

#### ⚠️ Why avoid `-target` in production?

`terraform destroy -target=null_resource.vagrant_destroy["jenkins"]`

* ✅ Can work for dev/testing
* ❌ **Not safe** in production:

  * It skips dependency graph
  * May leave orphaned or broken infra
  * Doesn’t respect full lifecycle

<br>

#### ✅ Real-world practice:

In production, people:

* Use **modular design** (1 folder/module per VM)
* CD into that VM’s directory
* Run `terraform destroy` inside it for isolated cleanup

Example:

```
cd terraform/app-vm/
terraform destroy
```

This avoids race conditions and respects dependencies properly.

</details>

<br>

## 📥 `variables.tf`: Input Variables

```hcl
variable "sandbox_enable" {
  type = bool
  default = false
}

variable "app_enable" {
  type = bool
  default = false
}

variable "jenkins_enable" {
  type = bool
  default = false
}

variable "vm_state" {
  description = "Vagrant action: up, halt, reload"
  type        = string
  default     = "up"
}

variable "vm_name" {
  description = "VM name to operate on. Empty means all VMs."
  type        = string
  default     = ""
}
```

<br>

## 🚀 Example Usages 

- Vms must be enabled at start as enabled ones only present in vagrantfile.

| Scenario                        | Command                                                             |
| ------------------------------- | ------------------------------------------------------------------- |
| Enable vms you want to run      | `terraform apply -var="jenkins_enable=true" -var="app_enable=true"` |
| Bring all vms up i.e enaled     | `terraform apply`                                                   |
| Halt all VMs that are enabled   | `terraform apply -var="vm_state=halt"`                              |
| Halt specific VM (`app`)        | `terraform apply -var="vm_state=halt" -var="vm_name=app"`           |
| Bring up specific VM (`app`)    | `terraform apply -var="vm_state=up" -var="vm_name=app"`             |
| Destroy all VMs + resources     | `terraform destroy`                                                 |    

<br>

## ✅ Why Use `null_resource` with Triggers?

* `null_resource` doesn’t track actual infrastructure.
* Without `triggers`, Terraform won’t re-run the provisioner even if variables like `vm_state` change.
* `triggers` force re-creation when relevant inputs change.
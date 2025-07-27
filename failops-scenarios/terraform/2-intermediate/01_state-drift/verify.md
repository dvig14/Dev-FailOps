## ✅ Verify Path 1: Sync State Using `terraform apply -refresh-only`

<br>

## 1️⃣ - 📸 [Refresh Output](./assets/refresh_state.png)

### Key Benefits:

* Shows you exactly what changed.
* Asks for confirmation before changing state.
* Great for catching drift without infra changes.

> ❓ Why does it show deletion for `local_file`?

Because:

* Terraform doesn’t inspect file contents.
* It just sees “this file is not what it used to be” → deletes from state.

<br>

### ✅ What If This Were Real Infrastructure?

Let’s assume this simulates a real cloud resource, like a VM where someone edited `sandbox.sh`.

In that case, `terraform refresh` would:

* Detect the **new value**.
* Prompt you to sync it to state.

**Example Output:**

```hcl
# local_file.example has been deleted
  + resource "local_file" "example" {
      + content              = <<-EOT
            #!/bin/bash
            echo FailOps Lab                     #### Updated Value
        EOT 
      ...
    }

Would you like to update the Terraform state to reflect these detected changes?
Only 'yes' will update the state.

Enter a value: yes
```

> ⚠️ **Important:** Just press `enter` (without typing `yes`) since this is just a local file.

<br>

## 2️⃣ Decide: Keep the Manual Change or Revert to Code?

### Option A: Keep the Manual Change (Match Infra)

* Update your `.tf` file to reflect the new value, e.g.:

```bash
  echo "FailOps Lab"
```

* Run `terraform plan`:

```bash
  No changes. Your infrastructure matches the configuration.
```

This confirms that **code, state, and infra are now in sync**.

<br>

### Option B: Revert Manual Change (Enforce What’s in Code)

* Simply run `terraform apply`.
* Terraform will recreate/update the resource based on your code.

  📎 [See Apply Step 5](./README.md/#5-run-terraform-apply)

<br>

> ⚠️ Note: In our simulation using `local_file`, Terraform might behave differently.
>
> 🛠 To simulate the cloud behavior:
>
> * Manually edit `sandbox.sh` back to:
>
>   ```bash
>   echo "Hello from sandbox VM, no real provisioning needed."
>   ```
>
> * Then run `terraform plan`.
>
> 📸 [Plan Output](./assets/plan_output.png)

<br>

> If don't want to proceed now and want to resume later on 
> [Destroy or Halt VMs After Completion](../../README.md#-destroy-or-halt-vms-after-scenario-completion)



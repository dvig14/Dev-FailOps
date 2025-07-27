### 🔁 Before You Begin

This lab uses **shared infrastructure** from the `/infra/` directory — including `*.sh`, Terraform configurations, and provisioners.

If you've previously run any other scenario (like `state-drift`), or made changes to shared files or infra:

> ❗ You **must reset the entire repo** before continuing.
> This ensures the environment matches the intended base state.

#### ✅ Reset the repo:

```bash
cd Dev-FailOps
git restore .

# This deletes cached Terraform backend data and local plans.
cd infra/terraform/vagrant
rm -rf .terraform terraform.tfstate* terraform.tfplan
```

✅ **Your real infrastructure and remote state (in MinIO/S3) is safe.**
[Initialize Terraform](./terraform/README.md#5️⃣-initialize-terraform)

<br>

> ❗ Want to keep your changes?
> Temporarily save your edits **before restoring**:

```bash
git stash
```

> Later, when you return to that lab:

```bash
git stash pop
```

💡 This avoids losing your changes and lets you continue switching safely between labs.

🚦 **Best Practice:** Complete one lab at a time to prevent state confusion and backend conflicts.

## 🧩 Problem Recap

You **manually modified infrastructure** outside of Terraform.

Now:

* Terraform has **no knowledge** of those changes.
* `terraform plan` → detects drift and shows a **recreation plan** based on what it knows from `.tf` files.
* `terraform apply` → **recreates** resources as per your code — potentially **overwriting manual changes**.

This may seem safe in local setups like Vagrant, but in **real cloud environments**, it poses **serious risks**.

<br>

## 🧠 Ask These Before You Fix

1. Is your state file outdated?
2. Was the change made to an **existing** resource or was a **new** resource manually created?
3. Do you want to **preserve** the manual changes or **revert** to what’s in the code?

Your answers guide which **fix path** is safest.

<br>

## ✅ Fix Path 1: Sync State with Actual Infrastructure using `terraform refresh`

<br>

## 🔍 What Does `terraform refresh` Do?

`terraform refresh` connects to your infrastructure provider and updates the **Terraform state file** to reflect the current state of infra without modifying the infra itself.

This is helpful when:

* Your `.tfstate` is outdated.
* You need to audit or troubleshoot drift.
* You're preparing for a plan or apply and want an up-to-date state.

> 🤔 Isn't this the same as what `terraform plan` does with auto-refresh?
>
> Yes, by default `terraform plan` **does** refresh the state before comparing.
> But as you’ll see later, there are still good reasons to use `refresh` manually in some cases.

<br>

## 🛠 Fixing Our Lab

To sync state with reality, you have **two options**:

### 🔧 1. `terraform refresh`

* Fetches the current infra state.
* Updates the `.tfstate` file.
* Then run `terraform show` to review updated state.
* You can then:

  * Update your code to **match** the new state.
  * Or, run `apply` to **revert** infra back to match your original code.

> ⚠️ On local simulations (like with `local_file` resources), this may not behave the same `refresh` may just delete the resource from state. 

<br>

### 🔧 2. `terraform apply -refresh-only`

- [🔍 Verify](./verify.md#-verify-path-1-sync-state-using-terraform-apply--refresh-only)  

<br>

## 🧑‍💼 Real-World Scenario: Why This Matters

- Same example as explained in [readme example](./README.md#-real-world-impact)
- You deploy an EC2 instance via Terraform:

```hcl
  Code (you deployed)                       Infra (manual change)
instance_type = "t2.micro"                instance_type = "t3.large"
```

When you **run this manually before plan or apply**:

```bash
terraform refresh
```

- Terraform contacts the provider, sees `t3.large`, and updates `.tfstate`.
- Now your state reflects `t3.large`. You can either:

  * Run `apply` to force the change back to `t2.micro`, or
  * Update `.tf` to match that

```
Code (updated)       ↔        State   (after refresh)     
t3.large                      t3.large    
```

<br>

### 💡 Better Option: `terraform apply -refresh-only`

This command gives you an **interactive preview** of drift:

```bash
terraform apply -refresh-only
```

1. Checks infra and updates the state (no infra changes).
2. You get a **prompt to confirm** before saving this to the state.

**Example Output:**

```
~ instance_type: "t2.micro" => "t3.large"

Do you want to perform these actions?
  Terraform will update the state to match the real infrastructure
  without modifying any real resources.

  Enter a value: yes
```

> ✅ You now **see the drift**, get a **chance to review**, and **only then** update the state.

<br>

## ❓Why Not Just Update the Code to Match?

That works **only if auto-refresh is enabled**, because `terraform plan` will contact the infra anyway.

But in some real-world setups:

* CI/CD pipelines **disable auto-refresh** using `-refresh=false`
* Or teams want **manual control** over state updates

So, changing just the code won’t help unless the state is **explicitly refreshed**.

<br>

## 🔍 When Is `terraform refresh` Still Useful?

**⚠️ Scenario 1: Auto-Refresh is Disabled**

```sh
terraform plan -refresh=false
```

- Terraform will **not contact the infra**.
- It will **assume the old state is correct**.

- ➡️ You must manually run `terraform refresh` to see the real drift.
 
<br>

**⚠️ Scenario 2: Diagnostic / Manual Review**

* You're debugging drift and want to see updated state immediately
* You want to inspect `terraform show` after refresh
* You're preparing for a plan but **not ready to apply yet**

<br>

## ❓ Why Disable Auto-Refresh at All? 

Large teams and enterprise environments often do this:

**🔧 1. Performance**

* Auto-refresh means calling **hundreds/thousands** of APIs which takes time
* To speed up workflows, teams skip refresh:

```bash
terraform plan -refresh=false
```

<br>

**⚠️ 2. Avoid Overwriting Critical Manual Fixes**

* Suppose someone made an emergency hotfix manually.
* `terraform plan` detects drift and wants to revert.
* That could break prod again.

So:

* Teams disable auto-refresh,
* Manually inspect drift,
* Then decide what to keep or discard.

<br>

## 🛠️ Drift Detection Tools (e.g., Atlantis, Spacelift, Scalr)

In large teams, manual refresh is hard. These platforms help by:

* **Auto-refreshing the state** in the background
* Showing **visual drift alerts**
* Letting teams **review, approve, or reject** drifts before applying anything

✅ This avoids surprises during deployment and helps maintain clean, predictable infrastructure.

<br>

## 🚨 What If the Resource Was Created Manually (Not in State at All)?
  
That's when we switch to

> [👉 Fix Path 2: Add Manual Created Resource In State Using `terraform import`](./fix-path-2.md)


## ✅ 1. `TF_LOCK_METADATA` - Track Who Owns the Lock

<br>

**User-B executes:**

```bash
export TF_LOCK_METADATA='{"owner":"user-b-laptop", "user":"User-B"}'

# API request to store lock metadata
curl --silent --request PUT \
  --data "$TF_LOCK_METADATA" \
  http://localhost:8500/v1/kv/terraform/state/app/.lockinfo.custom

terraform apply
```
<br>

> 🔍 Navigate to `http://localhost:8500` → **Key/Value** tab → open path `terraform/state/📁app`
> - You will see a file `.lockinfo.custom` that stores the lock metadata.
> - Now you know **User-B** holds the lock.
> - You can reach out to them and check whether their **apply** is `still running` or has `encountered an issue`.

<br>

* 📸 [Apply metadata](./assets/apply_metadata.png)
* 📸 [.lockinfo.custom](./assets/custom_lock.png)

<br>

## ✅ 2. `-lock-timeout` - Retry Instead of Fail Immediately

<br>

**User-A runs:**

```bash
# Start terraform apply but don't confirm or cancel – just leave it idle
terraform apply
```

**Then User-B runs:**

```bash
terraform apply -lock-timeout=60s
```

* 📸 [-lock-timeout](./assets/lock-timeout.gif)

<br>

### 🔄 Step-by-Step Internal Flow:

1. **Terraform polls the backend** (e.g., DynamoDB or Consul) every few seconds to check lock status.

2. If the lock **is still active**:

   * It waits and sleeps (\~5s by default), then retries.
   * This repeats for **up to 60 seconds**.

3. If the lock **gets released** (e.g., User-A cancels the apply):

   * Terraform (User-B) successfully acquires the lock and continues.

4. If **60 seconds pass and lock remains**:

   * Terraform exits with a lock error:
    ```
     Error: Error acquiring the state lock
    ```

    * 📸 [Here 30s passed but lock still held & Terraform fails](./assets/timeout-fail.gif)

- This is useful when **multiple pipelines** or users may apply in parallel.
- Instead of failing immediately, jobs **wait for the lock to release**, reducing false failure noise.

<br>

## ✅ 3. `force-unlock <id>` - For Crashes or Job Cancellation

<br>

**1. User-B runs `terraform apply`**

<br>

**2. Confirms with yes but then presses `Ctrl+C` to interrupt mid-apply.**

   * Lock entries remain in backend → creating a **stale lock**.

<br>

**3. Now User-A runs:**

```bash
terraform apply
```

Resulting error:

```
Error: Error acquiring the state lock
│
│ Error message: Lock Info:
│   ID:        b8312db7-98ab-eec2-c88c-4224e1b4878c
│   Path:      terraform/state/app
│   Operation: OperationTypeApply
│   Who:       VIKAS\VIKAS VIG@VIKAS
│   Version:   1.12.0
│   Created:   2025-08-04 08:24:27.2586981 +0000 UTC
│   Info:      consul session: b8312db7-98ab-eec2-c88c-4224e1b4878c
```

> ❌ Even though no active job is running (it was cancelled/crashed), the lock is still held and **blocks User-A**.

<br>

**4. User-A forcefully unlocks the state and then runs apply again:**

```bash
terraform force-unlock b8312db7-98ab-eec2-c88c-4224e1b4878c
terraform apply
```

<br>

* 📸 [force-unlock](./assets/force-unlock.gif)

> 💡 Note:
> 
> - **Use `force-unlock` only when you're certain** no active job is holding the lock.
> - Unlocking a live session can lead to **state corruption**.

<br>

## 🔚 Close the Consul Server

<br>

```bash
ps aux | grep consul
kill <id>
```

> 🧹 After shutting down the Consul server, delete `consul.log` from the `.terraform/` directory.

<br>

* 📸 [Consul server closed](./assets/consul_close.png)
* 📸 [Consul log deleted](./assets/log_deleted.png)

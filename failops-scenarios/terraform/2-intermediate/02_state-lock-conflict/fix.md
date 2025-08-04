
> **NOTE:**
> - The **state lock conflict** will be simulated again once pipeline and infrastructure scenarios are added.
> - For now, focus on understanding **what actions to take** when a lock issue occurs.

<br>

## 🧠 Check Failure Cause Before Applying Fix

1. 🔁 Are multiple jobs applying in parallel?
2. ❌ Did a CI job crash or get cancelled?
3. 🤷 Is the lock holder unknown?

Your answers guide which **fix path** is safest.

<br>

## 🧭 Step-by-Step: Identify the Lock Cause

<br>

| Check This                                           | It Tells You…                                              |
| ---------------------------------------------------- | ---------------------------------------------------------- |
| **Lock metadata** (`TF_LOCK_METADATA`)               | Who or what owns the lock (e.g., user, CI job ID, machine) |
| **CI/CD dashboards** (GitHub Actions, Jenkins, etc.) | Is there a pipeline currently running or recently failed?  |
| **DynamoDB / Consul lock entry**                     | Lock timestamp: recent (active) or stale (likely crash)    |
| **Team communication / Slack alerts**                | Was someone applying manually? Was there a notification?   |
| **CI job history or logs**                           | Did a job crash or get cancelled mid-apply?                |

<br>

## 🚦 Fixes & Good Practices

<br>

> 🧪 **Scenario 1**
>
> You're running a pipeline that fails on `terraform apply`
> Error:
> ```
>   Error: Error acquiring the state lock
> ```
>
> - You **don't know** whether another pipeline or a manual user triggered the lock.
> - You're unsure **who or what is holding it.**

<br>

## ✅ 1. `TF_LOCK_METADATA` — Track Who Owns the Lock

<br>

**Purpose**
- Make it easy to identify **who or what owns the lock** using logs or dashboards.
- This helps determine **which job to cancel** or **whom to contact**.              

#### Usage in CI/CD:

Inject metadata before `terraform apply`:

```bash
export TF_LOCK_METADATA="{\"owner\":\"CI #${CI_JOB_ID}\", \"user\":\"${GIT_COMMITTER_NAME}\"}"
terraform apply -auto-approve
```

> ⚠️ Note:
> This metadata is not stored in the backend (S3, DynamoDB, or Consul) unless you're using:
>
> * 🔧 Wrapper tools like Atlantis or Terragrunt -> They read this env var separately (before calling `terraform apply`) and **store it elsewhere** (e.g. in dashboards, logs, Slack)
> * Your own custom logging scripts                                 

<br>

#### Example Custom Script:

```bash
export TF_LOCK_METADATA="{\"owner\":\"CI #${CI_JOB_ID}\", \"user\":\"${GIT_COMMITTER_NAME}\"}"

# Optional: Log it for visibility
echo "Lock metadata: $TF_LOCK_METADATA" >> lock.log

# Optional: Save it in Consul under a custom key
curl --silent --request PUT \
  --data "$TF_LOCK_METADATA" \
  http://localhost:8500/v1/kv/terraform/state/my-key/.lockinfo.custom

terraform apply -auto-approve
```

### 🔗 [Simulation](./verify.md#-1-tf_lock_metadata---track-who-owns-the-lock)

<br>
<br>

> 🧪 **Scenario 2**
>
> - Now you **know it's a CI job** that holds the state lock.
> - Lock metadata shows: `"owner": "CI Job #245"`
> - But you **don’t know** whether it's still `running` or `already failed`.
> - You also **don’t know the timestamp** whether the lock is `recent` or `old`.
>
> ✅ So, you:
>
> * `Check CI/CD dashboards` → to identify if the pipeline is *currently running* or *failed*
> * `Check DynamoDB lock table / Consul .lockinfo` → to inspect the *timestamp* (recent vs old)
>
> **Part-1:**
>
> * CI dashboard shows: **Job #245 is still running**
> * Lock timestamp is **fresh** (e.g., seconds or a few minutes ago)
>
> ➡️ Since the CI job is actively running and your pipeline is trying to apply in parallel,
> you want to **prevent your job from failing** and instead **wait until Job #245 releases the lock**.

<br>

## ✅ 2. `-lock-timeout` — 🔁 Retry Instead of Fail Immediately

<br>

**Purpose:**
- When multiple jobs may apply simultaneously, prevent instant failure.

```bash
terraform apply -auto-approve -lock-timeout=300s
```

> Terraform waits up to 5 minutes for the lock to be released.

### 🔗 [Simulation](./verify.md#-2--lock-timeout---retry-instead-of-fail-immediately)

<br>
<br>

> 🧪 **Scenario 2**
> 
> **Part-2:**
>
> - CI dashboard shows: **Job #245 has failed** — no job is currently running.
> - Lock timestamp is **stale** (e.g., older than 30 minutes).
> - CI logs indicate the job was **cancelled** or **crashed** during execution.
>
> 🔒 However, the **lock is still present**, which means no other job can proceed with `terraform apply`.
>
> 💡 The key point: You are **100% sure** that no active (running) process is currently holding or using the lock.

<br>

## ✅ 3. `force-unlock <id>` — ❌ For Crashes or Job Cancellation

<br>

**Purpose**
- If a CI job **crashed mid-apply**, Terraform keeps the lock, blocking future applies.

```bash
terraform force-unlock <id>
```

### 🤷 No Metadata? Not sure?

* No `TF_LOCK_METADATA`
* No running CI jobs
* Can’t tell from timestamp alone

**Then:**
1. Ask your team
2. If the lock is **old enough** (e.g., >15 min), it's safe to use `force-unlock`

### 🔗 [Simulation](./verify.md#-3-force-unlock-id---for-crashes-or-job-cancellation)

<br>

## ✅ 4. Auto-Expire Locks (TTL) — *Stale Lock Auto-Cleanup*

<br>

**Purpose**
- Avoid manual unlocks when sessions crash or disconnect.
- We have already seen this in 📘 [Read_Part2.md](./READ_PART2.md#8-let-user-b-try-again)  

#### Consul (supported):

1. When `terraform apply` starts:
   * It creates a **session** in Consul.
   * That session "owns" the lock key (`terraform/state/app`).
   * Session includes a TTL (default: 15s–60s).

2. If `terraform apply` is **forcefully killed** (like Ctrl+C), **the client stops renewing the session**.

3. Even though the **lock key still shows up in the Consul UI**, the **session expires silently** after TTL.

4. When **User A** runs apply:
   * Terraform checks the lock key.
   * It sees: “The session that held this lock is **expired**.”
   * Therefore → **Terraform auto-deletes the stale lock** and **takes the lock** for User A.

<br>

## ⚠️ Limitations of TTL-Based Expiry

1. **Not supported in all backends**

   * ✅ Consul supports TTL
   * ❌ DynamoDB **does not** → Requires manual `force-unlock`

2. **Passive only**

   * You must **wait** for TTL to expire (30s–5min)
   * Your pipeline is **blocked** until then

3. **No visible countdown**

   * You can’t see “lock will expire in X minutes”
   * Developers often left guessing

4. **Force unlocks still needed if:**

   * You use S3 + DynamoDB (no TTL)
   * Metadata is corrupted or missing
   * CI job crashed mid-write

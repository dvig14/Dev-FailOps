# 🧩 Cgroup Namespace and Resource Isolation

The **cgroup namespace** isolates the control group (cgroup) root directory, which manages resource limits such as CPU, memory, disk I/O, and process counts. This ensures that each container can view only its own cgroup hierarchy, remaining unaware of the host or other containers.

Unlike virtual machines—where each instance runs its own kernel and has dedicated resources—containers share the host’s kernel. Through **cgroups**, Docker applies resource limits to processes, creating the illusion of independent resource ownership while actually sharing the same underlying system.

<br> 

**For example**, Docker provides flags like `--cpu-shares` and `--memory` to define per-container resource limits:

```bash
docker run -d --name cont1 --cpu-shares=512 alpine sleep infinity
```

When a container starts, Docker invokes the `clone()` system call with the `CLONE_NEWCGROUP` flag, creating a **new cgroup namespace**.
The root cgroup directory can be found at:

```bash
/sys/fs/cgroup
```

A running container’s cgroup typically appears under:

```bash
/sys/fs/cgroup/system.slice/docker-<container-id>.scope
```

**Host view:**
📸 [Root cgroup directory](./assets/root_cgroup.png)

**Container view:**
📸 [Container cgroup directory](./assets/docker_container.png)

<br>

Containers remain **isolated**—the host can view all container cgroups, but a container cannot access or modify the host’s cgroup or those of other containers.

To verify this, open a shell inside the container:

```bash
docker exec -it cont1 sh
/# ls /sys/fs/cgroup
/# exit
```

Inside the container:

* The cgroup view is isolated.
* Resource limits are visible but **read-only**.

Docker integrates with `systemd` by creating a **system slice** for each container at:

```bash
/sys/fs/cgroup/system.slice/docker-<container-id>.scope/
```

Within this slice, Docker enforces the resource constraints defined at runtime.

**Isolated cgroup view:**
📸 [Isolated cgroup](./assets/isolated_cgroup.png)

**Read-only limits inside container:**
📸 [Read-only limits](./assets/docker_readonly.png)

<br>

## Cgroup Versions: v1 vs v2

### Cgroup v1

| Feature | Description |
|---------|-------------|
| Hierarchy | Each controller (CPU, memory, etc.) has its own separate hierarchy, e.g., `/sys/fs/cgroup/cpu/`, `/sys/fs/cgroup/memory/`. |
| Process & Thread Control | Each process and thread can have its own cgroups within each controller. |

**Notes / Implications:**  
- Complex to debug and manage: each controller requires handling its own directory.  
- Threads cannot have isolated memory because they share the same process memory space. A process may have CPU limits per thread but cannot enforce memory limits per thread.  
- Kernel cannot logically correlate resource limits across different cgroup hierarchies. Each controller (CPU, memory, blkio) operates independently, so the same PID appearing in multiple controller folders does not provide a unified view of combined limits.

<br>

### Cgroup v2

| Feature | Description |
|---------|-------------|
| Hierarchy | Unified root hierarchy containing all controllers under a single structure, e.g., `/sys/fs/cgroup`. |
| Process & Thread Control | Each process can have its own cgroup. Example: a Docker container has its own cgroup, while the root contains all controllers and containers. |
| Thread-level Limits | Threads can have CPU and I/O limits individually via special flags; memory remains shared. Kernel is aware of shared memory, so memory controller operates at parent process level while still allowing CPU/I/O throttling per thread. |

<br>

### Check Cgroup Version

```bash
stat -f -c %T /sys/fs/cgroup
mount | grep cgroup
```

### 📸 [version](./assets/version.png)

<br>

## Creating and Managing Cgroups with `cgcreate` & `cgexec`

### 1. Install Required Tools

Install the necessary cgroup libraries and tools:

```bash
sudo apt-get update
sudo apt-get install libcgroup1 cgroup-tools -y
```

<br>

### 2. `cgcreate` Overview

The `cgcreate` command allows you to:

* Create a new cgroup for a specific resource controller (e.g., `cpu`, `memory`)
* Establish a directory structure to assign processes and enforce resource limits

```bash
cgcreate -g <controller>:<path>
```

> **Note:** In **cgroup v2**, there is a single root directory for all controllers, unlike v1 which had separate directories for each controller.

<br>

### 3. Example: Creating a CPU Cgroup

Create a cgroup named `mygrp`:

```bash
cgcreate -g cpu:/mygrp
```

📸 [mygrp](./assets/mygrp_cg.png)

<br>

### 3.1 Controlling CPU Limits

Modify `cpu.max` to set CPU limits for the cgroup:

```bash
echo '<max_quota> <period>' > /sys/fs/cgroup/mygrp/cpu.max
```

* `max_quota`: Maximum microseconds of CPU time allowed per scheduling period
* `period`: Duration of a scheduling period in microseconds (default: `100000 µs = 100 ms`)

**How it works:**

* The kernel schedules CPU in periods (default 100 ms)
* `cpu.max = 50000 100000` → Processes can run 50 ms per 100 ms (50% of one CPU core)
* `cpu.max = max 100000` → Unlimited CPU usage

📸 [cpu max limit](./assets/cpu_max.png)

<br>

### 3.2 Enabling Sub-cgroup CPU Control

To allow child cgroups (e.g., `/sys/fs/cgroup/mygrp/app1`) to have CPU limits:

```bash
echo '+cpu' > /sys/fs/cgroup/mygrp/cgroup.subtree_control
```

**Explanation:**

* Enabling `cpu` lets child directories or processes access the CPU controller and set limits
* This works similarly to how Docker delegates CPU limits to containers
* The root cgroup must have the controller enabled for children to inherit it

<br>

### 4. Understanding Cgroup Hierarchy

Each directory under `/sys/fs/cgroup/` represents a cgroup and can:

* Contain processes (listed in `cgroup.procs`)
* Have sub-cgroups (subdirectories)

Check the root cgroup:

```bash
cat /sys/fs/cgroup/cgroup.procs
cat /sys/fs/cgroup/cgroup.subtree_control
```

📸 [root cgroup & subtree_control](./assets/subtree_control_root.png)

<br>

### 4.1 Systemd Slice `/sys/fs/cgroup/system.slice`

* Typically contains one main PID (a service or container)
* Can have enabled subtree controllers even with a single PID
* Kernel allows this for system-managed slices
* Host/Docker safely delegate controllers to child cgroups

<br>

### 4.2 Non-root Cgroup `/sys/fs/cgroup/mygrp`

* If `cgroup.procs` is non-empty, enabling subtree controllers for children is **not allowed**
* Attempting this will fail:

```bash
echo +cpu > /sys/fs/cgroup/mygrp/cgroup.subtree_control
```
📸 [subtree_control mygrp](./assets/subtree_control_mygrp.png)

<br>

## `cgexec`: Execute Commands within a Cgroup

`cgexec` runs a command (or process) inside a specified cgroup, enforcing the resource limits defined for that cgroup.  
**Syntax:**
```bash
cgexec -g <controller>:<path>
```

<br>

### 1. No Isolation

```bash
cgexec -g cpu:/mygrp sh
```

📸 [cgexec](./assets/cgexec_noisolation.png)

Here, `/sys/fs/cgroup` is not isolated and remains the same as the host. `cgexec` does **not** handle namespaces, which are responsible for process isolation. It only creates a cgroup, applies the resource limits, and runs the process on the host. Therefore, the process shares network, devices, mounts, filesystem, and other host resources.

> **Note:** For true isolation, the `unshare` syscall must be used, as discussed in [namespace.md](./namespace.md).

<br>

### 2. Checking Memory Limits in Cgroups

Cgroups allow you to set a memory limit to restrict the total memory usage (RAM + swap) of processes within the cgroup:

```bash
apt-get install stress
echo 100M > /sys/fs/cgroup/mygrp/memory.max
cgexec -g cpu:/mygrp stress --vm 2 &
```

* **stress**: Utility to generate artificial load (CPU, memory, I/O, etc.) for testing.
* **--vm 2**: Launches 2 worker processes that repeatedly allocate memory blocks.

If these processes exceed the `100M` limit, the kernel enforces it via one of three mechanisms: throttling, memory reclamation, or triggering the OOM killer.

> **Note:** In this configuration, processes exceeding the limit are terminated immediately. To delay termination and allow processes to pause instead of being killed instantly, you can set `memory.high`:

```bash
echo 80M > /sys/fs/cgroup/mygrp/memory.high
echo 100M > /sys/fs/cgroup/mygrp/memory.max
cgexec -g cpu:/mygrp stress --vm 2 &
```

<br>

## 1. Throttling
**Definition:**  
- **Throttling** slows down or temporarily pauses a process to prevent it from exceeding the memory limit. The kernel delays memory allocation requests, allowing the system to manage resources effectively.

**How It Works:**  
- When a process attempts to allocate memory beyond `memory.max` (hard limit), the kernel may place it in a "stall" state, where it waits before continuing.  
- This behavior is often controlled by the `memory.high` threshold in cgroup v2 (soft limit), signaling the kernel to slow processes before reaching the hard limit.

**Monitoring Memory Pressure:**  
```bash
cat /sys/fs/cgroup/mygrp/memory.pressure
```

📸 [memory pressure](./assets/mem_pressure.png)

**Breaking Down the Values:**

* **Types of Pressure:**

  * **some:** Fraction of time some processes in the cgroup are stalled (waiting for memory). Includes delays caused by hitting `memory.high`, `memory.max`, or memory contention.
  * **full:** Fraction of time all processes in the cgroup are stalled. Indicates more severe pressure affecting the entire cgroup.

* **Metrics:**

  * `avg10`, `avg60`, `avg300`: Percentage of time over the last 10, 60, and 300 seconds that processes were stalled due to memory pressure.

**Example:**

* `some avg10=87.72` → Over the last 10 seconds, some processes in `mygrp` were stalled 87.72% of the time (high pressure).
* `full avg10=87.08` → All processes were stalled 87% of the time (almost full cgroup blockage).

**Why It Happens**:
- Throttling prevents immediate termination, giving processes a chance to stay within limits without crashing critical applications.

<br>

## 2. Reclaiming Memory

**Definition:**  
- **Reclaiming memory** occurs when the kernel takes back memory from a cgroup to ensure it stays under the `memory.max` limit. This process frees memory used for caches, buffers, or other reclaimable allocations.  

**How It Works**:  
- The kernel identifies memory pages (e.g., file caches, temporary buffers) that are not critical for process execution.  
- These pages are reclaimed, reducing the cgroup’s memory usage (`memory.current`).  
- If reclamation alone is insufficient (e.g., processes consume non-reclaimable memory like anonymous pages), the kernel may escalate to throttling or trigger the OOM killer.  

The kernel performs memory reclamation automatically whenever a cgroup experiences memory pressure (e.g., exceeding `memory.high=80M` or approaching `memory.max=100M`).  

**Monitoring Reclamation**:
```bash
cat /sys/fs/cgroup/mycontainer/memory.stat
```

**What It Shows**:
This file provides detailed statistics about memory usage and activity for all processes in the cgroup (`mygrp`):

* **Memory Types**: Usage in different categories (e.g., anonymous, file-backed).
* **Reclamation Metrics**: Number of pages scanned and reclaimed by the kernel.
* **Page Fault & Working Set Metrics**: How memory accesses and evictions are handled.

**Detecting Reclamation Activity**:

Look for non-zero values in the following fields:

* `pgscan`: Number of pages scanned for reclamation.
* `pgsteal`: Number of pages actually reclaimed (stolen from the cgroup).
* `workingset_refault_file`: Reclaimed file-backed pages that were needed again.
* `workingset_activate_file`: Reclaimed pages that were reactivated.

**Example Output**:

```
pgscan 3784                   # Kernel scanned 3784 pages for reclamation
pgsteal 2643                  # 2643 pages were actually reclaimed
workingset_refault_file 2650  # 2650 file-backed pages were reclaimed but refaulted
workingset_activate_file 51   # 51 file-backed pages reactivated after reclamation
```

📘 [What Each Field (State) Means](./memory-stat.md)

**Why It Happens**:

* Memory reclamation prevents process termination by freeing non-essential memory.
* It is less effective for programs like `stress --vm`, which allocate primarily anonymous memory that is not easily reclaimable.

<br>

## 3. Triggering the OOM (Out-of-Memory) Killer

**Definition:**:
- The **OOM killer** is a kernel mechanism that terminates processes when a cgroup exceeds its memory limit (`memory.max`) and memory reclamation or throttling cannot free enough resources.

**How It Works**:
- When `memory.current` exceeds `memory.max`, the kernel selects a process in the cgroup to terminate based on factors such as memory usage and OOM scores (`/proc/<pid>/oom_score`).  
- You can check the processes in the cgroup via:  
```bash
cat /sys/fs/cgroup/mygrp/cgroup.procs
````

```bash
cat /sys/fs/cgroup/mygrp/memory.oom.group
cat /sys/fs/cgroup/mygrp/memory.events
dmesg | grep -i oom
```

**`memory.oom.group`**:

* `0` (default): The kernel kills only the process with the highest OOM score (usually the one consuming the most memory).
* `1`: The kernel kills all processes in the cgroup when OOM occurs, treating the cgroup as a single unit.

**`memory.events`**:

* `low <value>`: Times memory usage fell below `memory.low`.
* `high <value>`: Times memory usage exceeded `memory.high` (e.g., 80MB).
* `max <value>`: Times memory usage hit or exceeded `memory.max` (e.g., 100MB).
* `oom <value>`: Times the cgroup ran out of memory after exceeding `memory.max` and failing to reclaim memory.
* `oom_kill <value>`: Times the kernel terminated processes to enforce `memory.max`.

📸 [events & dmesg](./assets/mem_events.png)

<br>

**Example**: `oom_kill 1` indicates the kernel killed the process exceeding `memory.max`. Confirm via `dmesg`. Since `oom.group` is `0`, only the offending process is terminated. You can verify with:

```bash
ps aux | grep stress
cat /sys/fs/cgroup/mygrp/cgroup.procs
```

If the cgroup is empty, all processes have been terminated.

📸 [dmesg for oom 0](./assets/dmesg_oom_0.png)

> Note: `dmesg` logs show all OOM events, but with `oom.group=0`, only the highest-memory process triggers termination.

<br>

Now, set `oom.group` to `1` to terminate all processes in the cgroup:

```bash
echo 1 > /sys/fs/cgroup/mygrp/memory.oom.group
cgexec -g cpu:/mygrp stress --vm 2
# Wait for the process to trigger OOM
cat /sys/fs/cgroup/mygrp/memory.events
dmesg | grep -i oom
```

* 📸 [output oom 1](./assets/oom_1.png)
* 📸 [dmesg for oom 1](./assets/dmesg_oom_1.png)
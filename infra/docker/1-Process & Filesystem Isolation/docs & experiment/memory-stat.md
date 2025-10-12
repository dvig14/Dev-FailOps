# Memory Usage and Reclamation Metrics

This section explains the memory usage and working set metrics observed during stress testing in a cgroup.

## Memory Usage Categories (Current Allocation)

These show how memory is currently used across different types:

- **anon 0**: Anonymous memory (heap, stack, malloc'd data not backed by files). `0` means no anonymous memory allocated (low for `stress --vm`, likely killed early).  
- **file 28672**: File-backed memory (cached file contents). 28 KB in use.  
- **kernel_stack 0**: Kernel stack memory. None allocated.  
- **pagetables 0**: Page tables (memory mappings). Minimal mappings.  
- **percpu 0**: Per-CPU allocations. None.  
- **sock 0**: Socket buffers (network memory). None.  
- **shmem 0**: Shared memory. None.  
- **file_mapped 0**: File-mapped anonymous memory. None.  
- **file_dirty 0**: Dirty file pages (modified but not written). None.  
- **file_writeback 0**: Pages being written back to disk. None.  
- **swapcached 0**: Cached swapped pages. None.  
- **anon_thp 0**: Anonymous transparent huge pages (THP). None.  
- **file_thp 0**: File-backed THP. None.  
- **shmem_thp 0**: Shared memory THP. None.  
- **inactive_anon 0**: Inactive anonymous pages (candidates for reclamation). None.  
- **active_anon 0**: Active anonymous pages (recently used, harder to reclaim). None.  
- **inactive_file 16384**: Inactive file-backed pages (easy to reclaim). 16 KB available.  
- **active_file 12288**: Active file-backed pages (recently accessed). 12 KB in use.  
- **unevictable 0**: Memory that cannot be reclaimed (e.g., locked). None.  
- **slab_reclaimable 0**: Reclaimable kernel slab caches. None.  
- **slab_unreclaimable 0**: Unreclaimable slab caches. None.  
- **slab 0**: Total slab caches. None.

<br>

## Working Set Metrics (Page Behavior)

These track how pages are accessed and reclaimed:

- **workingset_refault_anon 0**: Anonymous pages reclaimed but needed again. None.  
- **workingset_refault_file 2650**: File-backed pages reclaimed but refaulted. Indicates active reclamation.  
- **workingset_activate_anon 0**: Anonymous pages reactivated after reclamation. None.  
- **workingset_activate_file 51**: File-backed pages reactivated. Some reclaimed pages were reused.  
- **workingset_restore_anon 0**: Anonymous pages restored from swap. None.  
- **workingset_restore_file 50**: File-backed pages restored from swap. Some reclaimed pages reused.  
- **workingset_nodereclaim 0**: Pages not reclaimed due to node constraints. None.

> **Interpretation:** Non-zero values like `workingset_refault_file 2650` and `workingset_activate_file 51` confirm that reclamation occurred: file pages were reclaimed under memory pressure but were needed again.

<br>

## Page Fault and Reclamation Metrics

These reflect kernel activity in managing memory:

- **pgfault 54716**: Total page faults. High value indicates heavy memory activity.  
- **pgmajfault 380**: Major page faults requiring disk I/O or swap.  
- **pgrefill 1199**: Pages refilled from backing store (disk).  
- **pgscan 3784**: Pages scanned for reclamation.  
- **pgsteal 2643**: Pages successfully reclaimed. Indicates ~70% reclamation success.  
- **pgactivate 1095**: Pages reactivated after scanning.  
- **pgdeactivate 1143**: Pages deactivated for easier reclamation.  
- **pglazyfree 0**: Deferred freeing of pages. None.  
- **pglazyfreed 0**: Lazy-freed pages actually freed. None.  
- **thp_fault_alloc 0**: Transparent huge pages allocated on fault. None.  
- **thp_collapse_alloc 0**: THP collapsed (combined). None.

> **Interpretation:**  
> - `pgscan` and `pgsteal` confirm memory reclamation under pressure.  
> - High `pgfault` shows stress caused significant memory activity, triggering kernel reclamation.  
> - Since `stress --vm` primarily uses anonymous memory (which was 0 in this snapshot, likely after termination), reclamation was insufficient to prevent OOM.

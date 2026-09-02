+++
title = "Anatomy of a Multikernel Container from the Primary Linux Host"
description = "Following a container from containerd Create through child-kernel boot, process execution, networking, observation, and cleanup as seen by the primary Linux system."
tags = [
    "linux",
    "containers",
    "containerd",
    "multikernel",
]
date = "2026-09-01"
categories = [
    "cloud",
]
+++

My earlier posts looked at individual parts of the Multikernel container path: [building image-derived roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}}), [providing mediated networking]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}}), and [implementing a containerd Runtime v2 shim]({{< ref "20260831_containerdRuntimeForMultikernelLinux.md" >}}). This post puts those pieces together from one particular viewpoint: what happens on the primary Linux system when containerd creates a container whose process will run under another kernel?

That viewpoint matters because a Multikernel container is not represented by one ordinary process tree on the primary. The primary can see containerd, the shim, the runtime daemon, Kerf state, the prepared root, transport processes, and network devices. The actual workload PID belongs to the child kernel and does not appear in the primary kernel's process table.

The implementation and retained GCE evidence are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Two Linux systems inside one VM

I use *primary* to mean the Linux kernel that booted the GCE VM and still owns its management environment. It runs SSH, the Google guest agent, containerd, Docker, `mkruntimed`, and Kerf. It also retains the boot disk and GCE virtual NIC.

A *child* is another Linux kernel started by Multikernel from CPUs and memory removed from the primary. The child has its own scheduler, process table, boot ID, network stack, and PID 1. In the current containerd prototype, one containerd task receives one child kernel.

```text
One GCE VM
├── Primary Linux kernel
│   ├── containerd and Docker
│   ├── containerd-shim-multikernel-v2
│   ├── mkruntimed and Kerf
│   ├── OCI snapshot and generated initramfs
│   ├── primary-side TUN, routes and iptables rules
│   └── mkvsock-relay
└── Multikernel child Linux kernel
    ├── /init
    ├── mk-agent
    ├── child-side mkn0
    └── container init and exec processes
```

The child is not a nested VM. There is no emulated firmware, GRUB, virtual disk controller, or guest NIC. Kerf loads `vmlinux` and the generated initramfs directly into the resources assigned to the child. The primary remains responsible for assembling those inputs and mediating access to storage and the external network.

## The complete parent-side lifecycle

The easiest way to understand the runtime is to follow one Task v2 lifecycle. `Create` assembles and loads the child without running the workload. `Start` starts the child, connects to its agent, and launches the process. Later operations cross the same control channel. `Delete` tears the construction back down.

{{<mermaid>}}
graph TD
    A[ctr or Docker requests a container] --> B[containerd prepares OCI bundle and snapshot]
    B --> C[Runtime v2 shim mounts the snapshot]
    C --> D[Shim builds a private initramfs]
    D --> E[Shim selects free CPUs, memory, port, and child CID]
    E --> F[mkruntimed creates durable sandbox identity]
    F --> G[Kerf creates and loads the child]
    G --> H[Task is CREATED but workload is not running]
    H --> I[Start creates primary TUN and firewall state]
    I --> J[Relay starts and Kerf starts the child kernel]
    J --> K[Child /init starts mk-agent]
    K --> L[Shim authenticates and configures child networking]
    L --> M[mk-agent starts the OCI-configured process]
    M --> N[Shim forwards I/O, signals, state, and exit]
    N --> O[Delete stops network, child, and sandbox]
    O --> P[Unmount snapshot and return primary resources]
{{</mermaid>}}

### Before `Create`

Containerd owns image acquisition. It pulls the OCI manifest and layers, verifies content, unpacks them through its snapshotter, and creates an OCI bundle. The bundle includes `config.json`, which describes the process and root, while the Task v2 `Create` request includes the mounts that expose the prepared snapshot.

At this point there is no Multikernel child for the task. There is also no reason for the Multikernel runtime to download image layers or understand a registry. Its input begins at the bundle and prepared snapshot boundary.

When Docker is the client, Docker still reaches the same Runtime v2 shim through containerd. The experiment selects `io.containerd.multikernel.v2` as an alternative Docker runtime and uses `--network none`, because the Multikernel runtime rather than Docker's bridge supplies the child network.

### Containerd starts a shim

Runtime v2 gives a task its own long-running shim process. Containerd starts `containerd-shim-multikernel-v2` with the containerd namespace and task ID, creates a Unix socket for its Task API, and records the shim PID.

The separate shim is more than a command wrapper. It holds task state, the agent client, stdio endpoints, the packet pump, and the sandbox identity. It can remain alive across a containerd restart, which is why restarting containerd need not imply restarting the child kernel.

The shim is intentionally not allowed to manipulate Multikernel global state directly. It asks the privileged `mkruntimed` daemon to perform lifecycle mutations. That keeps containerd protocol handling separate from CPU and memory allocation, Kerf invocation, journaling, and reconciliation.

### `Create` mounts and copies the prepared root

The shim first mounts the Task v2 rootfs mounts at the bundle's `rootfs`. This mount is visible from the primary because containerd's snapshot still belongs to the primary kernel.

It then creates a bundle-local `.multikernel` directory with mode `0700`. The current builder copies the prepared image root into a private staging tree and packages the following child root as a gzip-compressed `newc` CPIO archive:

```text
.multikernel/initramfs.cpio.gz
├── /init
├── /bin/busybox
├── /mk-agent
├── /mkvsock-relay
├── /mk_transport.ko
└── /bundle
    ├── config.json
    └── rootfs
        └── copied OCI image filesystem
```

The shim also creates a random 256-bit authentication token and stores it as `.multikernel/token` with mode `0600`. `initramfs.path` tells the Kerf adapter which task-specific archive to load. Later, `sandbox.json` records the sandbox ID, generation, exit information, and network ownership required by cleanup.

Building the archive happens before allocating Multikernel resources. If the copy or CPIO step fails, for example because storage is full, the rootfs is unmounted and no child CPU, memory pool, TUN interface, or firewall rule should have been allocated.

One cost is visible here: the current implementation makes a full copy of the prepared root for every sandbox. The source snapshot remains containerd-owned, but startup cost and memory consumption grow with the unpacked image.

### The shim allocates a sandbox slot

The prototype has a configured list of disjoint CPU sets. Under a host-level allocation lock, the shim lists existing sandboxes, marks their CPUs as used, and selects the first free set. The same slot determines the agent port and child CID. The tested defaults allocate two CPUs and 3 GiB of memory per child.

The resulting request contains:

- a sanitized sandbox ID derived from the container ID;
- the selected CPU set;
- `3 GiB` of memory;
- the approved `gce-mk2` kernel-manifest entry;
- the bundle path;
- a unique agent port; and
- a unique child CID.

`mkruntimed` gives the sandbox a random generation and journals the mutation. Identity is therefore the pair of sandbox ID and generation, not the reusable container name alone. Subsequent mutations include that generation and an idempotency key so a delayed retry cannot modify a later sandbox that happens to reuse the same name.

If this is the first sandbox, the daemon asks Kerf to establish the CPU and memory pool. It then creates a Kerf instance and moves the durable lifecycle through `ALLOCATING` to `CREATED`.

### `Create` loads but does not start the child

The next mutation is `LoadSandbox`. The Kerf adapter reads the task-specific initramfs path and token, selects the approved `vmlinux`, constructs the kernel command line, and asks Kerf to load the child artifacts.

The token, sandbox ID, generation, and agent port are passed to the child through that command line. The child has not started executing yet. From the runtime's perspective the sandbox is `LOADED`, while containerd reports the task as `CREATED`.

This separation preserves an important containerd semantic:

```text
containerd Create   = resources and child are prepared
containerd Start    = child and workload begin executing
```

If loading fails after the sandbox was created, the shim issues a generation-qualified `DeleteSandbox` rollback. The rootfs mount is also unwound by the failing `Create` path.

## What changes when `Start` arrives

Starting the init process performs three related operations: establish the primary-owned data plane, start and authenticate the child control plane, and finally start the workload.

### The primary constructs the network boundary

The shim creates a primary-side TUN interface for the allocation slot. A typical pair looks like this:

```text
Primary: mkn0, 172.30.30.1/30
Child:   mkn0, 172.30.30.2/30
```

For the next slot, the primary interface name and `/30` subnet change, while the interface inside that child is still named `mkn0`. The primary raises the link with MTU 1400, finds its default egress interface, and installs three narrowly scoped iptables rules:

- masquerade traffic from the sandbox `/30` through the external interface;
- allow forwarding from the sandbox TUN to that interface; and
- allow established or related return traffic back to the TUN.

The GCE NIC never leaves the primary. The TUN carries IP packets, and a shim-owned pump exchanges them with `mk-agent` over the authenticated Multikernel transport. No forwarding rule is installed from one sandbox TUN to another.

The shim persists the interface, subnet, and egress interface into the recovery record before the child is exposed as running. This gives the cleanup path enough information to remove host networking even if the original in-memory shim state is lost.

### The relay and child kernel start

The shim starts a generation-qualified Unix socket under `/run` and launches `mkvsock-relay`. The relay bridges that primary-side socket to the pinned Multikernel VSOCK transport.

Only then does the shim ask `mkruntimed` to perform `StartSandbox`. The daemon checks the sandbox ID, generation, and allowed lifecycle transition before Kerf executes the loaded child.

Inside the child, the kernel unpacks the private initramfs and runs `/init` as PID 1. That init mounts `devtmpfs`, `devpts`, `/proc`, `/sys`, and cgroup v2, bind-mounts the required pseudo-filesystems beneath `/bundle/rootfs`, loads the transport module, reads its identity from `/proc/cmdline`, and starts `mk-agent`.

The shim retries the authenticated agent connection for a bounded period. Each session is bound to the sandbox ID, generation, endpoint, monotonically increasing request sequence, and per-sandbox token. Once connected, the shim asks the agent to configure the child-side TUN address and default route, then starts the packet pump.

### The workload starts last

For the container init process, the shim sends `CreateProcess` with `/bundle` as the OCI bundle. `mk-agent` reads the bundled configuration and records a process in its own `CREATED` state. The shim opens the containerd stdin, stdout, and stderr endpoints and then sends `StartProcess`.

The executable and libraries come from `/bundle/rootfs`, not from the runtime's BusyBox bootstrap. The current agent changes root into that filesystem, applies the supported process user, supplementary groups, arguments, environment, and working directory, and starts the process in a new process group. The 1 September proof used non-terminal processes with separate stdout and stderr streams; terminal creation and resizing were still rejected explicitly at that point.

Once that succeeds, the shim publishes a containerd Task start event and reports the task as running.

## What the primary can and cannot see

While the task runs, its objects cross two process tables and several ownership domains:

| Object | Owner | Visible from the primary? |
|---|---|---|
| Container metadata and OCI bundle | containerd | Yes |
| Snapshot mount at `bundle/rootfs` | containerd/shim | Yes |
| `.multikernel` artifacts | shim bundle | Yes, subject to permissions |
| Shim process and Task socket | primary kernel | Yes |
| `mkruntimed` and its durable state | primary kernel | Yes |
| Kerf pool and child instance | primary/Multikernel control plane | Yes through Kerf and sysfs |
| Assigned CPUs and memory | child while allocated | Visible as absent/allocated resources, not ordinary host processes |
| Primary TUN, routes, and firewall rules | primary kernel | Yes |
| Relay and packet-pump activity | shim/primary kernel | Yes |
| Child `/init` and `mk-agent` PIDs | child kernel | No, not in the primary's process table |
| Container init and exec PIDs | child kernel | No, not as primary-kernel PIDs |
| Workload stdout, stderr, state, and exit | child agent, forwarded by shim | Yes through the Task API |

The PID difference produces an unavoidable compatibility wrinkle. Task v2 expects a host PID, but the real workload PID has meaning only to the child kernel. The current shim returns its own primary-kernel PID from `Create`, `Start`, `State`, `Pids`, events, and `Connect`.

```text
Primary kernel process table       Child kernel process table
----------------------------       --------------------------
containerd                         PID 1: /init
containerd shim                    mk-agent
mkruntimed                         container init process
mkvsock-relay                      container exec processes
```

That value is sufficient for the tested `ctr` and Docker paths, but it is not faithful guest PID reporting. A later runtime needs either a documented virtual-PID mapping or another explicit compatibility design.

The two process tables also explain why tools must be interpreted carefully. Running `ps` on the primary will show the shim, not the workload. Running `ps` through `ctr task exec` or `docker exec` asks `mk-agent` to start a process inside the child and observes that kernel's process view. Reading `/proc/sys/kernel/random/boot_id` through exec is a useful proof because the child returns a boot ID different from the primary and its sibling.

## How normal container operations cross the boundary

After startup, the shim translates familiar container operations rather than asking the client to understand Multikernel:

| Client-visible operation | Primary-side work | Child-side work |
|---|---|---|
| `State` or inspect | Read shim-maintained process state | Agent state was previously synchronized |
| `Exec` | Register exec ID and stdio; publish event | Create another process in the same image root |
| stdin or attach | Not part of the 1 September retained proof | Not part of the 1 September retained proof |
| stdout/stderr | Write captured output to containerd FIFOs | Capture separate non-terminal output streams |
| terminal and resize | Reject as unsupported | No terminal process is created |
| `Kill` | Translate Task request | Signal the child process group |
| `Wait` | Block on shim completion state | Report exit code after process termination |
| `Delete` | Remove Task state and host resources | Delete process and quiesce the agent |

An exec process shares the same child kernel and copied image root as the init process. It does not allocate another child. Signals cross the authenticated agent protocol and are applied to the process group inside the child. Exit status and exit time travel back in the other direction, after which the shim publishes the Task exit event and wakes callers waiting through containerd.

Containerd and Docker therefore retain their familiar APIs, but the shim is translating between two different kernels rather than manipulating a descendant host process.

## Deletion reverses the construction

Deleting a running task is rejected until its process has stopped. Once the init process can be deleted, the normal teardown is approximately the reverse of startup:

```text
delete process in mk-agent
  -> stop packet pump and close child networking
  -> request agent shutdown
  -> close authenticated agent session
  -> StopSandbox through mkruntimed and Kerf
  -> DeleteSandbox and release Kerf resources
  -> remove TUN and iptables state
  -> unmount the containerd rootfs
  -> publish Task delete event
```

When the last sandbox is deleted, `mkruntimed` asks Kerf to release the pool so the CPUs and memory return to the primary kernel. The bundle and its `.multikernel` artifacts then remain tied to containerd's normal bundle cleanup rather than living as anonymous shared files.

If the shim dies, the current behavior is safe reclamation rather than task reconstruction. Containerd can invoke the shim's cleanup mode, which reads `.multikernel/sandbox.json`, removes the recorded network state, and sends generation-qualified stop and delete requests. This avoids leaking CPUs, memory, a child instance, TUN device, or firewall rules. It does not preserve the running workload or reconnect a replacement shim to it; that remains open work.

## What the retained GCE evidence shows

The clearest retained end-to-end run used an Ubuntu `n2-standard-16` GCE VM with the primary kernel `7.0.0-mk2-gce-lab`, Kerf `0.2.0`, containerd `2.2.2`, Docker `29.1.3`, and `busybox:1.36`.

One clean-pool run recorded the following results from concurrent `ctr` and Docker tasks:

```text
HOST_BOOT_ID=069e5c26-99ef-44ac-acbd-1db527a7fb74

ctr child boot ID:
45dc4c2e-42de-4c67-945c-cb94d12a8c4b
child mkn0: 172.30.30.2/30, MTU 1400

Docker child boot ID:
cbf79096-bf89-4bee-9ce1-ae5ba08fe04d
child mkn0: 172.30.31.2/30, MTU 1400

CTR_NETWORK_PASS
DOCKER_NETWORK_PASS
CROSS_SANDBOX_ISOLATION_PASS
CTR_EXEC_PASS
DOCKER_EXEC_PASS
DISTINCT_CHILD_KERNEL_BOOT_IDS_PASS
CTR_DOCKER_LIFECYCLE_PASS
PRIMARY_MEDIATED_NETWORK_PASS
G4_G5_G6_MVP_PROOF_PASS
```

The three boot IDs establish that the two workloads did not share the primary kernel or each other's child kernel. The two addresses show that each child received a different point-to-point subnet. The same transcript recorded exit code 137 after a `SIGKILL`, followed by successful lifecycle and cleanup markers.

The environment captured after the run showed no Kerf instances, an empty containerd task table, no Docker containers, and no matching network inventory. It also showed CPUs `0-15` back in the primary. A repeated clean run produced the same overall result.

The run's own manifest classifies the result as provisional and records that the repository was dirty. The exact working-tree diff was not retained, so these observations support the narrow MVP claims above but are not a reproducible full-gate result.

A second feature matrix captured later on 1 September added split create/start, state inspection, private-root writes, daemon-restart continuity, nonzero exit, and name reuse through both clients. It continued to report terminal/resize and pause/resume as explicitly unsupported. Its final transcript ended with:

```text
G4_G6_CTR_DOCKER_FEATURE_MATRIX_PASS
COMMAND_EXIT_CODE="0"
```

There is an evidence-quality limit worth preserving. That marker-oriented transcript did not retain every expanded command or asserted value, and its historical manifest does not conform to the repository's newer evidence schema. I treat it as useful feature evidence, not closure of the complete G4, G5, or G6 gates. The earlier clean-pool transcript is stronger for the exact boot IDs and child network addresses quoted above.

## What this does not yet prove

This walkthrough describes the implemented narrow runtime, not complete OCI or Kubernetes support.

At the point captured here, the initramfs builder reduces the original OCI configuration to terminal mode, user, arguments, environment, working directory, and the private root path. Capabilities, namespaces, cgroup resources, seccomp, mounts, hooks, rlimits, read-only-root configuration, and masked or read-only paths are not implemented end to end. More seriously, some unsupported fields are discarded before `mk-agent` can reject them. Until the adapter validates the original input and fails closed, this should be described as running an OCI-image process under a dedicated child kernel, not full OCI conformance.

The current mapping is also one child kernel per containerd task. The target Kubernetes design is one child per pod sandbox with multiple containers inside it. That requires CNI `ADD`, `CHECK`, and `DEL`, pod-sandbox metadata, pause-container behavior, multiple separate container roots in one child, volume handling, probes, scheduling policy, and reliable restart reconciliation.

Other open Task v2 work includes faithful guest PID reporting, `Stats`, `Update`, checkpoint/restore, pause/resume, complete event ordering, bounded output retention and backpressure, and preservation of a running task after shim death.

Those limitations do not undo the central result. From the primary VM, an ordinary container request now causes containerd content, a runtime-owned boot artifact, partitioned CPUs and memory, a primary-mediated network, and a separately booted Linux kernel to be assembled into one managed task. The same primary then translates the task's I/O and lifecycle back into the APIs that `ctr` and Docker already understand—and, on deletion, takes the construction apart and returns the resources.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Runtime architecture](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/architecture.md)
- [Runtime v2 shim implementation](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/cmd/containerd-shim-multikernel-v2/main.go)
- [Child agent implementation](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/manager.go)
- [Private initramfs builder](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/scripts/build-runtime-container-initramfs.sh)
- [G4-G6 clean-pool evidence](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/evidence/runtime-20260901/g4-g6-gce/g4-g6-proof-clean-pool.log)
- [G4-G6 feature-matrix evidence](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/tree/main/evidence/runtime-20260901/g4-g6-feature-matrix)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})
- [Persistent ext4 Roots for Multikernel Linux on Google Compute Engine]({{< ref "20260830_ext4ForMultikernelLinuxOnGCE.md" >}})
- [Turning Container Images into Multikernel Linux Roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}})
- [Networking Containers in Multikernel Linux Child Kernels]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}})
- [A containerd Runtime v2 Shim for Multikernel Linux]({{< ref "20260831_containerdRuntimeForMultikernelLinux.md" >}})

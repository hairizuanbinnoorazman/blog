+++
title = "A containerd Runtime v2 Shim for Multikernel Linux"
description = "Running ctr and Docker containers with one Multikernel child kernel each, including exec, signals, wait, delete, restart recovery, and crash cleanup."
tags = [
    "linux",
    "containerd",
    "docker",
    "multikernel",
]
date = "2026-08-31"
categories = [
    "cloud",
]
+++

My first Multikernel Linux runtime used a custom command-line client to create a child and ask an agent inside it to run a process. That proved the control and process layers, but it did not make Multikernel usable by existing container clients.

I have now added `containerd-shim-multikernel-v2`, a containerd Runtime v2 shim. An ordinary BusyBox image can be run with `ctr` or selected as an alternative Docker runtime. Each tested container receives its own Multikernel child kernel, while containerd still handles image acquisition and snapshot preparation.

The implementation, test scripts, and GCE evidence are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Where the shim fits

The runtime has three layers with deliberately different privileges:

```text
ctr or Docker
  -> containerd
    -> containerd-shim-multikernel-v2
      -> mkruntimed
        -> Kerf and /sys/fs/multikernel
          -> dedicated child kernel
            -> mk-agent
              -> container process
```

The shim speaks containerd's Task v2 API and translates container operations into runtime and child-agent calls. It does not invoke Kerf or mutate `/sys/fs/multikernel` directly. Those privileged, host-global operations belong to `mkruntimed`, which serializes allocation and maintains the durable sandbox lifecycle.

Inside the child, `mk-agent` is the process manager. It interprets the supported parts of the OCI process specification, creates the process in the image-derived root, captures output, forwards signals, and reports state and exit status.

This split matters during failures. Containerd can restart without taking ownership of child resources, and the daemon can restart without confusing container semantics with Kerf state. Each layer has enough identity to reconnect or clean up only what it owns.

## Mapping Task v2 onto a child kernel

The implemented lifecycle covers the core non-terminal operations:

| Task v2 operation | Multikernel action |
|---|---|
| `Create` | Mount snapshot, build private root, allocate and load child |
| `Start` | Start child, authenticate agent, configure network, launch init process |
| `State` | Return shim-maintained process state |
| `Exec` | Create an additional process through `mk-agent` |
| `Kill` | Forward the requested signal to the child process group |
| `Wait` | Block until the agent reports exit and return status/time |
| `Delete` | Delete process; for init, stop and release the whole sandbox |

`Create` deliberately stops at the containerd “created” state. The child is loaded, but the workload process does not run until `Start`. Starting the init process also creates the private TUN network, starts the authenticated transport relay, boots the child, and connects to its agent.

The Task API requires a host PID even though the workload PID exists in a different kernel and is not meaningful to the primary's process namespace. The runtime reports the shim PID as the task PID. This works for the tested clients, but it is one of the semantic differences that needs careful documentation and broader compatibility testing.

Additional non-terminal processes use Task v2 `Exec`. The shim sends a reduced process specification to the agent, publishes the corresponding task events, and tracks each exec ID independently. Terminal creation and `ResizePty` are intentionally rejected rather than pretending to work; terminal support remains open.

## One kernel per container

The target architecture eventually maps one child kernel to a Kubernetes pod sandbox and runs multiple OCI containers within it. For the current standalone containerd implementation, the granularity is simpler: every containerd task gets one child kernel.

The shim chooses a free, disjoint CPU pair from a configured list and assigns 3 GiB of memory. It also allocates a unique agent port, child CID, static `/30`, and random sandbox generation. A host-level allocation lock prevents two concurrent shims from selecting the same slot.

This made the central claim directly testable. The proof ran a `ctr` task and a Docker container concurrently, then read `/proc/sys/kernel/random/boot_id` from each. Both values differed from the primary kernel and from each other. The two containers were not merely using separate namespaces; they were executing under separate Linux kernel instances.

This is still a trusted, single-tenant experiment. Separate kernels do not automatically provide the KVM/EPT isolation boundary of a microVM, and the runtime should not be described as safe for hostile multi-tenant workloads.

## Making Docker use the same runtime

Docker uses containerd beneath its higher-level API, so the same Runtime v2 shim can be registered as an alternative Docker runtime. It must be registered by `runtimeType`, not as a path to a runc-compatible binary, because Runtime v2 has a different startup protocol.

The proof then uses the familiar Docker lifecycle:

```sh
docker run -d \
  --runtime io.containerd.multikernel.v2 \
  --network none \
  --name mk-proof-docker \
  busybox:1.36 /bin/sleep 300
```

`--network none` is required because the Multikernel runtime supplies networking inside the child. Docker must not attach its normal bridge interface to the shim process on the primary.

Both clients successfully executed a second `/bin/echo` process, delivered `SIGKILL`, waited for exit, and removed the task. Docker observed exit code 137, matching a process killed by signal 9.

## Restart recovery

The recovery tests separate three events that are easy to conflate.

First, restarting containerd while a task was running preserved the task. After containerd returned, `ctr` still reported it as running and an exec request read the same child boot ID as before the restart. Runtime v2's separate shim process is what makes that possible.

Second, restarting `mkruntimed` also retained the live child and its boot ID. The daemon reconciled its durable state with the existing Kerf resources rather than recreating the sandbox.

Third, killing the shim itself produced a different result. The current implementation does not reconstruct the live task or reconnect a new shim to its agent. Instead, containerd's cleanup path reads the generation-qualified recovery record and safely reclaims the child, CPU and memory allocation, TUN device, and iptables rules. This is crash cleanup, not task preservation.

That distinction is important: containerd and daemon restart recovery passed, while shim-crash reconnect remains unfinished.

## Generation-qualified cleanup

Container names can be reused, so a name alone is unsafe recovery identity. Every successful sandbox creation receives a random 128-bit generation. Mutations use the pair of sandbox ID and generation plus an idempotency key.

The shim persists that identity before exposing a running task. It also records the network interface, subnet, and egress device before starting the child. On normal `Delete`, or on the special cleanup invocation after a crash, these records let the runtime remove exactly the resources associated with that generation.

The GCE proof ended by checking all of the relevant inventories: no Kerf instance, no TUN link, no Multikernel NAT or forwarding rule, no containerd task or container, and no Docker container remained. It also confirmed that the primary kernel's boot ID had not changed.

## What works and what remains

The result demonstrates a real end-to-end route from standard container clients to dedicated child kernels. `ctr` and Docker can create, start, inspect, exec, signal, wait for, and delete non-terminal containers. Containerd and runtime-daemon restarts preserve a running child, and a forced shim crash has bounded, leak-free cleanup.

There is still open work. Terminal I/O and resizing are unsupported. Stdio FIFO edge cases, cancellation, event ordering, broader OCI compatibility, and task preservation after a shim crash need more testing and implementation. The eventual one-child-per-pod model and Kubernetes CRI integration also sit beyond this standalone containerd implementation.

Even with those limits, Runtime v2 changes the experiment substantially. Multikernel Linux is no longer reached only through a purpose-built demo client. It can sit behind existing container lifecycle commands while preserving the more unusual property underneath: a separate child kernel for each tested container.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Containerd shim design](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/plans/06-containerd-shim.md)
- [Runtime restart and cleanup test](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/scripts/test-runtime-recovery.sh)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})
- [Persistent ext4 Roots for Multikernel Linux on Google Compute Engine]({{< ref "20260830_ext4ForMultikernelLinuxOnGCE.md" >}})
- [Turning Container Images into Multikernel Linux Roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}})
- [Networking Containers in Multikernel Linux Child Kernels]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}})

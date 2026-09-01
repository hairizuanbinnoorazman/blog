+++
title = "Turning Container Images into Multikernel Linux Roots"
description = "How the Multikernel runtime turns containerd and Docker snapshots into private child initramfs roots with repeatable packaging and bounded rollback."
tags = [
    "linux",
    "containers",
    "containerd",
    "multikernel",
]
date = "2026-08-31"
categories = [
    "cloud",
]
+++

My [first Multikernel Linux experiment on GCE]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}}) started child kernels with roots that I built ahead of time. That was useful for proving that the kernels could boot, but it was not how a container runtime should consume an image. A runtime should accept the root filesystem that containerd has already prepared and should not become another registry client, layer downloader, or snapshotter.

The runtime now follows that boundary. I can pull an ordinary BusyBox image with either `ctr` or Docker, let containerd unpack it, and launch its userspace under a dedicated Multikernel child kernel. The runtime creates a private initramfs for each sandbox, keeps its bootstrap files separate from the image snapshot, and cleans up resources when creation or execution fails.

The implementation and its GCE evidence are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Container image, not guest operating system

An OCI image contributes the workload's files: executables, libraries, configuration, permissions, and the process defaults in `config.json`. It does not choose or supply the child kernel.

The resulting boot inputs have different owners:

```text
containerd or Docker
└── unpacked OCI snapshot and config.json
    └── Multikernel shim
        ├── runtime-selected vmlinux
        └── private initramfs
            ├── runtime bootstrap and transport files
            └── bundle/
                ├── config.json
                └── rootfs/  <- copied from the prepared OCI root
```

This separation avoids a subtle architectural mistake. A container image is not converted into a bootable VM disk, and the runtime does not install an operating system from it. Kerf loads an approved `vmlinux` and the generated initramfs directly into the CPUs and memory assigned to the child. The child then runs the image's process using that root filesystem.

Containerd remains responsible for pulling content, verifying and unpacking layers, and preparing the snapshot mounts. For `ctr`, the Runtime v2 `Create` request supplies mounts that the shim attaches at the bundle's `rootfs`. Docker's containerd image store can instead supply an absolute OCI `root.path`. The builder accepts either form.

## Building a private child root

The shim creates a `.multikernel` directory inside the containerd bundle. It generates a 256-bit authentication token and records the sandbox-specific artifacts there, including the initramfs path and later the sandbox identity needed for recovery.

The [initramfs builder](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/scripts/build-runtime-container-initramfs.sh) stages a new private tree rather than changing the caller's snapshot. It copies the prepared OCI root with `cp -a`, which preserves filesystem metadata, and writes a reduced `config.json` containing the process, user, environment, working directory, and a root path local to the child.

The runtime-owned part of the tree contains only the pieces needed to bring the sandbox up:

- BusyBox for the early userspace tools;
- `mk-agent`, which manages processes inside the child;
- the Multikernel VSOCK relay and transport module; and
- a small init program that mounts the required pseudo-filesystems and starts the agent.

The staged files are sorted before being written as a `newc` CPIO archive. Gzip runs with `-n`, removing the gzip header's filename and timestamp, and the result is written with mode `0600`. This gives the packaging step stable ordering and timestamp-free compression. The builder prints a SHA-256 digest so the exact artifact used for a sandbox can be recorded.

There is an important limit to the word “deterministic” here. The archive deliberately preserves metadata from the prepared OCI root, including file modification times. Two builds from an unchanged snapshot and unchanged runtime inputs have repeatable packaging, but changing source metadata can correctly change the archive digest. A formal manifest and a larger metadata test matrix are still needed before making a stronger reproducibility claim.

## Allocate only after the archive exists

The order of operations is part of the safety design:

```text
mount prepared rootfs
  -> build private initramfs
  -> record its path
  -> select a free CPU and endpoint slot
  -> create the sandbox
  -> load its kernel and initramfs
```

Expensive Multikernel resources are allocated only after the root artifact has been built successfully. This makes a storage failure much easier to contain. In a follow-up GCE test, I replaced the builder with one that returned `No space left on device`. Task creation failed before a child kernel, TUN interface, or firewall rule was allocated.

Failures after allocation need a different rollback. If loading the child fails, the shim sends a generation-qualified `DeleteSandbox` request to `mkruntimed`. The daemon's lifecycle layer uses durable identities and idempotency keys, so retries do not accidentally act on a later sandbox that reused the same container name.

The temporary staging directory is removed by the builder on exit. The per-sandbox archive, token, initramfs path, and recovery record live under the bundle, tying them to containerd's bundle lifecycle rather than placing anonymous shared files elsewhere on the host.

## Normal teardown and crash cleanup

Deleting the task stops the network pump, asks the child agent to shut down, stops and deletes the Multikernel sandbox, removes its network state, and unmounts the containerd rootfs. The end-to-end proof then checks that no Kerf instance, TUN device, iptables rule, containerd task, or Docker container remains.

The recovery record is also useful if the shim disappears unexpectedly. Containerd can invoke the shim's cleanup path, which reads the recorded sandbox ID, generation, and network ownership. The tested crash behavior is safe reclamation: the child, CPU and memory pool, TUN interface, and firewall rules are removed. It is not yet reconstruction of the running task.

## What the current implementation proves

The live GCE proof launched BusyBox through both `ctr` and Docker at the same time. Each image-derived root ran beneath its own child kernel, and each child reported a boot ID different from both its sibling and the primary kernel. After signals, waits, and deletion, the host returned to a clean resource inventory. A second clean-pool run produced the same result.

The result shows that containerd-prepared content can become a private root for a child kernel without moving a storage controller or modifying the snapshot in place. It also demonstrates rollback at one injected pre-allocation ENOSPC point and cleanup through the tested normal and shim-crash paths.

There is more storage work to do. Whiteouts, hardlinks, sparse files, extended attributes, malformed paths, device nodes, quotas, inode exhaustion, live ENOSPC, persistence, and corruption recovery still need a systematic matrix. The current initramfs approach also copies a complete root per sandbox, which is simple and isolated but not a final answer for image sharing or startup efficiency.

For this implementation, that trade-off is worthwhile. It establishes a clean ownership boundary: containerd owns image acquisition and snapshots, the runtime owns the child boot artifact, and each child receives a root that is private to its sandbox.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Runtime architecture](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/architecture.md)
- [Runtime initramfs builder](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/scripts/build-runtime-container-initramfs.sh)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})
- [Persistent ext4 Roots for Multikernel Linux on Google Compute Engine]({{< ref "20260830_ext4ForMultikernelLinuxOnGCE.md" >}})
- [Networking Containers in Multikernel Linux Child Kernels]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}})
- [A containerd Runtime v2 Shim for Multikernel Linux]({{< ref "20260831_containerdRuntimeForMultikernelLinux.md" >}})

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

## What normally happens when Linux boots

Before describing the Multikernel path, it helps to separate the pieces that are often compressed into the phrase “boot Linux.” A conventional Linux machine does not jump directly from power-on to a shell. Control passes through firmware, a bootloader, the kernel, an optional early userspace, and finally the long-running userspace of the installed operating system.

The following is a typical x86 boot through GRUB. The exact firmware and bootloader differ across machines—an embedded board might use U-Boot, for example—but the boundaries after the kernel is entered are broadly the same.

{{<mermaid>}}
graph TD
    A[Power on or reset] --> B[BIOS or UEFI firmware]
    B --> C[Select a boot entry]
    C --> D[Load and run GRUB]
    D --> E[Read GRUB configuration and choose an entry]
    E --> F[Load the Linux kernel, initramfs, and command line]
    F --> G[Transfer control to the kernel]
    G --> H[Decompress kernel and initialize core subsystems]
    H --> I[Discover hardware and initialize built-in drivers]
    I --> J[Unpack initramfs into the kernel rootfs]
    J --> K[Execute /init as PID 1 in early userspace]
    K --> L[Load modules and prepare the real root]
    L --> M[Mount the real root filesystem]
    M --> N[switch_root and execute the real init]
    N --> O[systemd or another init starts services]
    O --> P[Login, shell, desktop, or application is usable]
{{</mermaid>}}

### 1. Firmware establishes a machine that can load software

At power-on, the CPU starts at a firmware-defined address. BIOS or UEFI performs the platform-specific initialization needed before an operating system can run: it brings up enough memory and hardware to continue, discovers bootable devices, and selects a configured boot entry.

On an older BIOS system, firmware typically reads boot code from a disk's boot sector. On a UEFI system, firmware understands the EFI System Partition and starts an EFI executable such as GRUB. UEFI can also load a suitably packaged Linux kernel directly, but GRUB remains a useful representative bootloader because it makes the hand-off visible.

At this point there is no Linux process, root filesystem, or PID 1. Firmware only needs enough functionality to find and start the next program.

### 2. GRUB selects and loads the Linux boot inputs

GRUB is a bootloader, not part of the running Linux kernel. It can understand enough of the disk layout and filesystems to read its configuration and locate the artifacts selected by a menu entry. A normal entry identifies three important inputs:

- the kernel image, commonly named `vmlinuz`, which is usually a compressed bootable form of the kernel;
- an initramfs image, commonly named `initrd.img`, containing the first userspace the kernel will see; and
- the kernel command line, containing values such as `root=`, console settings, and flags controlling storage or recovery behavior.

GRUB copies the kernel and initramfs into memory, passes the command line and platform boot information, and transfers control to the kernel's entry point. Its job is then over. GRUB does not mount the Linux root filesystem for the kernel and it does not start system services.

### 3. The kernel makes the machine into a Linux system

The kernel first decompresses itself when required, establishes its architecture-specific execution environment, and initializes memory management, scheduling, interrupts, timers, and other core subsystems. It then runs built-in driver initialization and discovers the devices that those drivers can operate.

This ordering exposes a bootstrapping problem. The permanent root filesystem may be on an NVMe device, a virtio disk, an encrypted LUKS volume, LVM, software RAID, iSCSI, or NFS. To mount that filesystem, Linux needs the relevant drivers and often userspace tools. Those drivers may themselves be packaged as kernel modules on the root filesystem that Linux cannot yet mount.

One answer is to compile every required driver into the kernel and let it mount the root directly. General-purpose distributions instead usually provide an initramfs so that one kernel package can boot many storage arrangements.

### 4. Initramfs provides an early userspace

An initramfs is normally a compressed CPIO archive supplied alongside the kernel. During boot, the kernel extracts its files into `rootfs`, the special memory-backed filesystem that exists as the kernel's initial root. Unlike the older *initrd* mechanism, it is not a filesystem image that must be mounted as a block device. The names of distribution-generated files still often contain `initrd`, even when their contents use the initramfs mechanism.

The archive is intentionally small compared with a full installed system. It commonly contains an `/init` program or script, a shell and basic utilities, selected kernel modules, device-management rules, and only the libraries and configuration required for early boot. When the kernel has completed its own initialization, it executes `/init`. That program becomes PID 1 for this temporary early userspace, so failures here often produce an emergency shell or a kernel panic saying that no working init could be found.

Early userspace performs whatever work is necessary to make the permanent root usable. Depending on the machine, it can:

- mount `/proc`, `/sys`, and `/dev` so processes can inspect the kernel and access device nodes;
- load storage, filesystem, or network driver modules that were not built into the kernel;
- wait for devices to appear and process udev events;
- unlock an encrypted root after obtaining a passphrase or key;
- assemble software RAID and activate LVM volume groups;
- configure networking for an NFS or iSCSI root; and
- find, check, and mount the filesystem named by the kernel command line or distribution configuration.

This is why initramfs is more than “some files packed next to the kernel.” It breaks the dependency cycle between needing the real root and needing code from that root in order to access it. It is a disposable bootstrap environment with its own PID 1.

### 5. Early userspace hands over to the real root

Once the permanent root has been mounted, the early `/init` moves essential virtual filesystems into it and performs a `switch_root`. Conceptually, that operation makes the mounted disk filesystem `/`, discards the no-longer-needed files from the temporary root, and executes the real init program from the new root.

The distinction between `switch_root` and merely changing directories matters. Every process resolves absolute paths relative to a root directory. The hand-over changes that root view and allows memory used only by early boot to be reclaimed. The early PID 1 does not start a second, unrelated process tree and remain beside it; it normally replaces itself with the installed system's init, preserving PID 1 across the transition.

### 6. PID 1 brings the operating system to its usable state

The real init is commonly `systemd`, although alternatives such as OpenRC, runit, or SysV init can occupy the same role. PID 1 mounts remaining filesystems, applies host configuration, starts device and network management, launches logging and other services, and brings the machine to its configured target. That target might provide a console login, SSH, a graphical display manager, or an appliance application.

“The kernel has booted” and “the operating system is usable” are therefore different milestones. The kernel can be running while early userspace is still trying to unlock a disk, and the real root can be mounted while network services are still starting.

## How the Multikernel boot path differs

The conventional path gives us a useful checklist for the child kernel. A Multikernel child still needs a kernel, a command line, a root containing an init, and enough initialization to reach its workload. It does not, however, start from a hardware reset or ask firmware and GRUB to find those artifacts.

The primary Linux system is already running. The Multikernel runtime selects CPUs and memory for a child, and Kerf loads an approved uncompressed `vmlinux` plus the private initramfs directly. For that child, Kerf and the runtime therefore occupy the artifact-loading position normally held by firmware and GRUB. The child kernel begins at the kernel stage, initializes the resources exposed to it, unpacks its initramfs, and starts the runtime-provided `/init`.

There is another important difference: in the implementation described here, the initramfs is not only a temporary bridge to a disk-backed root. It contains the runtime bootstrap as well as a copy of the OCI bundle and prepared image root. The runtime's init mounts the required pseudo-filesystems and starts `mk-agent`, which launches the configured image process. There is no conventional “discover a root disk, mount it, then `switch_root` into it” stage; the private initramfs remains the child's root for the sandbox lifetime.

```text
Conventional machine                  Multikernel child
--------------------                  -----------------
BIOS/UEFI                             Primary Linux is already running
  -> GRUB                               -> runtime selects child resources
  -> load vmlinuz + initramfs           -> Kerf loads vmlinux + initramfs
  -> kernel initializes hardware        -> child kernel initializes its view
  -> temporary /init                    -> runtime /init
  -> discover and mount real root        -> start mk-agent from private root
  -> switch_root                         -> launch OCI-configured process
  -> system init and services            -> isolated workload becomes usable
```

That comparison is the reason the archive-building details below matter. The generated initramfs is simultaneously the child's early userspace, its boot-time control plane, and the filesystem from which the container workload is launched. A missing `/init`, incompatible executable, absent pseudo-filesystem, or incomplete image root is not a late container-start error in this design: it can prevent the child from reaching a usable userspace at all.

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

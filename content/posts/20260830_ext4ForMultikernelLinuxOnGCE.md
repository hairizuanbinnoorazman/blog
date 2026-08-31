+++
title = "Persistent ext4 Roots for Multikernel Linux on Google Compute Engine"
description = "Why direct GCE Persistent Disk assignment to child kernels did not work, and how primary-mediated ext4 storage worked instead."
tags = [
    "linux",
    "google-cloud",
    "compute-engine",
    "multikernel",
    "ext4",
]
date = "2026-08-30"
categories = [
    "cloud",
]
+++

My first Multikernel Linux experiment on Google Compute Engine (GCE) showed that one VM could run a primary kernel and multiple child kernels at the same time. The children could use different kernel binaries, but their root filesystems were either minimal initramfs images or DAXFS. That left an important question unanswered: could a child kernel have a persistent, read-write ext4 root filesystem?

I tested two designs. Directly attaching a GCE Persistent Disk to a child kernel did not work safely on the tested GCE storage topologies. Keeping the disk under the primary kernel and mediating access to separate ext4 images did work thus far, including across child recreation, a GCE reset, and a full VM stop/start.

The scripts, reports, raw evidence, and exact limitations are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## The direct-disk idea

The most natural design was to give each child kernel its own GCE Persistent Disk:

```text
GCE VM
├── Primary kernel -> boot disk
├── Child kernel A -> child disk A, ext4
└── Child kernel B -> child disk B, ext4
```

This would give every child a conventional block device and an independently durable filesystem. The primary would not need to proxy block operations, and each child could mount its disk as `/`.

The design depends on Multikernel being able to transfer the child disk without also transferring a device required by the primary. That condition failed on the live GCE VM.

On the tested `n2-standard-16` instance, the boot disk and additional Persistent Disk appeared as separate SCSI targets, but both sat behind the same Virtio SCSI PCI function:

```text
PCI 0000:00:03.0 (virtio-pci / virtio_scsi)
├── SCSI 0:0:1:0 -> /dev/sda -> primary boot disk
└── SCSI 0:0:2:0 -> /dev/sdb -> intended child disk
```

The pinned Kerf and Multikernel versions allocate and transfer storage at PCI-function granularity. Kerf could describe `0000:00:03.0`, but it could not allocate `/dev/sdb`, its Google persistent by-id name, or SCSI target 2 independently. Passing the PCI function to a child would also pass the controller serving the primary kernel's live root disk.

That was a hard safety stop. I did not format the blank child disk or attempt the handoff.

## NVMe did not make the disk independently assignable

I also checked an alternate C3 VM using NVMe. The names changed, but the ownership problem remained:

```text
PCI 0000:00:05.0 (NVMe controller)
├── nvme0n1 -> boot disk
└── nvme0n2 -> intended child disk
```

Both disks were namespaces of the same NVMe controller and PCI function. Kerf has namespace-related fields in its model, but the pinned Multikernel kernel path still transfers the whole PCI function. A namespace in a configuration file was therefore not evidence of namespace-granular device ownership.

The conclusion is deliberately narrow: direct Persistent Disk assignment did not work with the tested N2/Virtio-SCSI and C3/NVMe topologies and the pinned Multikernel revision. It does not prove that every possible GCE machine or future Multikernel version has the same limitation. A topology exposing the child disk through a distinct assignable PCI function could change the result.

## Letting the primary manage the disk

The working alternative kept every GCE storage controller with the primary kernel:

```text
GCE VM
├── Primary kernel
│   └── /dev/sdb: outer ext4 filesystem
│       ├── child-a/root.ext4
│       └── child-b/root.ext4
├── Child kernel A
│   └── /dev/nbd0: child A ext4 image mounted as /
└── Child kernel B
    └── /dev/nbd0: child B ext4 image mounted as /
```

The additional 20 GiB Persistent Disk was mounted by the primary as an outer ext4 filesystem. It contained two separate, fully allocated 4 GiB image files. Each image also contained its own ext4 filesystem, UUID, root marker, and persistent counter.

One server process per image exported block operations from the primary over Multikernel's AF_VSOCK transport. Inside each child, a small adapter connected that transport to a loopback TCP socket accepted by Linux NBD. The child then saw `/dev/nbd0`, checked the expected ext4 UUID, and mounted it as its root filesystem.

No physical storage device was assigned to either child. Their Kerf device trees contained only CPU and memory resources, so the primary retained the boot disk, additional Persistent Disk, and shared virtual storage controller throughout the test.

## What worked

The decisive run started two children concurrently with different kernel binaries and different ext4 roots:

| Child | Kernel | Root filesystem | Final observed counter |
|---|---|---|---:|
| A | `7.0.0-mk2-gce-lab` | ext4 image A on `/dev/nbd0` | 7 |
| B | `7.0.0-mk2-gce-lab-alt` | ext4 image B on `/dev/nbd0` | 2 |

Each child saw only its expected filesystem UUID and marker. The separate image identity, server port, lock, protocol identity, and generation value prevented one child from accidentally mounting the other child's export.

Child A's counter advanced across repeated child deletion and recreation. It then survived a GCE reset and a complete GCE stop/start, advancing again after each boundary. At the end, offline `e2fsck -fn` checks returned successfully for child A, child B, and the outer ext4 filesystem.

This is the encouraging result: a disk managed by the primary and exposed as separate block images to new child kernels has worked in the experiment thus far. It provides persistence without risking the primary kernel's access to the shared GCE storage controller.

## The failures were useful

The mediated path needed several fixes before it worked:

- The Multikernel VSOCK code in the pinned tree did not compile unchanged against its kernel API. I applied a small recorded patch and added a receive-length safety check.
- Linux NBD rejected a direct AF_VSOCK file descriptor because it accepts TCP or Unix sockets. The child-local loopback adapter bridges that gap without assigning a NIC.
- Formatting ext4 through a loop device caused discard to punch holes in an initially allocated image. Re-running `fallocate` after formatting, followed by an allocation assertion, ensured the backing file was fully allocated.
- The minimal BusyBox environment did not include `blkid`. The child bootstrap instead reads the ext4 superblock UUID directly before mounting.
- Force-stopping a child did not promptly close the VSOCK connection. The server now uses bounded timeouts, discards incomplete writes rather than replaying them, and syncs completed operations before closing.

These details matter because a storage proof is not only about reaching a successful mount. Failure behavior, export identity, incomplete writes, allocation, and cleanup are part of determining whether the design is safe enough to continue testing.

## What this result does not prove

I would not call this a production storage service yet. The current experiment still needs a clean child-driven shutdown protocol that remounts read-only, flushes, disconnects NBD, and then stops the kernel. Forced shutdown left the ext4 journal marked for recovery even though later offline checks found no structural errors.

The transport also needs more work around backpressure, authentication, connection state, server crashes, malformed messages, and sustained I/O. I have not yet tested performance, ENOSPC behavior under live writes, snapshot recovery, or deliberately damaged child images.

There is also an architectural cost. Direct device ownership would give a child a short path to storage. The mediated design adds a server in the primary, an inter-kernel transport, a child-local adapter, NBD, an image file, and an outer filesystem. That is more code and more failure modes, even though it fits GCE's shared-controller topology.

## Current takeaway

Directly handing a GCE Persistent Disk to a new child kernel is not currently workable in this experiment. The disk may appear as a distinct `/dev` node or NVMe namespace, but the tested Multikernel stack transfers the shared controller at PCI-function granularity. A Linux block-device name is not the same thing as an independently assignable hardware boundary.

Keeping the physical disk managed by the primary kernel has worked much better thus far. The primary can safely retain GCE device ownership while giving multiple child kernels isolated, persistent, read-write ext4 roots through separate image-backed block exports.

That makes primary-mediated storage the practical direction for the next stage of this GCE experiment. The result is promising, but the remaining reliability and security work is substantial enough that I still consider it a functional proof rather than a production-ready design.

## References

- [Multikernel Linux on Google Compute Engine experiment](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})

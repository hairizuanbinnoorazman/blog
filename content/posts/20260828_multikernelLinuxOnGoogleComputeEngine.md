+++
title = "Can Multikernel Linux Run on Google Compute Engine?"
description = "Testing whether Linux 7.0-mk2 can run multiple child kernels inside a single Google Compute Engine VM."
tags = [
    "linux",
    "google-cloud",
    "compute-engine",
    "multikernel",
]
date = "2026-08-28"
categories = [
    "cloud",
]
+++

The idea behind Multikernel Linux is unusual: one physical machine can run several independent Linux kernels at the same time, without placing a conventional hypervisor between those kernels and the hardware. A primary kernel owns the machine's resources, moves selected CPUs, memory, and devices into a pool, and starts child kernels from that pool.

The [Linux 7.0-mk2 announcement on Phoronix](https://www.phoronix.com/news/Linux-7.0-mk2-Multikernel) describes it as an alternative somewhere between virtual machines and containers. Unlike containers, the children do not share a kernel. Unlike VMs, Multikernel does not add another virtualization layer, second-level page tables, or an emulated device model between its kernels.

That description naturally raises a cloud question: could Multikernel Linux run inside a Google Compute Engine (GCE) virtual machine, even though the GCE VM itself already runs on Google's hypervisor?

I built an experiment to find out. The complete scripts, runbook, results, and limitations are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Multikernel inside a VM

Running Multikernel on GCE creates a layered arrangement:

```text
Google physical host
└── Google KVM hypervisor
    └── One GCE virtual machine
        ├── Primary Linux 7.0-mk2 kernel
        ├── Child kernel A
        └── Child kernel B
```

This is not nested virtualization. The primary kernel uses Linux `kexec` and CPU hotplug to start another kernel alongside itself. Each child receives CPUs and guest-physical memory that were already assigned to the same GCE VM. Nested virtualization does not need to be enabled.

The distinction matters. A child is not a new GCE instance, and it cannot escape the properties of the outer VM. Its CPUs are GCE vCPUs rather than guaranteed dedicated physical cores. Its memory is backed by the VM's memory, and any assignable devices are virtual devices exposed by GCE. Google's maintenance behavior, scheduling, and outer hypervisor remain part of the system.

So this experiment does not test Multikernel's bare-metal performance claims. It tests whether its kernel lifecycle and resource partitioning can function correctly through GCE's virtual hardware.

## The GCE setup

I used an `n2-standard-16` instance in `asia-southeast1-b` with 16 vCPUs, 64 GB of memory, and Ubuntu 26.04. Secure Boot was disabled for the custom unsigned kernel path, while the stock Ubuntu kernel remained installed as a recovery option. Serial-port logging was enabled before changing the kernel.

I built the `v7.0-mk2` tree using the running Ubuntu GCE kernel configuration as a base, then enabled the essential Multikernel options:

```text
CONFIG_KEXEC=y
CONFIG_KEXEC_FILE=y
CONFIG_MULTIKERNEL=y
CONFIG_MKTTY=y
```

Reusing the GCE configuration retained the Virtio, storage, network, and guest support needed by the VM. After rebooting into the custom `7.0.0-mk2-gce-lab` kernel, SSH, the root disk, the `ens4` network interface, the metadata server, serial output, and the Google guest agent all continued to work.

That proved the primary kernel could boot on GCE, but it did not yet prove the Multikernel functionality.

## Starting two child kernels

The next step was to use Kerf, Multikernel's management tool, to reserve eight vCPUs and 16 GB of memory. One detail was particularly important: Kerf expects physical APIC IDs, not Linux logical CPU numbers.

On this VM, the mapping was interleaved:

```text
logical CPUs 0-7  -> APIC IDs 0,2,4,6,8,10,12,14
logical CPUs 8-15 -> APIC IDs 1,3,5,7,9,11,13,15
```

Assuming that logical CPU 8 maps to APIC ID 8 would therefore be unsafe. APIC ID 0 is also the boot CPU and must remain with the primary kernel.

I created two children without assigning either one a PCI or platform device:

| Child | APIC IDs | Memory |
|---|---|---:|
| `smoke-a` | 8, 10, 12, 14 | 8 GB |
| `smoke-b` | 9, 11, 13, 15 | 7 GB |

The one-gigabyte gap was deliberate. Splitting a nominal 16 GB pool into two exact 8 GB allocations failed because Multikernel needs a small amount of memory for its own bookkeeping.

Both children loaded the same uncompressed `vmlinux` with a minimal BusyBox initramfs. Their MKTTY consoles independently reported four online CPUs, the expected memory, and a `CHILD_READY` marker. Kerf showed both instances as active at the same time.

While they were running, the primary kernel remained reachable over a new SSH connection. Its boot ID did not change, the guest agent remained active, and its network and metadata access still worked. After stopping and deleting the children, all 16 vCPUs and approximately 61 GB of host memory were available to the primary kernel again.

That answers the central question: yes, Multikernel Linux can run inside the tested GCE VM topology. GCE's virtual APIC accepted the CPU parking, child startup, shutdown, and resource-return sequence used by `v7.0-mk2`.

## Taking the experiment further

I also tested whether two workloads derived from Docker images could run under different child kernels. This needs careful wording because it does not change normal Docker behavior. An ordinary Docker container still shares the Docker host's kernel.

In this experiment, Docker supplied an OCI root filesystem. Kerf serialized that filesystem into DAXFS, and Multikernel started it using a separately selected child `vmlinux`. Two children then ran concurrently with distinct kernel binaries:

| Child | Kernel release | Root filesystem |
|---|---|---|
| `docker-kernel-a` | `7.0.0-mk2-gce-lab` | Docker-derived DAXFS root |
| `docker-kernel-b` | `7.0.0-mk2-gce-lab-alt` | Docker-derived DAXFS root |

Both children reported their expected release and a `DOCKER_IMAGE_READY` marker while the primary kernel remained healthy. This demonstrates a different kernel per Docker-derived workload, not a different kernel per conventional container.

## What is not ready yet

The successful boot is only the beginning. Several areas still need work before I would treat this as a production design.

Networking is the most immediate gap. The tagged kernel's optional Multikernel VSOCK transport did not compile against the Linux 7.0 callback signature, so I disabled it rather than patching an unverified network path into the initial proof. Assigning the GCE VM's only virtual NIC to a child would also risk disconnecting the primary kernel. A future experiment needs a working inter-kernel transport and probably a proxy in the primary kernel's userspace.

Storage also needs a conservative design. A self-contained initramfs is safest for a first child because the GCE boot disk must stay with the primary kernel. DAXFS worked as a child root, including for Docker-derived filesystems, and two children could share it read-only. However, simultaneous writable sharing was not coherent at the tested revisions. One child retained a stale negative lookup after another created a file, and contending writers observed different file contents. I would use DAXFS read-only or with a single writer until explicit cross-kernel cache invalidation exists.

DAXFS in this setup is shared memory rather than durable storage. Data survived a child restart while its allocation remained alive, but that says nothing about persistence after releasing the pool, rebooting the host, stopping the VM, or losing the machine.

There are also cloud lifecycle questions that the experiment did not answer:

- Are APIC IDs stable across VM stop/start or when creating another VM from an image?
- What happens to active child kernels during GCE live migration or host maintenance?
- How does Multikernel interact with memory ballooning?
- What security boundary can be claimed when all kernels remain inside one outer VM?

These need their own tests. A successful child boot should not be stretched into a broader claim about availability, isolation, or performance.

## Where this could be useful

The model is interesting for workloads that need stronger kernel separation than containers while avoiding another guest-hypervisor layer inside an already virtualized cloud machine. It could also make kernel experiments more flexible: a primary kernel could retain management access while child kernels run different builds on partitioned resources.

The trade-off is maturity and operational complexity. CPU identifiers, kernel configuration, recovery, networking, storage ownership, and cleanup all require more care than launching either a container or a normal GCE VM. For most applications, those established abstractions remain the practical choice.

Still, the result is promising. A single GCE VM successfully ran a custom primary kernel and two concurrent child kernels, later ran two Docker-derived workloads with distinct kernels, and returned its resources cleanly. Multikernel Linux is therefore possible on GCE—not as a replacement for Google's hypervisor, but as another kernel-partitioning layer inside one of its VMs.

## References

- [Linux 7.0-mk2 Released For Multi-Kernel Linux With Promising Performance Results](https://www.phoronix.com/news/Linux-7.0-mk2-Multikernel)
- [Multikernel Linux on Google Compute Engine experiment](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)

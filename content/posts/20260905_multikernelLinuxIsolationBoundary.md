+++
title = "The Isolation Boundary of Multikernel Linux Containers"
description = "Why CPU and memory allocation between Multikernel siblings is useful fault containment but not a KVM or EPT security boundary."
tags = [
    "linux",
    "containers",
    "security",
    "multikernel",
]
date = "2026-09-05"
categories = [
    "cloud",
]
+++

The phrase “one kernel per container” sounds like a stronger isolation claim than “one process namespace per container.” In a Multikernel Linux runtime, each child really does have its own kernel, process table, boot ID, CPUs, memory description, and root filesystem. That still does not make it equivalent to a virtual machine.

My earlier experiments showed useful separation: two child kernels ran concurrently, a crashing child returned to a reclaimable state, and the primary remained reachable. Those are resource-lifecycle and fault-containment results. They are not proof that a malicious ring-0 child cannot access another kernel's memory or disrupt the machine.

This article draws the trust boundary used by my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Separate kernels are not automatically virtual machines

A conventional KVM guest runs beneath a hypervisor boundary. On x86, second-level address translation such as EPT restricts which host physical pages the guest can access. Privileged operations and virtual devices are mediated by the virtualization architecture.

A Multikernel child is entered directly in kernel mode on CPUs and memory handed off by the primary. There is no separate virtual machine monitor interposing every privileged operation.

```text
KVM-style guest                    Multikernel child
---------------                    -----------------
guest page tables                  child page tables
  -> EPT / second-level mapping      -> physical addresses
  -> host physical memory            -> machine memory

hypervisor mediates privilege      child runs as an x86 kernel
virtual devices                    selected resources are handed off/shared
```

This design can avoid some virtualization overhead and allow specialized kernels to use dedicated resources. Its security properties must be stated differently.

## Memory allocation is software coordinated

The primary allocates physically contiguous pages, removes them from its ordinary allocator, and records disjoint regions for each child. The child's E820 map advertises only those regions as RAM, and its initial identity mappings cover those assigned regions.

For an approved, trusted child kernel, these are meaningful controls. Normal memory discovery and allocation remain within the grant, and two children do not accidentally receive the same recorded region.

They do not create a hostile-kernel memory boundary. The child runs at ring 0 and there is no EPT layer preventing it from constructing page tables for other physical addresses that it can discover or guess. The correct claim is software-coordinated ownership and accidental-access protection—not hardware-enforced confidentiality or integrity between hostile siblings.

The Multikernel DMA heap is even more explicit: it maps selected pool pages for sharing between userspace, kernels, and devices. Shared memory is a transport mechanism, not isolation.

## CPU handoff is exclusive but shares the platform

Before assigning a CPU, the primary takes it offline and parks it. The implementation records pool membership and rejects invalid returns. After a successful handoff, the logical CPU executes the child rather than ordinary primary work.

The runtime adds several policies:

- never allocate APIC ID 0;
- keep management CPUs and memory headroom in the primary;
- allocate complete cores rather than splitting SMT siblings; and
- reject duplicate, offline, or topologically inconsistent CPU input.

Exclusive logical-CPU execution does not isolate the rest of the platform. Siblings can share last-level cache, memory bandwidth, power controls, and interrupt infrastructure. A bare-metal ring-0 child can program privileged CPU facilities that a hypervisor would normally interpose.

Therefore CPU allocation supports deterministic placement and useful failure containment for trusted kernels. It does not prove side-channel resistance or denial-of-service containment.

## Interrupts, MSRs, and I/O ports remain privileged

Multikernel uses shared memory and inter-processor interrupts for communication. Its receive path bounds ring indexes and discards abandoned entries after respawn, which helps contain accidental corruption.

The child can still execute privileged instructions. The reviewed path does not provide a hypervisor boundary around arbitrary local APIC programming, model-specific registers, or I/O-port access. A malicious kernel could attempt effects outside the intended cooperative protocol.

This is one reason the runtime selects child kernels from a small approved manifest. The kernel, matching modules, initramfs, transport behavior, hashes, and shutdown path are qualified together. Allowing an untrusted workload to supply its own kernel would cross the current trust boundary immediately.

## Device ownership is more dangerous than a device name

My [persistent ext4 experiment]({{< ref "20260830_ext4ForMultikernelLinuxOnGCE.md" >}}) originally explored giving a child a cloud disk directly. On GCE N2, the candidate disk and the primary boot disk shared the same allocatable PCI function. Passing that controller would not mean passing only one harmless block device.

Multikernel can unbind and record a PCI function, and a child can filter PCI discovery against its assigned manifest. That software allowlist is not proof of:

- IOMMU isolation;
- interrupt remapping;
- PCIe ACS isolation;
- reset isolation; or
- independence between functions, controllers, and upstream bridges.

The runtime consequently prohibits physical-device assignment. The primary retains the GCE boot disk, external NIC, and their shared controllers. Storage and networking are mediated instead:

```text
physical disk and NIC
  -> primary-owned drivers and services
      -> bounded storage or packet transport
          -> virtual endpoint in the child
```

This reduces the resources directly exposed to the child and avoids accidentally removing infrastructure needed to keep the primary reachable. It still trusts both kernels at the broader machine boundary.

## Authentication prevents stale peers, not hostile kernels

Each agent session is bound to the sandbox ID, generation, endpoint, sequence number, and a random token. Requests carry an HMAC, and local service sockets validate peer credentials. These mechanisms stop a stale shim or accidental peer from controlling a different sandbox generation.

They cannot protect a secret from a compromised primary, which built the child's bootstrap, or from a malicious sibling kernel able to read shared physical memory. Authentication strengthens identity inside the stated trusted-node model. It does not convert shared bare-metal privilege into cryptographic isolation.

## The actual trust model

The runtime currently trusts:

- the operator and node configuration;
- the primary kernel;
- `mkruntimed`, `mknetd`, and the approved Kerf binary;
- the approved child kernel, modules, initramfs, and `mk-agent`; and
- workloads sufficiently trusted for a single-tenant node.

It treats OCI metadata, bundle files, protocol bytes, identifiers, paths, workload processes, and stale durable state as untrusted inputs. These inputs are bounded and validated, but the workload still executes under a kernel that shares the physical machine without a hypervisor boundary.

The resulting policy can be summarized per resource:

| Resource | Useful current property | Property not claimed |
|---|---|---|
| Logical CPUs | Exclusive after coordinated handoff | Platform or SMT side-channel isolation |
| Memory capacity | Disjoint recorded allocation and child E820 view | EPT-enforced protection from malicious ring 0 |
| Control transport | Bounded parsing and generation authentication | Secrecy from a compromised sibling kernel |
| Storage/network | Primary-owned mediated endpoints | Safe arbitrary device pass-through |
| Child failure | Tested recovery for specific cooperative crashes | Adversarial denial-of-service resistance |

## What the experiments do prove

The narrow results remain valuable. The repository has evidence that:

- the primary can reserve CPUs and memory, boot two children, and reclaim them;
- child kernels see distinct CPU, memory, process, and boot identities;
- a specific child PID 1 crash returns to a recoverable Multikernel state;
- storage and external networking can work without assigning their physical controllers;
- normal teardown returns the tested resources; and
- host qualification rejects several unsafe configurations before mutation.

Those are foundations for trusted kernel specialization and stronger operational containment than placing every workload directly in the primary kernel. They simply answer a different question from hostile multi-tenancy.

## What would strengthen the boundary

A stronger security claim would require a different or expanded architecture: hardware-backed second-level memory translation, interrupt and DMA isolation, carefully virtualized or mediated privileged operations, adversarial tests, and an independently reviewed threat model. Failure-injection tests can improve recovery confidence, but they cannot prove a hardware boundary that is absent from the design.

For the current runtime, precision is the most useful security feature. “Trusted, single-tenant Multikernel runtime with software-coordinated resource isolation” is less dramatic than “VM-like sandbox,” but it tells an operator what can safely run there and what must not.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Pinned Multikernel isolation audit](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/research/g1-pinned-isolation-audit.md)
- [Ownership and trust contract](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/contracts/ownership-and-trust.md)
- [Host qualification and isolation learnings](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/learnings/01-g1-host-and-isolation.md)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})
- [Persistent ext4 Roots for Multikernel Linux on Google Compute Engine]({{< ref "20260830_ext4ForMultikernelLinuxOnGCE.md" >}})

+++
title = "How Hypervisors Isolate Virtual Machine Memory"
description = "Comparing Intel EPT, AMD NPT, Arm Stage-2 translation, shadow page tables, and software emulation as memory boundaries beneath a guest kernel."
tags = [
    "linux",
    "virtualization",
    "security",
    "hypervisor",
]
date = "2026-09-07"
categories = [
    "cloud",
]
+++

While investigating the [isolation boundary of Multikernel Linux containers]({{< ref "20260905_multikernelLinuxIsolationBoundary.md" >}}), I kept returning to one comparison: why can a compromised virtual-machine guest kernel not simply map the host's memory, while a compromised Multikernel child kernel can attempt to map memory outside its allocation?

The short answer is that a hypervisor keeps control of the final address translation. Extended Page Tables, or EPT, are Intel's modern implementation of that idea, but EPT is neither the generic name nor the only way to build the boundary.

This article looks at the major implementations and the security property they have in common.

## Start with ordinary process memory

A process normally works with virtual addresses. If an instruction reads address `0x4000`, that number does not directly select a DRAM location. The CPU walks page tables prepared by the operating-system kernel and translates the process's virtual page into a physical page.

Page-table entries also carry permissions. They can distinguish user from kernel access and allow or deny reading, writing, or execution. If no valid permitted mapping exists, the CPU raises a page fault rather than completing the access.

```text
process virtual address
  -> operating-system page tables
  -> physical address
```

This protects processes from each other only while the kernel remains trusted. The kernel constructs the page tables and chooses the register that points to them. After an attacker compromises the kernel, the attacker can create new mappings to physical memory the kernel can reach.

A virtual-machine monitor must therefore enforce its boundary below the guest kernel, using state that the guest cannot replace.

## Hardware-assisted virtualization adds a second translation

In a modern hardware-assisted VM, the guest kernel still maintains page tables. They translate a guest virtual address into what the guest believes is a physical address. The processor then performs a second translation controlled by the hypervisor:

```text
guest virtual address
  -> guest page tables controlled by guest kernel
  -> guest-physical address
  -> second-stage tables controlled by hypervisor
  -> host-physical address
```

This separation lets the guest manage its processes normally without giving it authority over host memory. A compromised guest kernel may point its own virtual addresses at any guest-physical page it has, but it cannot create a second-stage entry for an unassigned host page.

The important security requirement is not a particular product name:

> Enforce the guest's memory boundary in a layer that the guest kernel cannot modify.

The implementation depends on architecture and virtualization mode.

## Intel Extended Page Tables

Intel calls its second-stage mechanism Extended Page Tables. EPT is a hierarchy of translation tables maintained by the hypervisor and consulted by the CPU while executing a guest in VMX non-root mode.

An EPT entry identifies the host-physical page backing a guest-physical page and whether the guest may read, write, or execute it. For example:

```text
guest page table
  guest virtual page 0x4000
    -> guest-physical page 0x2000

hypervisor EPT
  guest-physical page 0x2000
    -> host-physical page 0x8a000, read/write
```

The guest may change the first mapping. It could point another guest virtual address at guest-physical page `0x2000`. It cannot use that freedom to select arbitrary host page `0x8b000`, because the second mapping remains under hypervisor control.

If an access has no permitted EPT entry, the CPU produces an EPT violation and transfers control to the hypervisor instead of completing the memory operation. Depending on the reason, the hypervisor can install a legitimate mapping, emulate memory-mapped I/O, record a dirty page, inject a guest-visible fault, or stop the VM.

The security property is that a hostile guest kernel cannot tell the CPU to skip the EPT lookup. Reaching host memory then requires another vulnerability in the hypervisor, KVM, device emulation, or a host-facing interface.

## AMD Nested Page Tables

AMD's corresponding x86 mechanism is Nested Page Tables, usually shortened to NPT. It has also been marketed as Rapid Virtualization Indexing.

The terminology differs, but the relevant translation is the same shape:

```text
guest virtual -> guest physical -> system physical
                 guest owns        hypervisor owns
```

KVM uses the vendor-neutral term two-dimensional paging, or TDP, for both Intel EPT and AMD NPT. Second Level Address Translation, or SLAT, is another common generic description.

EPT and NPT are not separate security models. They are vendor implementations of hardware-assisted guest-physical to host-physical translation.

## Arm Stage-2 translation

Arm describes the two layers as stages. Stage 1 is controlled by the guest operating system and translates virtual addresses into Intermediate Physical Addresses, or IPAs. The guest treats an IPA as though it were a physical address.

Stage 2 is controlled by the hypervisor and translates the IPA into a real physical address:

```text
guest virtual address
  -> Stage 1 controlled by guest OS
  -> intermediate physical address
  -> Stage 2 controlled by hypervisor
  -> physical address
```

Stage-2 entries also control access to memory-mapped resources. As with EPT and NPT, the guest cannot expand its allocation merely by changing the tables it owns at Stage 1.

Intel EPT, AMD NPT, and Arm Stage 2 are therefore architecture-specific versions of the same two-owner translation design.

## Shadow page tables work without EPT or NPT

Older x86 processors could run virtual machines without hardware second-stage translation. Hypervisors used shadow page tables instead.

The guest maintained the page tables it believed were active, but those tables were not given direct authority over machine memory. The hypervisor constructed separate hardware-visible shadow tables combining:

- the guest's requested virtual-to-guest-physical mapping; and
- the hypervisor's permitted guest-physical-to-host-physical mapping.

```text
guest changes its page tables
  -> hypervisor intercepts or observes the change
  -> hypervisor validates and updates shadow tables
  -> CPU uses hypervisor-controlled shadow mapping
```

The guest's relevant page-table writes and control-register changes had to cause traps or synchronization work. The hypervisor also had to invalidate and rebuild shadow mappings when guest or host memory state changed. This created substantially more complexity and overhead than letting hardware walk a separate EPT or NPT hierarchy.

Shadow paging nevertheless preserves the central property: the compromised guest does not control the final hardware-visible mapping to host pages.

## Software emulation can enforce the boundary in software

A full system emulator does not need to execute guest instructions directly on the host CPU. QEMU's Tiny Code Generator, for example, can translate guest instruction blocks into host code and emulate the guest MMU.

In this model, guest “physical memory” is data managed by the emulator process. The software MMU translates or checks guest memory accesses, and accesses to memory-mapped devices call device-emulation code.

```text
emulated guest instruction
  -> software MMU translation and bounds
  -> emulator-managed memory region or virtual device
```

This does not require EPT because the guest is not directly controlling the host CPU's page-table walk. It is generally slower than hardware-assisted virtualization, although translation caches and generated host code reduce the cost.

Software enforcement is still software attack surface. A bounds, translation, or device-emulation bug in the emulator can become a guest escape. “Does not use EPT” does not mean “has no boundary”; it means the boundary is implemented differently.

## Type 1 versus Type 2 is a separate classification

A Type 1 hypervisor runs directly on the hardware, while a Type 2 hypervisor runs with or through a host operating system. That classification does not determine whether a VM uses EPT, NPT, Stage 2, shadow paging, or emulation.

KVM uses the Linux kernel for hardware virtualization while a userspace VMM such as QEMU provides much of the machine model. A desktop virtualization product can use the same CPU second-stage facilities. A bare-metal hypervisor can also fall back to shadow paging on older hardware.

The useful question for memory isolation is not merely where the VMM process runs. It is which component controls the final translation and whether the guest can modify it.

## An IOMMU protects a different source of memory access

EPT, NPT, and Stage-2 CPU translation constrain memory references made by virtual CPUs. A physical device can access memory through Direct Memory Access, or DMA, without executing a guest CPU load or store.

When a device is assigned to a VM, an IOMMU supplies a separate translation and permission boundary for its DMA requests. Intel calls its I/O virtualization technology VT-d; AMD uses AMD-Vi. Without correct IOMMU configuration, a device controlled by the guest could potentially DMA outside the guest's CPU-memory allocation even though EPT itself is correct.

```text
virtual CPU access -> EPT/NPT/Stage 2 -> permitted host memory
assigned-device DMA -> IOMMU          -> permitted host memory
```

This is why a claim such as “the VM uses EPT” is not enough to make arbitrary PCI pass-through safe. Interrupt remapping, reset isolation, PCIe topology, and whether several devices share a controller or group also matter.

## EPT alone does not make a VM secure

Second-stage translation is a strong memory boundary, but a VM still exposes interfaces that consume guest-controlled input:

- hypervisor and KVM code;
- virtual-device and device-emulation implementations;
- paravirtualized storage and network backends;
- management and migration services;
- physical-device assignment and IOMMU configuration; and
- shared CPU caches, memory bandwidth, and other side-channel or denial-of-service surfaces.

A successful VM escape normally exploits one of those host-facing components after compromising—or simply controlling—software inside the guest. EPT prevents the guest from bypassing them by directly installing a host-physical mapping, but it cannot make their implementations bug-free.

Confidential virtual machines add another distinction. Ordinary virtualization primarily protects the host and other guests from a guest. The hypervisor remains trusted and can generally inspect ordinary guest memory. Hardware memory encryption and attestation attempt to protect a guest from parts of the host as well. That is a different trust direction from EPT's basic address-isolation role.

## MicroVMs generally use the same memory machinery

A microVM reduces the virtual hardware and management surface rather than inventing a new kind of address translation. When a microVM uses KVM on x86, its guest-memory isolation normally comes from the same EPT or NPT support used by a larger VM.

Fewer emulated devices can mean fewer host-facing parsers and a smaller attack surface. It does not replace the second-stage memory boundary. “Micro” describes the machine model and operational footprint, not weaker memory isolation.

## Applying this comparison to Multikernel Linux

A Multikernel child has its own ordinary page tables, but there is no new hypervisor-controlled translation between the child and primary kernels:

```text
Multikernel child process
  -> child virtual address
  -> child page tables controlled by child kernel
  -> GCE guest-physical address
```

The primary can reserve a contiguous range, remove it from its normal allocator, tell the child about only that range through E820, and build initial mappings for it. These controls keep approved kernels and ordinary child processes in the intended allocation during normal operation.

After a child-kernel compromise, however, the attacker controls the only relevant page-table hierarchy inside the GCE guest. There is no EPT, NPT, shadow table, or software MMU between that child and other guest-physical addresses belonging to the primary or sibling children.

GCE's outer hypervisor still has its own second-stage boundary. It sees the primary and Multikernel children as execution belonging to one GCE VM and prevents that VM from directly mapping arbitrary cloud-host memory. It does not distinguish the inner primary from its children, so its mapping includes the complete guest-physical address space assigned to that GCE VM.

This gives the project useful process separation, kernel specialization, resource accounting, and fault containment for approved child kernels. It does not give the primary a VM-style memory boundary against a hostile child kernel.

That is the comparison I needed for the Multikernel runtime: setting memory aside describes who should use it; a hypervisor-controlled final translation enforces who can use it after a guest kernel stops cooperating.

## References

- [Linux KVM x86 MMU documentation](https://docs.kernel.org/7.0/virt/kvm/x86/mmu.html)
- [Intel Software Developer's Manual: Extended Page Tables](https://www.intel.com/content/dam/support/us/en/documents/processors/pentium4/sb/253669.pdf)
- [Arm guide to Stage-2 address translation](https://developer.arm.com/documentation/101811/0104/Address-spaces)
- [QEMU system emulation and virtualization accelerators](https://www.qemu.org/docs/master/system/introduction.html)
- [QEMU software MMU implementation](https://www.qemu.org/docs/master/devel/tcg.html)
- [The Isolation Boundary of Multikernel Linux Containers]({{< ref "20260905_multikernelLinuxIsolationBoundary.md" >}})


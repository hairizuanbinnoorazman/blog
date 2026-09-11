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

## How page tables operate in Linux

To understand why a hypervisor needs a second translation stage, it helps to examine how single-stage page tables work in a standard Linux system.

### What a page table is

A page table is a hierarchical tree data structure stored in physical RAM that maps virtual addresses to physical memory addresses. Physical memory is divided into fixed-size blocks called page frames (standard 4 KiB on x86-64, though 2 MiB and 1 GiB huge pages are also supported), and virtual memory is similarly divided into pages.

Because a flat array mapping every 4 KiB page in a 64-bit address space would require petabytes of storage, modern architectures use a multi-level radix tree. On standard x86-64 systems with 48-bit virtual addressing (4-level paging), the 48 bits of a virtual address are divided into five components:

```text
63        48 47    39 38    30 29    21 20    12 11          0
+-----------+--------+--------+--------+--------+------------+
| Sign-ext  | PGD    | PUD    | PMD    | PTE    | Offset     |
| (16 bits) | 9 bits | 9 bits | 9 bits | 9 bits | (12 bits)  |
+-----------+--------+--------+--------+--------+------------+
```

1. **Sign-extension (bits 48–63):** Canonical address check (must match bit 47).
2. **PGD index (bits 39–47):** Selects an entry in the Page Global Directory (Level 4).
3. **PUD index (bits 30–38):** Selects an entry in the Page Upper Directory (Level 3).
4. **PMD index (bits 21–29):** Selects an entry in the Page Middle Directory (Level 2).
5. **PTE index (bits 12–20):** Selects an entry in the Page Table Entry array (Level 1).
6. **Offset (bits 0–11):** Identifies the exact byte within the 4 KiB physical page frame.

Systems with 57-bit virtual addressing add a fifth level, the P4D / PML5, before the PGD/PUD.

Each entry in the table is an 8-byte (64-bit) descriptor containing the base physical address of the next table level (or the final page frame) alongside architectural control and permission flags:

| Bit(s) | Name | Purpose |
|---|---|---|
| 0 | `P` (Present) | `1` if the page is currently in physical DRAM; `0` if unmapped or swapped out |
| 1 | `R/W` (Read/Write) | `0` for read-only; `1` for read-write access |
| 2 | `U/S` (User/Supervisor) | `0` restricts access to kernel privilege (Ring 0–2); `1` allows user-mode (Ring 3) |
| 3 | `PWT` (Page-level Write-Through) | Configures caching policy for the page |
| 4 | `PCD` (Page-level Cache Disable) | Disables CPU caching for memory-mapped I/O |
| 5 | `A` (Accessed) | Automatically set to `1` by CPU hardware when the page is read or written |
| 6 | `D` (Dirty) | Automatically set to `1` by CPU hardware when the page is modified (leaf PTE level) |
| 7 | `PS` (Page Size) | In PUD/PMD levels: designates a huge page (1 GiB or 2 MiB) directly |
| 63 | `NX` / `XD` (No-Execute) | When set, instruction fetches from this page fault, preventing arbitrary code execution |

### Which CPU instructions manipulate page tables

Ordinary applications do not execute explicit instructions to translate addresses. When code executes a standard instruction like `mov (%rax), %rbx` or pushes to the stack, the CPU's Memory Management Unit (MMU) walks the page tables automatically in hardware.

The CPU provides specific privileged instructions to manage and control the page-table mechanism:

- **Activating page tables (`mov %cr3`):**
  On x86-64, Control Register 3 (`CR3`) holds the physical base address of the active root page directory (the PGD). Loading `CR3` is a privileged instruction executed only in Ring 0:
  ```assembly
  mov %rax, %cr3
  ```
  Executing this instruction switches the current active virtual address space. By default, writing to `CR3` also causes the CPU to automatically flush all non-global entries in the Translation Lookaside Buffer (TLB). On Arm64, the equivalent registers are `TTBR0_EL1` for userspace and `TTBR1_EL1` for the kernel, loaded via `msr`.

- **Reading faulting addresses (`mov %cr2`):**
  When a memory access violates permissions or references a non-present entry, the CPU raises an architectural Page Fault exception (`#PF`, interrupt vector 14). Before jumping to the kernel's fault handler, the CPU hardware stores the linear virtual address that caused the fault in Control Register 2 (`CR2`). The kernel inspects it using:
  ```assembly
  mov %cr2, %rax
  ```
  On Arm64, the faulting address is placed in `FAR_EL1` (Fault Address Register).

- **Invalidating cached translations (`invlpg` and `invpcid`):**
  Because walking DRAM tables on every access would be too slow, the CPU caches recent virtual-to-physical translations in the Translation Lookaside Buffer (TLB). When the kernel modifies or unmaps a virtual page, it must invalidate stale TLB entries:
  ```assembly
  invlpg (%rax)
  ```
  `invlpg` flushes the TLB entry for the single virtual page specified by the memory operand. Process-Context Identifiers (PCID) also permit the kernel to invalidate cached translations for specific address-space tags via `invpcid`. On Arm64, this is performed with `tlbi` instructions.

### How the Linux kernel operates page tables in normal cases

Under normal, steady-state conditions (when the system is not under memory pressure or thrashing swap), Linux manages page tables through four coordinated steps:

#### 1. Address space separation at process creation
Every Linux process has a distinct `struct mm_struct` in the kernel representing its address space, with `mm->pgd` pointing to its allocated root page directory.

Linux divides the 64-bit virtual address space into two halves:
- **Userspace (low half):** Addresses `0x0000000000000000` to `0x00007fffffffffff` (128 TiB). Unique to each process.
- **Kernel space (high half):** Addresses `0xffff800000000000` to `0xffffffffffffffff` (128 TiB). Identical across all processes.

When a process is created via `fork()` or `execve()`, the kernel allocates a new PGD page. It leaves the lower half empty or establishes copy-on-write mappings, and populates the upper half by synchronizing the global kernel-space entries.

#### 2. Context switching (`switch_mm`)
When the Linux CPU scheduler selects a new process to run, the architecture-specific context switch routine calls `switch_mm()`:

```text
scheduler picks next task
  -> check if next->mm matches current active mm
  -> if different: write physical address of next->pgd to CR3
  -> CPU TLB recognizes new address space
```

If the CPU supports PCID (Process-Context Identifiers), the kernel associates each process with an address-space ID. This lets the kernel update `CR3` without flushing the entire TLB, keeping cached translations hot when returning to recently scheduled threads.

#### 3. Lazy allocation via demand paging
In a normal Linux system, allocating memory does not immediately populate page tables or allocate physical RAM:

1. **Virtual allocation:** When a process calls `malloc()` or `mmap()`, the kernel merely records a new Virtual Memory Area (`struct vm_area_struct`) tracking that this virtual range is valid and what permissions it has. No physical DRAM is assigned, and no leaf PTE is created yet.
2. **First access triggers `#PF`:** When the process first attempts to read or write that memory (e.g. `mov %rbx, (%rax)`), the CPU walks the page table, finds the PTE absent (`Present = 0`), halts execution, saves the address to `CR2`, and generates a page fault (`#PF`).
3. **Kernel resolves fault:** The kernel's page fault handler (`do_page_fault()` -> `handle_mm_fault()`) catches the exception:
   - It checks whether the address in `CR2` falls within a valid `vm_area_struct`.
   - If valid, it pulls a fresh 4 KiB physical page frame from the buddy allocator.
   - For security, it zeros the page to prevent leaking previous memory contents.
   - It populates intermediate table levels if missing and writes the physical address into the leaf PTE with `Present = 1`, `R/W = 1`, and `U/S = 1`.
4. **Resumed execution:** The kernel executes `iretq` to return from the exception. The CPU automatically re-executes the exact instruction that faulted. This time, the MMU finds a valid entry, writes the translation to the TLB, and completes the write.

#### 4. Fast-path steady-state execution
Once a page is mapped and cached in the TLB, subsequent memory accesses require **zero kernel intervention**. The CPU pipeline translates the virtual address to physical DRAM in hardware within 1–2 clock cycles.

This entire mechanism depends on trust in the operating-system kernel. Because the kernel executes in Ring 0, it holds unrestricted control over `CR3`, page tables, and page fault resolution. If an attacker gains kernel execution, the attacker can modify any PTE to point anywhere in physical RAM.

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


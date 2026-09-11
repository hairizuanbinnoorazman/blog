+++
title = "Running OCI Processes Inside a Multikernel Linux Child"
description = "How mk-agent validates an OCI bundle, starts container processes in a child kernel, and translates exec, signals, terminals, streams, and exit status."
tags = [
    "linux",
    "containers",
    "oci",
    "multikernel",
]
date = "2026-09-03"
categories = [
    "cloud",
]
+++

In [Turning Container Images into Multikernel Linux Roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}}), I described how an unpacked image becomes a private root for a child kernel. That gets the files into the right place, but files are not yet a running container. Something inside the child still has to interpret the OCI process configuration, establish its safety boundaries, start the executable, and translate later `exec`, signal, terminal, and wait requests.

That component is `mk-agent`. It runs inside the child kernel and manages processes whose PIDs do not exist in the primary kernel's process table. This article follows that child-side process lifecycle. The implementation is in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## The child starts with a runtime, not an operating system

Kerf loads an approved `vmlinux`, a runtime-built initramfs, and a generated command line. The child does not pass through firmware, GRUB, or a distribution installer. Its `/init` mounts the small set of pseudo-filesystems needed by the runtime, loads the Multikernel transport, obtains the sandbox identity from the command line, and starts `mk-agent`.

The roles inside the child are approximately:

```text
child kernel
  -> /init as PID 1
      -> prepare /dev, /proc, /sys, cgroup v2, and storage
      -> start mk-agent
          -> validate the runtime-owned OCI bundle
          -> create and supervise container processes
          -> mediate I/O, signals, network packets, and shutdown
```

The bootstrap BusyBox and `mk-agent` belong to the runtime. The workload executable and its libraries belong to the OCI root. Keeping those owners separate prevents an image from replacing the control agent that is responsible for starting it.

## `CreateProcess` validates before changing process state

The shim sends a `CreateProcess` request naming a fixed runtime-owned bundle. `mk-agent` does not accept an arbitrary host path from every process request. It opens `config.json`, validates it strictly, resolves the bundle-relative `root.path`, and records a process in `CREATED` state.

Path validation matters even inside the child. The configuration file must be a bounded, private, single-link regular file. It is opened without following symlinks or magic links, and its device, inode, size, modification time, and change time are compared before and after reading. The root path must remain beneath the bundle and contain only real directory components.

The parser also rejects unknown JSON fields and more than one JSON value. A field that the runtime does not understand should not disappear silently and leave the user believing it was enforced.

The current agent accepts OCI configuration version `1.1.0` and validates bounded process arguments, environment variables, working directory, UID, GID, supplementary groups, terminal selection, `noNewPrivileges`, rlimits, and Linux capability sets. It can also apply the supported hostname, masked paths, read-only paths, and read-only-root policy.

Several larger OCI surfaces remain explicitly unsupported in the guest projection, including arbitrary mounts and hooks, Linux namespace descriptions, cgroup resource configuration, seccomp, and annotations. The correct behavior is to reject such a bundle before starting its workload. Partial OCI support is defensible only when it fails closed.

## `StartProcess` crosses into the image root

Create and start remain separate operations, matching containerd's task lifecycle. On `StartProcess`, the agent verifies that `argv[0]` is absolute and that the target is a regular 64-bit x86 ELF executable. This catches an architecture mismatch before reporting a running process.

For a normal non-terminal process, the agent prepares:

- a chroot into the validated OCI root;
- the requested UID, GID, and supplementary groups;
- the exact argument and environment arrays;
- the requested working directory;
- a new process group for signal delivery; and
- separate stdin, stdout, and stderr plumbing.

Some process restrictions require syscalls immediately before `exec`. Performing arbitrary post-fork work from a long-running, multi-threaded Go process is unsafe. The agent therefore re-executes a short-lived mode of its own binary when it must apply rlimits, capability masks, or `noNewPrivileges`. That helper applies the constraints and then replaces itself with the workload through `execve`.

The process is marked `RUNNING` only after the OS successfully starts it. A goroutine waits for completion, converts signal deaths to the conventional `128 + signal` exit code, closes input, finishes output collection, and records `STOPPED`.

## Exec is another process, not another child kernel

`ExecProcess` creates an additional process inside the existing sandbox. It names a parent process whose root has already been validated. The request may provide a new process specification but cannot select a different root path.

```text
one Multikernel child
├── mk-agent
├── init process: application
├── exec process: diagnostic command
└── exec process: another application command
```

This is an important distinction from the current one-child-per-container test shape. An exec does not allocate CPUs, memory, a kernel, or a network endpoint. It shares the child kernel and container root already owned by the task.

The target pod design extends the same idea further: one child represents a pod sandbox, and multiple container roots and process groups live beneath one child-side agent. The current direct task path does not yet implement that complete model.

## Signals belong to the child process tree

The primary cannot call `kill(2)` on the real workload PID because that PID belongs to another kernel. The shim sends `SignalProcess` across the authenticated agent session, and `mk-agent` applies it inside the child.

For non-terminal workloads, the agent starts the executable in a new process group and signals the group. This means a TERM or KILL reaches descendants rather than only the original process leader. Wait then reports the final exit status back through the agent protocol and the shim publishes the corresponding Task v2 exit event.

The PID seen by the agent is a child-kernel PID. Any PID exposed through containerd needs an explicit compatibility representation; it must not be mistaken for something that the primary can inspect in `/proc`.

## A terminal changes the I/O model

When `terminal` is false, stdin, stdout, and stderr are independent streams. When it is true, the agent allocates a pseudo-terminal. The process becomes a session leader with the PTY slave as its controlling terminal, and output is read from the PTY master.

Terminal resize requests contain width and height and are valid only for terminal processes. An initial size can arrive before start and be applied as the PTY is created. Later `ResizeProcess` requests adjust the live terminal. Dimensions are bounded to Linux's 16-bit PTY representation.

A PTY also has no ordinary half-close for stdin. For canonical input, the agent translates `CloseProcessStdin` into the terminal's end-of-transmission behavior rather than pretending it can close only one direction of the PTY.

## Streams need offsets and bounds

The child and primary are separated by a transport that may disconnect after accepting data but before delivering a reply. A simple “retry the write” rule can duplicate stdin. The agent therefore supports offset-qualified chunks of at most 64 KiB.

Suppose the shim sends bytes `[0, 4096)` and loses the response. On reconnect it repeats the same offset, length, and bytes. The agent recognizes the digest of the most recently accepted chunk and returns the next offset without writing those bytes twice. If a local write accepted only a prefix before failing, an exact replay resumes at the first unaccepted byte.

Output uses independent offsets for stdout and stderr. Each retained stream is capped at 4 MiB. A full buffer briefly backpressures the writer, then marks explicit truncation instead of blocking the child indefinitely because its controller vanished. Process state and wait replies contain metadata rather than embedding the retained output, keeping them below the protocol frame limit.

These are container semantics implemented across two kernels:

| Container operation | Child-agent responsibility |
|---|---|
| Create | Validate bundle and record a process without running it. |
| Start | Apply identity/root/process policy and launch the executable. |
| Exec | Add a process using an already validated parent root. |
| Kill | Signal the child-side process group. |
| Attach | Continue bounded input and offset-based output. |
| Resize | Change the child PTY dimensions. |
| Wait | Preserve exact exit code and completion state. |
| Delete | Remove a stopped process's retained state. |

## Shutdown is a lifecycle operation

The agent cannot power off while processes or storage operations are still active. `Shutdown` first requires quiescence. After sending its final successful reply, the agent syncs the filesystem and invokes child poweroff.

At the pinned Multikernel revision, the child-specific machine operations turn this into a notification to the primary and park the child's CPUs. It is not a platform reset. The primary can then observe the instance returning to a loaded or stopped condition and let `mkruntimed` complete resource release.

This ordering is why process management belongs inside the child. The primary can request shutdown, but only the agent can know that child processes, buffered output, and child-side filesystem activity have reached the required state.

## What this layer proves

The agent makes a container process manageable even though its kernel, process table, root, terminal, and network interface live outside the primary Linux instance. It does so without adding SSH or a general login service to the child. The only control surface is the bounded, authenticated runtime protocol.

The remaining limitation is equally important: this is not yet arbitrary OCI conformance. The supported subset is growing, but unimplemented namespaces, cgroup resources, seccomp, mounts, hooks, and multi-container root management must remain visible failures until their semantics exist inside the child.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [`mk-agent` process manager](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/manager.go)
- [OCI execution constraints](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/oci_exec_linux.go)
- [Child root policy](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/root_policy_linux.go)
- [Turning Container Images into Multikernel Linux Roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}})
- [A containerd Runtime v2 Shim for Multikernel Linux]({{< ref "20260831_containerdRuntimeForMultikernelLinux.md" >}})

+++
title = "Docker-in-Docker on GitLab Runners Without Privileged: Trying Kata Containers"
description = "Privileged Docker-in-Docker gives every CI job root-equivalent access to the node. Kata Containers runs each pod in a lightweight VM, so elevated rights only affect a throw-away guest kernel. I tested four VMMs (Cloud Hypervisor, QEMU, Dragonball, Firecracker) running DinD without privileged, found the two capabilities it really needs, and hit a storage surprise with overlayfs."
tags = [
    "kata-containers",
    "gitlab-runner",
    "docker",
    "kubernetes",
    "security",
    "cloud-hypervisor",
    "firecracker",
    "qemu",
    "cicd",
]
date = "2026-11-05"
categories = [
    "cicd",
    "kubernetes",
    "security",
]
+++

Anyone who runs GitLab Runner on Kubernetes eventually meets this problem. A project wants `docker build` in its pipeline. The usual answer is Docker-in-Docker (`docker:dind`), and DinD wants `privileged: true`. A privileged container can load kernel modules, mount host devices and, on most setups, trivially become root on the node. Every job from every project that can reach that runner then has that power.

There are other routes: Kaniko, rootless BuildKit, Buildah, or a different builder altogether. Sometimes they work. Sometimes a project needs a real Docker daemon (`docker run`, Compose, Testcontainers) and you do not get to choose.

This post covers a different approach: **keep the jobs as they are, and change where the kernel boundary sits.** If each job pod runs inside its own small VM, "root with extra capabilities" means root in a guest kernel that nobody cares about, not on the node. That is what **Kata Containers** does.

## How the Layers Fit Together

It took me a while to get the layering straight, so here it is:

{{<mermaid>}}
graph TD
    A["Docker / containerd (or the Kubernetes CRI)<br/>asks an OCI runtime to start the container"]
    B["Kata Containers (shim + kata-agent in the guest)<br/>an OCI runtime like runc, but starts a VM"]
    C["VMM: QEMU, Cloud Hypervisor, Dragonball or Firecracker<br/>the program that creates the VM"]
    D["KVM (/dev/kvm)<br/>hardware-assisted virtualisation in the Linux kernel"]
    E["EC2 instance with nested virtualisation enabled<br/>the host is itself a cloud guest"]
    A --> B --> C --> D --> E
{{</mermaid>}}

Two things follow from this. Firecracker is not an alternative to Kata; it is one of the VMMs Kata can drive. And on a cloud provider you need **nested virtualisation**, because the node is already a VM. Not every instance type offers it. I used an `m7i-flex.2xlarge` on AWS, which I initially assumed could not do it. The EC2 API says it can, and it can. Bare metal instances are the other route and avoid the nesting cost, but I did not compare them.

## The Test Rig

One cloud instance with nested virtualisation, Docker, and Kata 4.3 installed, with a Docker runtime registered per VMM:

```json
{
  "runtimes": {
    "kata-qemu": {"runtimeType": "io.containerd.kata.v2",
                  "options": {"ConfigPath": "/etc/kata-containers/configuration-qemu.toml"}},
    "kata-clh":  {"runtimeType": "io.containerd.kata.v2",
                  "options": {"ConfigPath": "/etc/kata-containers/configuration-clh.toml"}}
  }
}
```

(and the same for Dragonball and Firecracker). Then, for each VMM, one script did the same thing:

1. Boot an Alpine container.
2. Hot-plug a 10 GB ext4 disk into the VM.
3. Run `dockerd` inside it and do a three-step image build including a 500 MB layer, once with the `overlay2` storage driver on the hot-plugged disk and once with `vfs`.
4. Everything with `Privileged=false`.

## What DinD Actually Needs

The first useful result is that **DinD does not need `privileged`** once it runs in a Kata VM. It needs two capabilities:

- `SYS_ADMIN`, for the mounts and namespace operations the inner Docker performs.
- `NET_ADMIN`. This one took a while to find. `runc` inside the guest has to bring up the loopback interface in a new network namespace, and without `NET_ADMIN` that fails with an error that does not mention capabilities. I found it with `strace`, with some help from a second pair of eyes (an LLM subagent, in my case).

When I mimicked the GitLab `services: docker:dind` pattern as a Kubernetes pod, I also needed `SYS_RESOURCE` and had to remount `/sys/fs/cgroup` and `/proc/sys` read-write before the stock `dockerd` entrypoint. The pod looks roughly like this:

```yaml
spec:
  runtimeClassName: kata-clh-runtime-rs
  containers:
  - name: build
    image: docker:cli
    env: [{name: DOCKER_HOST, value: "tcp://localhost:2375"}]
    # ... runs docker build against the service container
  - name: dind
    image: docker:dind
    env: [{name: DOCKER_TLS_CERTDIR, value: ""}]
    command: ["sh","-c"]
    args:
    - |
      mount -o remount,rw /sys/fs/cgroup && mount -o remount,rw /proc/sys
      exec dockerd-entrypoint.sh
    securityContext:
      privileged: false
      capabilities: {add: ["SYS_ADMIN","NET_ADMIN","SYS_RESOURCE"]}
    volumeMounts: [{name: docker-graph, mountPath: /var/lib/docker}]
```

A `SYS_ADMIN` container on a shared kernel is dangerous. On a Kata guest kernel it is far less so. That only holds if the pod really runs under the Kata runtime class, which is why the `runtimeClassName` line matters as much as the capabilities: a pod allowed those capabilities but scheduled with the default runtime would hold them on the node's kernel. More on that below.

## The Storage Surprise

Docker's default `overlay2` driver did not work on the container's root filesystem. Kata shares the container root into the guest over **virtiofs**, and overlayfs cannot sit on top of virtiofs.

The fix is to give the inner Docker its own block device. Kata can hot-plug an ext4 disk into the VM, and `overlay2` works fine on it. Falling back to `vfs` also works, but copies every layer in full, which is slow and large. In the Kubernetes version of the test I used an in-memory `emptyDir` for `/var/lib/docker` as a stand-in, and that is not a real design: a production setup needs a per-job data disk of known size, with a decision on which kind (EBS or instance store), which filesystem, and who cleans it up.

## Results per VMM

All four ran the same script, single runs each, with `Privileged=false` and only the two extra capabilities:

| VMM | Boot | Block hot-plug | DinD overlay2 | DinD vfs | Works through plain Docker? |
|---|---|---|---|---|---|
| Cloud Hypervisor | 6.6 s | pass | pass (15 s) | pass (12 s) | yes |
| QEMU (Kata default) | 7.9 s | pass | pass (14 s) | pass (11 s) | yes |
| Dragonball | 7.8 s | pass | pass (9 s) | pass (21 s) | yes |
| Firecracker | 7.6 s | pass | pass (7 s) | pass (8 s) | **no**, containerd only |

I want to be careful here. These are single runs (three for Firecracker's boot, all 7.6 s), and the boot time includes image and daemon overhead. The four VMMs are all within about 1.5 seconds of each other, and the overlay2-versus-vfs numbers are noisy. An earlier note of mine claimed overlay2 was faster (15 s against 24 s), and that did not reproduce when I reran it. So treat the table as a feasibility signal that all four boot and run DinD, not as a benchmark.

### Why Firecracker Needs Extra Work

Firecracker has no virtio-fs, so Kata must give the container a block-device root filesystem. Through Docker that fails with `share fs is unavailable`, even after switching Docker to containerd's devmapper snapshotter. Through containerd directly (`ctr run --snapshotter devmapper`) it works, but only after:

- creating a device-mapper thin pool (on loop files in my test),
- adding `cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1` to the guest kernel parameters,
- mounting cgroup2 by hand, since `ctr` does not add the cgroup mount that Docker would,
- fixing Kata's shipped Firecracker config, which was rejected because `reconnect_timeout_ms` must be at least `dial_timeout_ms` (I set 10 and 45000), and
- symlinking an upstream Firecracker binary, because Kata 4.x no longer ships one.

It is a fine project and a good fit if you are on containerd and want density. For a quick drop-in on Docker it is the most work.

## Do VM Escapes Happen?

Yes. A root user in a guest sits behind a stronger boundary than root in a plain container, but not an unbreakable one. Reading the published GitHub security advisories for each project turned up, among others:

- **Kata:** a guest-root to host-root issue in the Rust runtime's virtiofs handling, virtiofsd argument injection through pod annotations, annotation-driven config loading and host bind mounts, and two Dragonball guest-to-host virtio issues.
- **Cloud Hypervisor:** a virtio-block use-after-free and a QCOW backing-file host exfiltration.
- **Firecracker:** a process-memory disclosure after a failed discard, a virtio-pci out-of-bounds write, and a jailer symlink overwrite.

I did not research QEMU's record, which has a long history in device emulation, and I did not verify that the latest Kata release contains the fixes for the issues above. The pattern I noticed is that the problems cluster in shared-filesystem and virtio device emulation, and in Kata's handling of pod annotations, not in KVM itself.

## Which One I Would Pick

For a first rollout: **Kata with Cloud Hypervisor, with QEMU as the fallback.**

- Cloud Hypervisor is a small Rust VMM, actively maintained, supports virtiofs and block hot-plug, and passed everything through plain Docker. The smaller attack surface compared with QEMU was part of the reasoning.
- QEMU is Kata's default, the most battle-tested and the most feature-complete, at the cost of a larger attack surface.
- I would skip Dragonball for now. It is a single-vendor project that only runs inside Kata's Rust runtime, it had two guest-to-host advisories this year, and its standalone repository is archived with development continuing inside Kata.
- Firecracker is excellent and very active, but it does not work through Docker and needs the devmapper plumbing above. I would revisit it if the platform is containerd or CRI throughout.

Maintenance activity was part of this ranking, so I checked the release and commit history of each project through the GitHub API. All four were being committed to within the previous day or two, and Kata, Cloud Hypervisor and Firecracker release regularly, but Kata is where Dragonball lives, so that is not an independent signal.

## What Would Need to Be True Before a Rollout

The recommendation rests on pass/fail results, advisory counts and maintenance activity, from a single-node Docker setup, not a real Kubernetes cluster. In particular:

- **Admission policy has to pin the runtime.** If a job pod may hold `SYS_ADMIN` and `NET_ADMIN`, it must be forced onto the Kata runtime class. A pod with those capabilities on the normal runtime is strictly worse than before. I would do this with a policy engine that rejects the capabilities unless `runtimeClassName` is the Kata one, and put Kata nodes in a separate, tainted node group.
- **Restrict Kata pod annotations.** Several of the advisories involve annotations that change the VMM configuration, host bind mounts, or virtiofsd arguments. Job authors should not be able to set them.
- **Design the per-job data disk** for `overlay2`, including cleanup.
- **Make sure the runner subnet can pull what it needs.** My test subnet had no path to GitHub, object storage or Docker Hub, so I pushed binaries over SSH from a laptop, and some registry pulls failed on presigned storage URLs.
- **Repeat on Kubernetes** with Kata installed through `kata-deploy` or node bootstrap, real job images, and real concurrency.
- **Decide on instance types.** Nested virtualisation worked on the `m7i-flex` size I used. Newer sizes and bare metal were not compared, and I did not benchmark performance rigorously at all.

This was a feasibility experiment, not a production migration. What it showed is that "DinD without `privileged`" is achievable with ordinary tools today, as long as you accept two capabilities, a block device for the inner Docker, and an admission policy that makes sure those capabilities only ever land in a VM.

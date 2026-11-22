+++
title = "A macOS GitLab Runner Pool with Orchard and Tart VMs"
description = "macOS CI is awkward: Apple licensing ties it to Apple hardware, and EC2 Macs bill by the dedicated host. This post describes a pool where Mac hosts run Tart VMs, an Orchard controller schedules them, and a GitLab Runner custom executor in Kubernetes creates one throw-away VM per job."
tags = [
    "gitlab",
    "gitlab-runner",
    "macos",
    "orchard",
    "tart",
    "aws",
    "kubernetes",
    "cicd",
]
date = "2026-11-04"
categories = [
    "cicd",
    "devops",
]
+++

The previous post was about Windows jobs on throw-away VMs. macOS is the same wish with harder constraints:

- macOS may only legally run on Apple hardware, so you cannot just launch a VM from a cloud image on any host.
- On AWS, that hardware is an **EC2 Mac**, which is a dedicated host. You pay for the host, not for the instance, and a host cannot be released before 24 hours after it was allocated.
- A shell executor on a Mac is the easy approach, and it is how most people start. Every job then runs as the same user, in the same filesystem, with the same keychain. State leaks between jobs, and so do secrets.

The setup in this post gets one clean VM per job on a small number of Macs, without giving up much of the simplicity.

## The Pieces

{{<mermaid>}}
graph LR
    A["GitLab job (tag: macos)"] -->|"runner polls"| B["Runner pod (custom executor, in Kubernetes)"]
    B --> C["Orchard controller"]
    W["Orchard worker (launchd service on each Mac)"] -->|"dials out"| C
    C -->|"schedules VM"| W
    W --> V["Tart VM (job runs here)"]
    R["Reaper CronJob"] -->|"deletes leaked or expired VMs"| C
{{</mermaid>}}

- **[Tart](https://tart.run)** runs macOS and Linux VMs on Apple Silicon using Apple's Virtualization framework. Images are OCI artifacts, so you can store and pull them from a normal container registry.
- **[Orchard](https://github.com/cirruslabs/orchard)** is the orchestrator for Tart. A *controller* holds the desired state (which VMs should exist), and a *worker* process on each Mac creates and deletes VMs to match. Workers connect out to the controller, so the Macs do not need to be reachable from the cluster.
- **A GitLab Runner custom executor** is how GitLab is told "do not run this job yourself; call my scripts". The runner invokes a config, prepare, run and cleanup stage, and each of those scripts talks to Orchard.
- **A reaper** deletes VMs that outlived their jobs.

## Why a Custom Executor and Not the Tart Executor

Tart's maintainers publish a GitLab executor that runs on the Mac itself. That is a good fit when the runner lives with the Mac, but I wanted the runner process in Kubernetes, next to the rest of my CI, with the Macs as pure capacity. The custom executor makes that possible, because its "run this stage" step is just a command, and that command can call an HTTP API.

The runner's configuration is short:

```toml
[[runners]]
  executor = "custom"
  [runners.custom]
    config_exec  = "/usr/local/bin/orchard-executor"
    config_args  = ["config"]
    prepare_exec = "/usr/local/bin/orchard-executor"
    prepare_args = ["prepare"]      # create the Tart VM, wait for SSH
    run_exec     = "/usr/local/bin/orchard-executor"
    run_args     = ["run"]          # pipe the job's script into the VM
    cleanup_exec = "/usr/local/bin/orchard-executor"
    cleanup_args = ["cleanup"]      # delete the VM
```

My `orchard-executor` is a small program (a Python script in my case) that does four things:

1. **config** tells the runner where to build, and sets an optional driver name.
2. **prepare** creates an Orchard VM from the golden image named by the job, then waits until it accepts SSH.
3. **run** receives a script from the runner and executes it in the VM over SSH, passing back the exit code. GitLab Runner distinguishes build failures from system failures through special exit codes, and the executor must return the right one: a failed `script` is the user's problem, while a VM that never booted is a system failure and the job can be retried.
4. **cleanup** deletes the VM, regardless of how the job finished.

## Capacity: Two VMs per Mac

Apple's licence allows at most two macOS VMs at a time on one Mac, and Tart enforces this. That makes capacity easy to reason about but awkward to express, because GitLab's `concurrent` setting needs to reflect how many Macs you actually have. If `concurrent` is higher than the number of free VM slots, jobs are accepted and then fail at VM creation.

I handle this with a sidecar container that periodically asks the controller how many workers are online, multiplies by two, and rewrites `concurrent` in the runner's `config.toml`. The runner reloads that file without restarting. The sidecar starts at 1 so that a runner restart never briefly admits more jobs than there are slots.

For that reason the macOS runner is its own Helm release instead of one more `[[runners]]` block in my Linux runner. `concurrent` is global to a runner process, so the sidecar would otherwise end up throttling Linux jobs whenever Mac capacity dropped.

## Golden Images

A job needs a VM that already has Xcode, a toolchain and the usual dependencies; installing those per job would take far longer than the job. So I keep "golden" images:

- Built with **Packer** and the Tart plugin on one of the Macs, starting from a vanilla macOS image.
- Pushed to a container registry as an OCI artifact, with immutable tags.
- Pulled by the workers, which keep them cached on disk. Cloning a VM from a cached image is fast because Tart uses copy-on-write for the disk.

Tag immutability matters. A job that says "run on `xcode-26-<build-id>`" should get the same bits tomorrow, and rolling forward should mean pushing a new tag and changing the job.

## Networking and Secrets

- The **controller** is a single pod with a small volume, exposed through an internal network load balancer. It has a certificate that clients pin, and service accounts for the runner, the reaper and the workers.
- **Workers** connect out to the controller, authenticated with a token. Because the connection is outbound, the Mac subnet only needs to reach the controller, plus a registry for image pulls.
- Credentials for each component come from a secrets manager, one secret per consumer, with identities scoped so the runner cannot read the controller's admin token.

## Things I Found Worth Knowing

- **EC2 Mac billing shapes everything.** You cannot treat Mac capacity as elastic. A host costs money for at least a day once allocated, so scaling to zero is not a saving. I size for typical load and accept that Mac jobs queue when the pool is busy.
- **Root volume size.** Tart's local image and VM storage is the main consumer of disk, and macOS images are large. A root volume that looks generous at launch fills up quickly with several cached images and clones. I give the Mac a large volume from the start, since an EC2 Mac's root volume is awkward to grow later.
- **Host maintenance is still your job.** The host runs Orchard's worker, Tart, a metrics agent and some scripts, all of which need updates. I keep this as one idempotent bootstrap script with pinned, checksummed versions, so a rebuilt host converges to the same state.
- **The keychain.** A Tart VM that runs without a logged-in GUI session can still need an unlocked login keychain for tools such as code signing. This is a known sharp edge for any headless macOS CI. Think about it before you decide which jobs may use the pool, and do not put signing identities on a host shared by projects that do not trust each other.
- **Leaks happen.** A runner killed mid-job leaves a VM behind. The reaper job exists for that: every few minutes it lists VMs, finds ones whose job has finished or whose age exceeds a limit, and deletes them. Without it, two stuck VMs make a Mac useless.
- **Pod termination.** When the runner pod receives a shutdown signal, it drains running jobs. If the grace period is shorter than your longest job, Kubernetes kills the pod and the VM leaks. Set `terminationGracePeriodSeconds` to something longer than your job timeout, and mark the pod not safe to evict.

## Compared with a Shell Runner on a Mac

| | Shell executor on the Mac | Orchard pool with Tart VMs |
|---|---|---|
| Setup effort | low | considerably higher |
| Job isolation | none (same user and filesystem) | one VM per job |
| Clean state per job | only if the job cleans up | yes, by construction |
| Secrets exposure | any job can read what the user can | limited to the VM |
| Capacity | one machine, one or two jobs | scheduled across workers |
| Failure mode | a bad job can break the host | a bad job breaks its VM |

If only one team uses the Mac and trusts its own jobs, a shell runner is simpler and perfectly respectable. The pool starts paying off once several projects share the hardware, or once "the job left something behind" has cost you a debugging afternoon.

## What I Did Not Verify

I set this up and watched the pieces run, but I have no throughput numbers for it: I did not measure queue time under load, how long a VM takes to become reachable, or how the pool behaves with many workers. The first job I watched flowing through failed on its own script, which is the correct kind of failure and a useful test of the exit-code handling, but it does not tell me anything about speed. Treat the structure here as a design that worked, not a benchmark.

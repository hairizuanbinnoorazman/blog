+++
title = "A Fresh Windows VM for Every Job: GitLab Runner with the Fleeting AWS Plugin"
description = "Kubernetes can run Windows job pods, but it cannot build Windows container images. For that you want a whole Windows VM with Docker on it. This post walks through a GitLab Runner instance executor with the fleeting AWS plugin: one clean EC2 instance per job, scaled from zero through an Auto Scaling group, reached over WinRM, and thrown away afterwards."
tags = [
    "gitlab",
    "gitlab-runner",
    "windows",
    "aws",
    "ec2",
    "fleeting",
    "cicd",
    "kubernetes",
]
date = "2026-11-03"
categories = [
    "cicd",
    "devops",
    "aws",
]
+++

Most of my GitLab Runner experience is Linux containers on Kubernetes (see the [GKE as Gitlab Runner]({{< ref "20250408_gkeAsGitlabRunner.md" >}}) post). Windows jobs are a different story, and the first thing to learn is that "Windows runner" can mean two quite different things:

1. **Windows job pods on a Kubernetes cluster.** The Kubernetes executor schedules a pod onto a Windows node. It is fine for compiling and testing, and it is the cheapest option because the nodes autoscale.
2. **A whole Windows VM per job.** The instance executor asks a cloud API for a fresh machine, runs the job on it, and deletes it.

This post is about the second. The reason to want it is narrow but real: **you cannot build Windows container images from inside a Windows container on Kubernetes.** There is no Docker daemon to talk to, and the Linux tricks (Kaniko, rootless BuildKit, privileged Docker-in-Docker) have no Windows equivalent that I could rely on. If a job has to run `docker build` for a Windows image, it needs a machine that has Docker Engine installed and is allowed to use it.

A full VM brings its own problems: it is slow to boot, it costs money while it runs, and it is stateful unless you stop it from being so. The fleeting plugin is GitLab's answer to those.

## The Moving Parts

{{<mermaid>}}
graph TD
    A["GitLab job"] --> B["Runner manager (a small Linux pod)"]
    B --> C["Fleeting AWS plugin"]
    C -->|"scale ASG up by one"| D["EC2 Auto Scaling group (Windows Server + Docker)"]
    D -->|"new instance"| E["Fresh Windows instance"]
    B -->|"WinRM: run the job in PowerShell"| E
    E -->|"job done, max_use_count = 1"| F["Instance terminated"]
{{</mermaid>}}

- **The runner manager** is an ordinary `gitlab-runner` process. It does not run jobs itself and it does not need to run on Windows. I run it as a Linux pod in a cluster I already have, but it could just as well be a systemd service on a small VM.
- **Fleeting** is the library GitLab Runner uses to talk to "something that provides instances". The AWS plugin treats an **Auto Scaling group** as that something. Scaling out a job means raising the group's desired capacity by one.
- **The instance executor** takes whichever instance fleeting hands over, connects to it, and runs the job's stages with the shell you configure (PowerShell here).
- **The AMI** is where your build environment lives. I build mine with Packer: Windows Server, Docker Engine, the runner binary, and as little else as possible.

The manager's identity is what lets it touch the Auto Scaling group, so it needs AWS permissions but no Kubernetes permissions at all. That is a nice property: the pod can be given an AWS role (EKS Pod Identity in my case) scoped to one Auto Scaling group and nothing else.

## The Configuration

Here is the interesting part of `config.toml`, trimmed down:

```toml
concurrent = 2

[[runners]]
  name = "windows-vm"
  url = "https://gitlab.example.com"
  executor = "instance"
  shell = "powershell"
  builds_dir = "C:\\b"                # short path, avoids the MAX_PATH pain

  [runners.autoscaler]
    plugin = "aws:1"                  # fetched by `gitlab-runner fleeting install`
    capacity_per_instance = 1         # one job at a time per machine
    max_use_count = 1                 # then the machine is destroyed
    max_instances = 2                 # must match the ASG max size
    delete_instances_on_shutdown = true

    [runners.autoscaler.plugin_config]
      name = "windows-vm-asg"         # the Auto Scaling group

    [runners.autoscaler.connector_config]
      os = "windows"
      protocol = "winrm"
      protocol_port = 5985
      username = "Administrator"
      key_path = "/path/to/ec2-keypair.pem"
      use_static_credentials = false  # decrypt the generated password instead
      use_external_addr = false       # talk to the private address
      timeout = "20m0s"

    [[runners.autoscaler.policy]]
      idle_count = 0                  # scale to zero when quiet
      idle_time = "20m0s"
```

A few of those lines deserve explanation, because each one is a decision rather than a default.

**`max_use_count = 1` is the heart of it.** The default behaviour of the instance executor is to reuse a machine for several jobs. For Windows image builds I do not want that: a build leaves behind layers, caches, credentials in environment variables and whatever else the job touched. With one use per instance, the next job gets a pristine machine, and the Administrator password and any registry credentials that were on the box disappear with it. The cost is that every job pays the boot time.

**`capacity_per_instance = 1` and `concurrent`.** `concurrent` is the manager's global job limit. It should equal `max_instances × capacity_per_instance`, otherwise the manager will accept jobs that it has no instance for, and they sit in "preparing" until the timeout.

**`max_instances` has to match the Auto Scaling group's maximum size.** If the runner thinks it may have three instances and the group is capped at two, the third job waits for a machine that will never appear. I put both numbers in the same infrastructure-as-code repository and a comment on each pointing at the other.

**`use_static_credentials = false`.** Windows on EC2 generates a random Administrator password at first boot, encrypted with the public half of the key pair you launched with. With this setting the plugin calls `GetPasswordData` and decrypts the result with your private key, which means no password is baked into the AMI. The manager therefore needs both the private key (I mount it from a secrets store) and the `ec2:GetPasswordData` permission.

**The 20 minute `timeout`.** Windows boot plus first-boot password generation is not quick. A short timeout produces a confusing failure mode where the instance is healthy but the runner has already given up and terminated it.

## Scaling From Zero

With `idle_count = 0` there is no warm machine. The first job after a quiet period waits for the whole sequence: scale-out, instance boot, password generation, WinRM becoming reachable. I have not turned that into a number I would publish, since it depends on the AMI size, the instance type and whether the volume is a fresh one. It is minutes, not seconds, and anyone designing around this should plan for it.

If that is too slow, `idle_count = 1` keeps one warm instance ready. But then the "one job per instance" guarantee still holds: the warm instance is used once and replaced, so you are paying for one idle Windows machine to hide the boot latency of the next job. That trade is yours to make; I went with scale-to-zero because these jobs are infrequent.

## Things That Bit Me (or Nearly Did)

- **The runner image and the AMI should agree on the runner version.** The instance executor runs the runner binary on the instance too (for artifacts and cache handling). Keeping the manager's image tag and the version installed in the AMI in step avoids subtle protocol mismatches.
- **The plugin must be installed before the runner starts.** `gitlab-runner fleeting install` downloads the plugin named in `config.toml`. In a container, that goes in a pre-entrypoint script.
- **The region comes from the AWS SDK chain.** I found that the `region` key in `plugin_config` was ignored by the plugin release I used, so I set `AWS_REGION` as an environment variable on the manager instead. If your instances never appear and nothing errors, check this first.
- **Helm chart executor override.** If you deploy the manager with the official Helm chart, the chart passes its own `runners.executor` to registration, and its default is `kubernetes`. If you only set `executor = "instance"` inside the config block, the chart can silently override it, and the job fails with a message about "no image specified". Setting `runners.executor: instance` in the chart values fixes it.
- **Antivirus and short paths.** Windows Defender scanning the build directory slows down image builds noticeably, and long paths still hurt in 2026. In the AMI I create a short build directory (`C:\b`) and exclude it from scanning.
- **Scope the runner.** Jobs run as `Administrator`, often with permission to push images. Do not register this as an instance-wide runner. Register it for the specific projects that build Windows images, require a tag, and turn off "run untagged jobs".
- **Leftover instances.** If the manager dies mid-job, its instances keep running until the manager restarts and reconciles the group. Mark the manager pod as not safe to evict by the cluster autoscaler, so a routine node scale-down does not strand a Windows machine.

## Where This Sits Compared to Windows Pods

| | Windows pods on Kubernetes | Fleeting instance per job |
|---|---|---|
| Can `docker build` a Windows image | no | yes |
| Isolation between jobs | container (process isolation) | whole VM, destroyed after one job |
| Start-up time | node boot if scaled to zero, otherwise seconds | VM boot every time |
| Who owns the OS image | AWS (EKS-optimised AMI) | you (a Packer pipeline) |
| Cost model | nodes, shared by many jobs | one instance per running job |

I would still reach for the pod-based runner first for plain compile-and-test work on Windows. The VM-per-job runner is the tool for the jobs that genuinely need a Docker daemon on Windows, and it earns its keep through the clean-slate guarantee.

## What I Did Not Verify

This post is a walk through a configuration and the reasons behind each choice. I did not measure end-to-end job latency, and I did not stress the scale-out path with many simultaneous jobs. If you adopt this, test your own boot-to-WinRM time with your own AMI before you pick `timeout` and `idle_time`.

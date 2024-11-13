+++
title = "Building a code assessment tool but in Kubernetes"
description = "Building a code assessment tool but in Kubernetes"
tags = [
    "kubernetes",
    "golang",
    "docker",
]
date = "2024-11-10"
categories = [
    "kubernetes",
    "golang",
    "docker",
]
+++

- [Container based security measures](#container-based-security-measures)
  - [Smaller images for code execution platform](#smaller-images-for-code-execution-platform)
  - [Not running the container as root](#not-running-the-container-as-root)
- [Kubernetes related](#kubernetes-related)
  - [Run the deployment in different namespace](#run-the-deployment-in-different-namespace)
  - [Setting up a new Service account in kubernetes](#setting-up-a-new-service-account-in-kubernetes)
  - [Ensuring service account token is not mounted in potentially vulnerable pods](#ensuring-service-account-token-is-not-mounted-in-potentially-vulnerable-pods)
  - [Ensuring that the container is started with non-root access](#ensuring-that-the-container-is-started-with-non-root-access)
  - [Ensuring resource limits are set](#ensuring-resource-limits-are-set)
  - [Set security context](#set-security-context)
  - [Setting network policy](#setting-network-policy)
  - [Using a stricter seccomp/apparmor profile](#using-a-stricter-seccompapparmor-profile)
- [Tool related](#tool-related)
  - [Ensure limited logs sniffed](#ensure-limited-logs-sniffed)
  - [Ensure that there is a time limit of code executions](#ensure-that-there-is-a-time-limit-of-code-executions)
- [Future efforts](#future-efforts)


I had previously attempted to build a code assessment tool in docker. That involves doing the following:

- Build a web application which a user can interact with
- Have a separate worker that would start container runs that would run the encapsulated code
- Capture all of those data into some sort of database

The codebase for this can be found here: https://github.com/hairizuanbinnoorazman/Python_programming/tree/master/docker_code_executor

However, the above simple solution only works on a single node - if we were to go into a situation where we would be running hundreds/thousands of code runs at one time, then, we might not be able handle it on a single node - we would need to scale out.

Just a note here: Building a code assessment tool involves a lot more simply the code execution platform. There is also part about providing the "unit" test portion where test cases would be tested against code provided by the user of the platform. There is also the rewards system etc. However, these sections are "easier" or less interesting to talk about as compared to the code execution portion - this is where it would interesting to someone who delves in code/infrastructure - how to ensure we can adopt the best secure posture when taking in potential malicious attacks on the codebase.

With regards to the implementation - this is the rough implementation that I have in mind (a thougher approach might be better as to whatever I have in mind)

- Create a piece of controller/web applicaiton code that is able to manipulate kubernetes resources. This controller code would create jobs/pods that would then inject the third party code in and run it and store it.
- User inputted code will be loaded in via configmaps (it can store up to 1mb) - we should have a limit to what can be passed to the execution engine
- Logs are temporary stored in pods - this is fetched into the web application

The focus of this post is more of the security measures that we have done to try to harden the code execution portion in order to limit the blast radius of potential issues from user submitted code.

Refer to the implementation here: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/code-executor-k8s

## Container based security measures

### Smaller images for code execution platform

Run the application on smaller docker images where there are less utilities available. For Python - we can have the "normal" python. However, there are slim editions as well as alpine. Over here - there is also a choice for distroless but this would take a bit of research to get it working.

### Not running the container as root

We need to ensure that the user on the container is not a root user. With that, we should be able to limit the potential things that a user would be able to within the container since most thigs that would alter file states on a server would require root permissions.

## Kubernetes related

### Run the deployment in different namespace

There is not much isolation when it comes to workloads and connectivity between pods in a Kubernetes cluster. We can't use namespace to properly isolate the various pod executions - it is technically still possible for pods to converse between namespaces. Sometimes, this is a feature that people use when they might put all monitoring related pods in a namespace and the rest in a "application" namespace. One benefit for this slight segregation is the ease to delete resources.

If we know that the application resource is "hacked" and causing security issues - we can potentially go in and delete the entire namespace - all the resources tied to that namespace should be delete along side it.

### Setting up a new Service account in kubernetes

Kubernetes would create pods with a service account - if not specified, it'll go with default. We might specific things that we might add to service accounts which may not apply too well with what we're trying to build here - so it'll be better to start from a clean slate by creating a new service account. There could be a potential where default service account is already having some special kubernetes permissions - if this is so, it immediately raises the risk for the application.

For this, we would first a service account which would get certain access for our controller/web application - e.g. viewing pod logs, being able to create Kubernetes jobs/pods etc, being able to list/delete jobs and pods.

We would also need to create another service account token that will have 0 permissions to access any of the Kubernetes APIs. This would be the service account that would be used for our pods that would run the the third party submitted code.

### Ensuring service account token is not mounted in potentially vulnerable pods

Technically, the submitted code that would be running on these potentially vulnerable pods would need 0 access to kubernetes access. Also, even if one argues that it is needed - that would definitely raise the risk for running such third party code.

By ensuring that the token is not mounted, that would reduce the risk that the third party could take over and cause damage by contacting the kubernetes api.

### Ensuring that the container is started with non-root access

We can ensure this behaviour by adding a flag for this in the kubernetes manifest file. If the docker container did not set a non-root user, it will result in issues - the container will not run and in the description - it will complain of "Container Configuration Issue" of sorts - the container/pod will not be able to start running

### Ensuring resource limits are set

If limits are not set, the pods can technically expand its usage to take over the entire cluster assuming that the priority pods already take their share of resources. This is potentially bad - let's say if 1 single pod can take up resources of a entire node. If we have 5 nodes, just 5 pods (which could just be 5 code submissions) - could be cause our entire software to run to a complete stop (for a couple of seconds/minutes) - depending on the time limit of the kubernetes job.

### Set security context

Security context is pretty important field to configure to ensure that we adopt a proper security posture for our apps. Here, we can alter various settings such as:

```golang
...
SecurityContext: &core.PodSecurityContext{
  SELinuxOptions: &core.SELinuxOptions{},
  RunAsNonRoot:   boolPtr(true),
  RunAsUser:      int64Ptr(3000),
  RunAsGroup:     int64Ptr(3000),
  SeccompProfile: &core.SeccompProfile{
    Type: core.SeccompProfileTypeRuntimeDefault,
  },
  AppArmorProfile: &core.AppArmorProfile{
    Type: core.AppArmorProfileTypeRuntimeDefault,
  },
},
...
```

Over here, we can ensure uid and gids of the user running in our container - vital that we are running at id-s more than 1000; Uid and Gid less than 1000 are usually known as priviliged IDs. Over here, we can set some sort of Seccomp and Apparmor profile - these are common linux configurations that would reduce access to certain resources and system calls for the pods.

These configuraitions are on the pod level - we have more securitycontexts that we can set on the container level (within the pods)

```golang
...
SecurityContext: &core.SecurityContext{
  Capabilities: &core.Capabilities{
    Drop: []core.Capability{"all"},
  },
  Privileged:               boolPtr(false),
  ReadOnlyRootFilesystem:   boolPtr(true),
  AllowPrivilegeEscalation: boolPtr(false),
},
...
```

Over here, we can even ensure that we drop linux capabilities, set read only filesystems and ensure that a normal user wouldn't be able to do "sudo" to run priviliged commands within the container.

### Setting network policy

What we're trying to do here is a "code assessment" tool - this would mean that there is very little reason to try to create environment that allows for internet access. That would mean that it would make sense to ensure that the pod has 0 ingress and egress capabilities.

One reason for trying to limit this is to ensure that submitter would not be able to run scripts that would call out to some external endpoint that can pull in a malicious binary. If we block internet access both ways, we can ensure that this form of attack is somewhat blocked. 

Reference: https://kubernetes.io/docs/concepts/services-networking/network-policies/

### Using a stricter seccomp/apparmor profile

Right now, there isn't a convenient way to distribute apparmor or seccomp profiles across the various nodes in the cluster. If we were to do it without any tool, we would need to go to every ndoe and add the profile in a specific folder for every single node (technically, this is possible with provision/infrastruture templating tools).

However, this is not covered in the above implementation - this should probably be covered in its own blog post to cover it in greater detail of what this controller is doing etc.

Reference: https://github.com/kubernetes-sigs/security-profiles-operator

## Tool related

### Ensure limited logs sniffed

We definitely need to limit the amount of logs that will be collected by the web application. While writing this controller/applicationinitially - i did not the log limit. I then write a small program that does a loop in a loop in a loop:

```python
for a in range(1, 1000):
  for b in range(1, 1000):
    for c in range(1, 1000):
      print(f"{a} - {b} - {c}")
```

This code immediately can cause issues:
- The code takes a long time to run (but we can control the time limit of the code executions)
- Each iteration writes a line - however, in this case, we would be writing 1000,000,000 lines of logs. Where are these logs going to be stored and how will it be shown to the user?

While showing the logs to the website, it immediately crashed the chrome tab. - definitely an issue

### Ensure that there is a time limit of code executions

We can't wait for code executions to complete or fail - a time limit needs to be set. It is definitely possible for a third party submitter to just submit some code that runs forever - and this would simply mean that the pods would be created and be left to exist for a very very long time in the cluster. Even if try to allow this as well as ensure that each pod only takes a small amount of resource; it would eventually fill up the Kubernetes cluster and cause further problems down the line.

## Future efforts

The implementation mentioned here: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Apps/code-executor-k8s is a initial implementation (as of November 2024) - and is not the hardened approach to this problem. It is more of the minimal easy to do security measures that can be done to try to achieve this. However, there is more that can be done:

- Run the following scan to ensure compliance: https://github.com/kubescape/kubescape
- Run micro-vms (e.g. kata containers/gvisor). However, this would mean that we need to get nodes that support provisioning of vms. In cloud providers, we would need to get virtual machines that support "vm in vm" situation. However, doing this approach would definitely lead to a massive slowdown approach of executing code.
- Run sqlmap scans? This is to ensure that the application accepting third party submissions 
- Rate limiting (Current version has no concept of rate limiting)
- User authentication (Current version is just a prototype and doesn't do auth/authorizations)
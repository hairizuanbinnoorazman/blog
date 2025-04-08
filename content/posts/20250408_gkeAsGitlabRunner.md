+++
title = "GKE as Gitlab Runner"
description = "GKE as Gitlab Runner"
tags = [
    "google-cloud",
    "kubernetes",
    "cicd",
    "devops",
]
date = "2025-04-08"
categories = [
    "google-cloud",
    "kubernetes",
    "cicd",
    "devops",
]
+++

Part of my job involves me dealing with Gitlab on a daily basis. Gitlab is a complicated beast to handle and it took a while to get around the various features that the product offers. One of the offerings available is one where we can set an entire Kubernetes cluster as a potential target where we can then create containers and run tests on said cluster.

Some of the benefits of doing this is:

- Instead of having separate machines where workloads may not be efficiently used, we instead centralize it. Multiple teams can share the same resource and now, there is only a single machine/setup that the Devops team can look at and manage

Some of the cons:

- Complicated setup. It involves setting up a Kubernetes Cluster and managing it (including doing software updates etc). However, a potential point here would be that we don't really need to "maintain" the cluster 100% of the time. Essentially, we can explore blue-green way of deployment where we can setup a new updated cluster and bring down the old one accordingly (require research for this)

This blog post would cover on setting up a gitlab server and a Kubernetes cluster runner setup - we would then see how it behaves with this. Do note that the cluster here is extremely not secure - we skip steps of doing domain registration etc or even adding ssl certs - its always good to follow such best practises wherever possible.

## Install Gitlab Server on Google Compute Instance

We will follow the steps mentioned here. Do note that Gitlab is a pretty resource hungry product - we would need to deploy a pretty powerful machine here (the below experiment worked decently with 4 CPUs 16 GB ram)

Reference Link:  
https://about.gitlab.com/install/#debian

Run the following command to install Gitlab Community Edition

```bash
sudo apt-get update
sudo apt-get install -y curl openssh-server ca-certificates perl
sudo apt-get install -y postfix
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
sudo EXTERNAL_URL="http://<IP Address>" apt-get install gitlab-ce
cat /etc/gitlab/initial_root_password
```

Add a whole bunch of configuration to disable in order to allow for "testing version" of gitlab

https://docs.gitlab.com/omnibus/settings/nginx.html

Some of the configurations to rollback in order to be able test locally. We will edit the file: `/etc/gitlab/gitlab.rb` in order to do have a less secure deployment for easier testing.

```bash
nginx['enable'] = true
nginx['client_max_body_size'] = '250m'
nginx['redirect_http_to_https'] = false
nginx['listen_addresses'] = ['*', '[::]']

external_url = 'xxx'
```

Do note that for external url - that'll be the public ip address of the instance.

Once we have configure the `gitlab.rb` file, we can then run the following command to have it reconfigure the various files in the server.

```bash
sudo gitlab-ctl reconfigure
```

## Connecting a kubernetes cluster

First step would be to create a Google Kubernetes Engine Cluster.

Next, we would then install helm on said GKE  
https://helm.sh/docs/intro/install/  

```bash
# Install helm locally
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Adds gitlab helm repo
helm repo add gitlab https://charts.gitlab.io
```

Create the `values.yaml` file. We need to replace the images - seems like we can't reach/access them easily. We also need the runner token: https://docs.gitlab.com/ci/runners/runners_scope/#create-an-instance-runner-with-a-runner-authentication-token

```yaml
image:
  registry: ''
  image: gitlab/gitlab-runner
gitlabUrl: http://<IP Address>
runnerToken: glrt-t1_xxxxxxx
rbac:
  create: true
serviceAccount:
  create: true
runners:
  # https://docs.gitlab.com/runner/configuration/advanced-configuration.html
  config: |
    [[runners]]
      [runners.kubernetes]
        helper_image = "gitlab/gitlab-runner-helper:alpine3.21-x86_64-ef636327"
        namespace = "{{.Release.Namespace}}"
        image = "alpine"

```

For experimentation purposes, we would add it to a new different namespace `zzz`. To create a new namespace in kubernetes, make sure we access the `kubectl` command and then execute the command:

```bash
kubectl create namespace zzz
```

Once we have the `values.yaml` file and the namespace, we can run the following command to install the helm chart

```bash
helm upgrade --install --namespace zzz gitlab-runner -f values.yaml gitlab/gitlab-runner
```

To test our setup, we can then create a simple empty repo and then add the following to the `.gitlab-ci.yml` file. Once the code is pushed, it should immediately trigger a run

```yaml
build-job:
  image: nginx:latest
  stage: build
  script:
    - echo "Hello, xxx"
  tags:
    - containers
```

## Troubleshooting

One important thing to note is the pod can take up to 90s to be "ready". However, it registers with the gitlab pretty quickly

Here are some of the issues I faced while doing the above setup

```bash
Preparing environment
00:00
ERROR: Error cleaning up secrets: resource name may not be empty
ERROR: Job failed (system failure): prepare environment: setting up credentials: secrets is forbidden: User "system:serviceaccount:zzz:default" cannot create resource "secrets" in API group "" in the namespace "zzz". Check https://docs.gitlab.com/runner/shells/index.html#shell-profile-loading for more information
```

This issue is because the Gitlab runner helm installation did not automatically include rbac rules. But most kubernetes clusters now enable RBAC rules by default (secure by default). It's too much work to actually disable - so its easier to allow the helm chart to create it (and they took the shortcut way to do so by enable '*' access for all the critical Kubernetes apis such as pod creation/secret creation etc)

```bash
WARNING: Event retrieved from the cluster: Failed to pull image "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v17.10.1": failed to pull and unpack image "registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-v17.10.1": failed to copy: httpReadSeeker: failed open: failed to do request:
```

This issue came up because apparently, the default helper image is not reachable/accessible. We need to overwrite it - see the `values.yaml` under the `config` key

```bash
WARNING: Event retrieved from the cluster: Unable to retrieve some image pull secrets (runner-t1sflzcw-project-1-concurrent-0-ixn6wo8t); attempting to pull the image may not succeed.
WARNING: Event retrieved from the cluster: Failed to pull image "gitlab/gitlab-runner-helper:latest": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/gitlab/gitlab-runner-helper:latest": failed to resolve reference "docker.io/gitlab/gitlab-runner-helper:latest": docker.io/gitlab/gitlab-runner-helper:latest: not found
WARNING: Event retrieved from the cluster: Error: ErrImagePull
WARNING: Event retrieved from the cluster: Error: ImagePullBackOff
```

Similar to above but just a FYI that the `latest` tag doesn't exist for the gitlab-runner-helper image. We need to specify an exact image in order to have it work.
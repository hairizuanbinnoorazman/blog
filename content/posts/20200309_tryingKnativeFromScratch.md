+++
title = "Trying Knative from scratch"
description = "Using Knative from scratch"
tags = [
    "google-cloud",
]
date = "2020-03-09"
categories = [
    "google-cloud",
]
+++

**This blog post is still being updated**

Various cloud providers started offering serverless containers as a service. This is a service where developers can just create a container and then, pass that container over to the cloud provider and then forget about it. The cloud provider would deal with the scaling, provisioning of resources to host the applications, deployment, monitoring etc.

Some of such services are:

- Google Cloud Run
- Pivotal Function Service

Underneath these services lie various frameworks, some examples would be:

- Knative
- Openfaas

These frameworks operate on top of various other tools, orchestrated together to work harmoniously (albeit, maybe a little fragile?) to provide the simplified developer experience of just focusing on delivering their application in a docker container and let the platform handle the rest.

In the case of this post, we would cover the way to deploy knative, which powers the Google Cloud Run product.

## Deploying a Kubernetes Cluster

We would want to try to deploy a Kubernetes cluster. There are various ways to do so these days:

- kubespray
- kops
- kubeadm
- Managed Kubernetes Clusters on Cloud Providers
  - GKE on Google Cloud Platform
  - AKS on Azure
  - EKS on AWS (Managed Kubernetes platform)
  - Digital Ocean Managed Kubernetes Platform

Naturally, the easiest are the ones that are provided by Cloud Providers.

In our case, let's say if we are to do it manually via kubeadm, we would first need to create 3 VMs on Google Cloud. We would then need to run the following commannds in sequence in order to get the kubernetes cluster up and running. The first part is to install the container runtime on the machines.

In order to support nodeport in the kubernetes cluster we would be creating, we would need to add a network tag to all of them. Network Tag: "nodeports".

Also, since we are going to have the gce instance to contact the various google cloud platform to create the relevant volumes/load balancers, it is important that we state that the instance should have more permissions. For more granular control, you can follow the blog post stated above, but for simplicity sake, we would just set the instance to have full api access.

Here are some additional references when trying to get a kubernetes cluster up in gce vms.

References: https://medium.com/@stephane.beuret/kubeadm-on-gce-14df27d67bf5

```bash
# Install Docker
# Reference: https://docs.docker.com/install/linux/docker-ce/debian/
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
```

The next step is to install kubeadm which would install the tool that would assist to install kubernetes binaries on the machines.

```bash
# Installing kubeadm
# Reference: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
sudo apt-get install -y iptables arptables ebtables
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy

sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Save this in the /etc/kubernetes/cloud-config on all 3 nodes

```text
[Global]
project-id = "XXX"
node-tags = nodeports
node-instance-prefix = "test"
multizone = true
```

Save this as gce.yaml on the machine that is designated as the master node.

Note: We need to create google compute engine instance group: test-group-manager => load balancer can only be attached to instance groups

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
bootstrapTokens:
  - groups:
      - system:bootstrappers:kubeadm:default-node-token
    token: 123456.test123456789012
    ttl: 24h0m0s
    usages:
      - signing
      - authentication
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "gce"
    cloud-config: "/etc/kubernetes/cloud-config"
  taints: []
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  podSubnet: 192.168.0.0/16
apiServer:
  certSANs:
    - X.X.X.X # External IP
    - X.X.X.X # Internal IP
    - 10.96.0.1 # No idea - can try removing this
  extraArgs:
    cloud-provider: "gce"
    cloud-config: "/etc/kubernetes/cloud-config"
  extraVolumes:
    - name: cloud
      hostPath: "/etc/kubernetes/cloud-config"
      mountPath: "/etc/kubernetes/cloud-config"
controllerManager:
  extraArgs:
    cloud-provider: "gce"
    cloud-config: "/etc/kubernetes/cloud-config"
  extraVolumes:
    - name: cloud
      hostPath: "/etc/kubernetes/cloud-config"
      mountPath: "/etc/kubernetes/cloud-config"
```

With that, we can now begin to try to initialize kubeadm to begin starting the required kubernetes services.

```bash
sudo su
kubeadm init --config gce.yaml
```

The next step would be to install the networking overlay as well as to allow you to schedule pods on the master node.

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/master-
```

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "X.X.X.X:6443" # Private ip address
    token: 123456.test123456789012
    unsafeSkipCAVerification: true
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "gce"
  taints: []
```

```bash
kubeadm join --config join.yaml
```

```bash
kubectl run nginx --image=nginx --port=80
kubectl expose deployment nginx --type=LoadBalancer --name=nginx-service --port=80 --target-port=80
```

```bash
# Hacks:
# If you want to do a single node kubernetes "cluster" but still want load balancer
# Reference: https://github.com/kubernetes/kubernetes/issues/65618
# Remove the following line:
# node-role.kubernetes.io/master
# To force it to say that this node can be used as a backend for a load balancer.
```

## Installing Istio

```bash

```

```bash

```

## Installing Knative

And now, we finally come to knative, the final piece of the technology puzzle in order to unlock deployment serverless like workloads into our Kubernetes cluster.

Knative is reliant

```bash

```

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

In order to support nodeport in the kubernetes cluster we would be creating, we would need to add a network tag to all of them. Network Tag: "nodeports". Ports 30000-32767 needs to be made available for these.

At the same time, in order to provide external kubectl access from outside world to the cluster, we would need to create another network tag that opens the firewalls to port 6443 for these instances. We have the network tags be "kube-api" for this.

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
# For debian 9 - can skip?
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

# Not necessary for debian machines
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Run the following command to prep it for flannel CNI use
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

Save this in the /etc/kubernetes/cloud-config on all 3 nodes

```text
[Global]
project-id = "XXXX"
node-tags = nodeports
node-instance-prefix = "test"
multizone = true
```

From this point onwards, we would need save the files/run commands in particular machines. Let's have the machines be called either master nodes or worker nodes.

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
  podSubnet: 10.244.0.0/16
apiServer:
  certSANs:
    - X.X.X.X # Public IP Address of VM machine that is meant to be master
    - X.X.X.X # Private IP Addresss of VM machine that is meant to be master
    - 10.96.0.1
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
# Run it on master node
sudo su
kubeadm init --config gce.yaml
```

Add this to your worker node

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    apiServerEndpoint: "X.X.X.X:6443"
    token: 123456.test123456789012
    unsafeSkipCAVerification: true
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "gce"
  taints: []
```

And then run this command on each of your worker node in order to form the full cluster

```bash
kubeadm join --config join.yaml
```

The next step would be to install the networking overlay as well as to allow you to schedule pods on the master node.

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
# This is not necessary in our case as we already remove taints from our deployment
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Let's try to deploy some apps to see if it works. This step is the most vital before proceeding on. If any of these "tests" fail, you cannot deploy istio nor knative.

```bash
# Deploy a service and ensure it can connect to internet
kubectl run --image=nginx --port=80 nginx
kubectl exec -it nginx /bin/bash
# Within container
apt update # If this fails -> your networking requires a fixin'

# Deploy a service with a load balancer
kubectl run --image=nginx --port=80 nginx
kubectl expose deployment nginx --type=LoadBalancer --name=nginx-service --port=80 --target-port=80

# Editing the load balancer to make the connections external
annotations:
    networking.gke.io/load-balancer-type: External
# https://github.com/kubernetes/legacy-cloud-providers/blob/8dfcb684d422483a0bc1ea84008859a5f7950b3a/gce/gce_loadbalancer.go#L218
# https://github.com/kubernetes/legacy-cloud-providers/blob/66bed784d14dbdc0d4a9ae192b1e137e9e295f30/gce/gce_annotations.go#L79

# Deploy a service with nodeport expose
kubectl run nginx-nodesport --image=nginx --port=80
kubectl expose deployment nginx-nodesport --type=NodePort --name=nginx-nodeport --port=80
```

### If you're attempting to link load balancer to single node

```bash
# Hacks:
# If you want to do a single node kubernetes "cluster" but still want load balancer
# Reference: https://github.com/kubernetes/kubernetes/issues/65618
# Remove the following line:
# node-role.kubernetes.io/master
# To force it to say that this node can be used as a backend for a load balancer.
```

### Important Note: Calico don't seem to work well here

https://github.com/kubernetes/kubeadm/issues/1776

Calico doesn't seem to work well here. So don't use calico. Try using flannel instead

```bash
# Don't use calico here
kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
```

### Another important note: Old CNI config haunt current attempts to start cluster

In the case of trying to debug why coredns not starting

https://github.com/coredns/deployment/issues/87

Use some of the debugging steps here to find out why.

One possible reason is leftover effects of previous CNI left behind. We would need to remove it

```bash
# Cleanup network plugins
rm -r /etc/cni/net.d/
```

## Installing Istio

```bash
cd /usr/local/bin
curl -L https://istio.io/downloadIstio | sh -
export PATH="$PATH:/usr/local/bin/istio-1.5.0/bin"
istioctl verify-install
istioctl manifest apply --set profile=demo --set addonComponents.grafana.enabled=true
```

## Installing Knative

And now, we finally come to knative, the final piece of the technology puzzle in order to unlock deployment serverless like workloads into our Kubernetes cluster.

Knative is reliant on the previous set of technologies deployed above (although you have choices to switch out your "service mesh" layer).

Refer to the following document for full instructions and details: https://knative.dev/docs/install/any-kubernetes-cluster/

```bash
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-crds.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-core.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.13.0/serving-istio.yaml
kubectl --namespace istio-system get service istio-ingressgateway

# Refer to the section on real dns - since xip.io cannot be used here -> load balancer appears to be internal load balancer

# Watch the pods for deployment
kubectl get pods --namespace knative-serving
```

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

So to summarize, we need to to do following manual steps on google cloud console gui:

- Create nodeports firewall rule
- Create kube-api firewall rule
- Create VM with firewall rule configured AND have all access to Google APIs

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

# Run the following command to prep it for weavenet CNI use
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
# Configuration: https://godoc.org/k8s.io/kubernetes/cmd/kubeadm/app/apis/kubeadm/v1beta2
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
# networking:
#   podSubnet: "10.32.0.0/12"
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
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Flannel network (not fully tested)
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
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

## Getting private gcr.io docker images into the cluster

Not all apps that we need to run on the cluster would be available publicly. Let's say if we have our private apps in our own private registry. How are we able to pull them into the cluster.

General rule of thumb for this issue is that if you can pull the images into the machine; you can deploy that into the kubernetes cluster

```bash
gcloud auth configure-docker
docker pull gcr.io/<PROJECT ID>/<IMAGE NAME>

# Run image in kubernetes cluster
kubectl run private-image --image=gcr.io/<PROJECT ID>/<IMAGE NAME>
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

Next step in the march to get knative working on the cluster would be to install some sort of service mesh (component to control the traffic of the application)

We'll first go for a basic setup (with no sidecar injection before trying out the full blown istio components)

```bash
# https://knative.dev/v0.12-docs/install/installing-istio/
export ISTIO_VERSION=1.3.6
curl -L https://git.io/getLatestIstio | sh -
cd istio-${ISTIO_VERSION}
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
  labels:
    istio-injection: disabled
EOF
```

The next step is to actually install helm since helm is needed to install the istio component

```bash
wget https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz
tar -xvzf helm-v3.1.2-linux-amd64.tar.gz
cd linux-amd64
chmod +x helm
mv helm /usr/local/bin/helm
```

The final step is to do finally apply the istio component and get all the istio components working

```bash
# A lighter template, with just pilot/gateway.
# Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
helm template --namespace=istio-system \
  --set prometheus.enabled=false \
  --set mixer.enabled=false \
  --set mixer.policy.enabled=false \
  --set mixer.telemetry.enabled=false \
  `# Pilot doesn't need a sidecar.` \
  --set pilot.sidecar=false \
  --set pilot.resources.requests.memory=128Mi \
  `# Disable galley (and things requiring galley).` \
  --set galley.enabled=false \
  --set global.useMCP=false \
  `# Disable security / policy.` \
  --set security.enabled=false \
  --set global.disablePolicyChecks=true \
  `# Disable sidecar injection.` \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set gateways.istio-ingressgateway.autoscaleMin=1 \
  --set gateways.istio-ingressgateway.autoscaleMax=2 \
  `# Set pilot trace sampling to 100%` \
  --set pilot.traceSampling=100 \
  --set global.mtls.auto=false \
  install/kubernetes/helm/istio \
  > ./istio-lean.yaml

kubectl apply -f istio-lean.yaml
```

## Installing Knative

And now, we finally come to knative, the final piece of the technology puzzle in order to unlock deployment serverless like workloads into our Kubernetes cluster.

We would be experimenting with several unique features of Knative:

- Scale to zero on 0 traffic
- Traffic splitting between multiple versions of an application
- Accessing tag versions of an application
- Watch auto-scaled services as it handles load

Knative is reliant on the previous set of technologies deployed above (although you have choices to switch out your "service mesh" layer).

Refer to the following document for full instructions and details: https://knative.dev/v0.12-docs/install/knative-with-any-k8s/

```bash
# Installing the knative CRDs
kubectl apply --selector knative.dev/crd-install=true \
--filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
--filename https://github.com/knative/serving/releases/download/v0.12.0/monitoring.yaml
#--filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml \


# Getting the knative components to run
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.12.0/serving.yaml \
--filename https://github.com/knative/serving/releases/download/v0.12.0/monitoring.yaml
#--filename https://github.com/knative/eventing/releases/download/v0.12.0/eventing.yaml \


kubectl get pods --namespace knative-serving
kubectl get pods --namespace knative-eventing
#kubectl get pods --namespace knative-monitoring
```

Alter the DNS records for the config map in order to start knative serving to the right ip address. Reference: https://knative.dev/v0.12-docs/install/installing-istio/

```bash
# Edit the following file
kubectl edit cm config-domain --namespace knative-serving
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-domain
  namespace: knative-serving
data:
  # xip.io is a "magic" DNS provider, which resolves all DNS lookups for:
  # *.{ip}.xip.io to {ip}. => We would need to use the istio-ingressgateway ip address
  X.X.X.X.xip.io: ""
```

We can try to deploy an nginx container but we realize that it won't work. Issues for that is added here.

```yaml
# https://github.com/knative/serving/issues/3809
# https://github.com/knative/serving/issues/2142
# https://medium.com/@frederic.lavigne/moving-a-cloud-foundry-app-to-knative-on-ibm-cloud-c0787e3611f1
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containers:
        - image: nginx
```

Instead, we can try with the yaml below.

```yaml
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go-1 # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go # The URL to the image of the app
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Go Sample v1"
```

After multiple versions - we can try alter the above file to the following -> this would allow us to have traffic splitting between various versions of an application

```yaml
# With reference from the following page: https://github.com/knative/docs/blob/master/docs/serving/samples/traffic-splitting/split_sample.yaml
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go-1 # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containerConcurrency: 1
      containers:
        - image: gcr.io/knative-samples/helloworld-go # The URL to the image of the app
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Go Sample v2"
  traffic:
    - tag: current
      revisionName: helloworld-go-1-xxxxx
      percent: 50
    - tag: first
      revisionName: helloworld-go-1-xxxxx
      percent: 50
    - tag: latest
      latestRevision: true
      percent: 0
```

### Testing out scaling

Refer to the following url: https://github.com/sgotti/knative-docs/tree/master/serving/samples/helloworld-go

We would adjust the helloworld app by making it such that application would take a longer time to respond to requests. We would be adding code such that it would do a sleep before responding back to the request -> somewhat simulating the event where web requests are taking a while to complete.

```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func handler(w http.ResponseWriter, r *http.Request) {
	log.Print("Hello world received a request.")
	defer log.Print("End hello world request")
	target := os.Getenv("TARGET")
	if target == "" {
		target = "NOT SPECIFIED"
	}
	waitTimeEnv := os.Getenv("WAIT_TIME")
	waitTime, _ := strconv.Atoi(waitTimeEnv)
	log.Printf("Sleeping for %v", waitTime)
	time.Sleep(time.Duration(waitTime) * time.Second)
	fmt.Fprintf(w, "Hello World: %s!\n", target)
}

func main() {
	log.Print("Hello world sample started.")

	http.HandleFunc("/", handler)
	http.ListenAndServe(":8080", nil)
}

```

With the following app, we can provide it a `WAIT_TIME` environment variable that would allow us to control the amount of time for the app to return a response to the request. For completeness sake, the Dockerfile is also added here as well.

```Dockerfile
FROM golang
ADD . /go/src/github.com/knative/docs/helloworld
RUN go install github.com/knative/docs/helloworld
ENTRYPOINT /go/bin/helloworld
EXPOSE 8080
```

We can proceed to build and push this a registry

```bash
docker build -t gcr.io/XXXX/helloworld:v1
docker push gcr.io/XXXX/helloworld:v1
```

We can then alter the knative configuration for this app in order to try scaling examples

```yaml
apiVersion: serving.knative.dev/v1 # Current version of Knative
kind: Service
metadata:
  name: helloworld-go-1 # The name of the app
  namespace: default # The namespace the app will use
spec:
  template:
    spec:
      containerConcurrency: 1 # Take note of this
      containers:
        - image: gcr.io/XXXX/helloworld
          env:
            - name: TARGET # The environment variable printed out by the sample app
              value: "Go Sample v2"
            - name: WAIT_TIME
              value: "2"
```

This would create a pod that would respond to a web request in 2s. If one is loading that service with 3 requests/second, 1 pod won't be sufficient to handle the requests, so knative autoscales the service out to handle the traffic.

For a more proper load testing tools, one can consider other tools like [vegeta](https://github.com/tsenart/vegeta) and [apache benchmark](https://httpd.apache.org/docs/2.4/programs/ab.html)

Note: To view extreme cases where 20 requests/s come in at the same time etc, do ensure that the cluster has enough resources to handle it. If there is insufficient resources, the cluster may begin to starve critical components in order to fulfil and complete web requests.

### Logging and Monitoring in Knative

If you deploy the monitoring stack in knative, you would get both the grafana + prometheus as well as the ELK stack as well which would serve as the logging and monitoring platforms.

For the grafana dashboard, we can immediately view it by looking at services available, and then going to nodeport where the dashboard is exposed.

To get to view the kibana ui, we would need to first edit all the nodes in the cluster to enable the fluentd daemon to run on it

```bash
# Add this line under the labels
beta.kubernetes.io/fluentd-ds-ready: "true"

# Verify the nodes that has this daemonset running
kubectl get nodes --selector beta.kubernetes.io/fluentd-ds-ready=true
kubectl get daemonset fluentd-ds --namespace knative-monitoring
```

Then, get local kubectl access to the cluster.

Run the following command:

```bash
kubectl proxy

# Then, go to the following link:
http://localhost:8001/api/v1/namespaces/knative-monitoring/services/kibana-logging/proxy/app/kibana
```

Tracing is also available via this link: http://localhost:8001/api/v1/namespaces/istio-system/services/zipkin:9411/proxy/zipkin/ -> make sure you run the kubectl proxy command first before accessing this.

## Additional debugging steps

While creating this article, I experimented quite a bit. Tried installing latest istio and knative (didn't work). Tried using Calico CNI (partly because that is the first CNI in the list on kubeadm page - this didn't work as well)

If you're here for the guide to successfully deploy knative on Google Compute Engine nodes - you don't need to read this portion. But if you wish to explore and debug further issues, you can continue reading.

### Attempting to deploy latest knative on latest istio (as of March 2020)

Istio was at 1.5 and knative at 0.13

Issue - custom domain job always in error. It was complaining that it was unable to reach the kubernetes api server.

Initial investigation assumed that this was because of CNI issues

```
https://github.com/kubernetes-sigs/metrics-server/issues/375
https://github.com/kubernetes/kubeadm/issues/1817

# The url being accessed
https://10.96.0.1:443/api/v1/namespaces/knative-serving/configmaps/config-domain
```

However, it is then noted that you can't exactly ping the ip address of the kubernetes apiserver. Iptables rules have been setup to ignore such traffic. Also, if you run busybox and then run `nslookup kubernetes` -> the pods is able to resolve the addresses, but it is unable to reach it.

After further researching, found out that the way to access such data is via the following:

```bash
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
curl -H "Authorization: Bearer $TOKEN" --insecure https://10.96.0.1/api/v1/namespaces/knative-serving/configmaps/config-domain
```

However, it is vital that the pod has the capability to query the apiserver regarding that. If you had not supplied the tokens, you are deemed as an anonymous user -> which automatically prevents you from pulling any data out of the pod.

Within the pod, it is possible to attach a service account to the pod (knative-serving already creating `controller` and `default` service accounts). The service accounts will somewhat indicate what api data can be pulled from apiserver.

In order to debug further, tried to create the following yaml files that would attempt to provide the required roles and capabiltiies to the service account so that it can pull the required data but still having issues with that.

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: knative-role
  namespace: knative-serving
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - secrets
      - configmaps
    verbs:
      - get
      - watch
      - list
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: knative-role-binding
  namespace: knative-serving
roleRef:
  kind: Role
  name: knative-role
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: controller
    namespace: knative-serving
```

The conclusion from this is that further investigation need to be done to find out why that specific component is not fetching the config map as expected.

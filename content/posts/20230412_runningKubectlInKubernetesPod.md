+++
title = "Running kubectl in a Kubernetes Pod"
description = "Running kubectl in a Kubernetes Pod; roles, clusterroles, rolebinding and clusterrolebinding configuration needed"
tags = [
    "google-cloud",
    "kubernetes",
]
date = "2023-04-12"
categories = [
    "google-cloud",
    "kubernetes",
]
+++

I have a little side project at work where it somewhat requires me to allow a pod within a kubernetes cluster to access and query and manipulate resources in a Kubernetes cluster. This would provide some sort of special development environment within pod with the required capability to update the cluster. In order to do this, we need to add a bunch of roles, clusterroles and its bindings (essentially the RBAC system in Kubernetes) to allow the pod to access said resources

Important thing to note here is to NEVER RUN THIS ON PRODUCTION ENVIRONMENTS. The following configurations provides unnecessary power into a single pod - if there was ever someone who managed to get into that specific pod, the person would be able to wreck on the cluster. But then again, if someone already has capability to access and enter a pod in a cluster, you would have other more critical security concerns to address.

First, let's set up a simple pod to how we would be unable to utilize the `kubectl` command effectively by default. Let's first create some sort of Kubernetes cluster - in my case, I created mine in Google Kubernetes Engine. Once, we have the cluster up and running, we can create a `deployment` resource which would create our `pod`. This can be done via the following command.


```bash
kubectl create deployment lol --image=nginx
```

Let's then query the pods being created and then enter the bash of said pod.

```bash
kubectl get pods
kubectl exec -it <pod name> -- /bin/bash
```

The next step is to get the `kubectl` command into the container. The nginx image we use is convenient as it provides a running container with a command that allows it to run as a server. Other images such as debian and ubuntu would require us to provide some sort of "sleep" command to make it run for a longer period. For reference to install the `kubectl` command, we can refer to the following website:

https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

For our case, we can simply run the following commands within the pod.

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
mv kubectl /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
kubectl
```

If we tried to list the pods with the following command:

```bash
kubectl get pods
```

We'll get the following output.

```bash
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" in API group "" in the namespace "default"
```

This is to be expected. By default, most pods don't need access to Kubernetes resources. E.g An application that is serving some sort of business logic shouldn't need to query any Kubernetes resources etc.

Now, let's remedy the situation to solve for my need to be able to access all the Kubernetes resources from a pod. First, let's create a `ServiceAccount` resource. This would ensure that most pods wouldn't get the special access to the Kubernetes API. If a pod is created without pointing to a specific `ServiceAccount`, it would default to the `default` service account which should still be pretty locked on at this stage. We're giving the ServiceAccount the name `god` since essentially, that's what it can kind of do - read and manipulating anything on the cluster literally. However, feel free the alter the example accordingly.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: god
  namespace: default
```

The next step is to provide the role and rolebindings that we would give. The Role and Rolebindings would give us permissions to view resources in the `default` namespace. We give it capability to view most resources within said namespace (although we might still need to add on to the role if we need access to other types of resources)

```yaml
apiVersion: v1
kind: Role
metadata:
  name: god-role
  namespace: default
rules:
- apiGroups:
  - ""
  resources:
  - '*'
  verbs:
  - '*'
```

The next yaml is to bind above roles to a serviceaccount which in our case, would be the `god` ServiceAccount.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: god-role-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: god-role
subjects:
- kind: ServiceAccount
  name: god
  namespace: default
```

Just having the above `Role` and `RoleBinding` isn't enough. If we only have that, we can run commands such as this: `kubectl get pods --all-namespaces`. That is a "cluster" level operation and we need the appropriate ClusterRole to be provided to the pod to be able to do give said pod the access needed.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: god-role
rules:
- apiGroups:
  - ""
  resources:
  - '*'
  verbs:
  - '*'
```

This would be the binding configuration for the above `ClusterRole`


```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: god-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: god-role
subjects:
- kind: ServiceAccount
  name: god
  namespace: default
```

Now that we have the RBAC permissions all setup, we can finally alter our pod to provide it the permission access it needs to do the magic. To do so, we'll need to edit our `deployment` resource.


```bash
kubectl edit deployment lol
```

The only 2 lines we need to add is the `serviceAccount` and `serviceAccountName`. Do note that the following yaml below is heavily abbreviated - it's only trying to demonstrate where to add the 2 key values pairs so that the pod would start to use the `god` ServiceAccount.


```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lol
...
spec:
  template:
    metadata:
      labels:
        app: lol
    spec:
      serviceAccount: god     # Important lines to add
      serviceAccountName: god # Important lines to add
...
```

Once we have done that, we can then exec into the pod once more and then install kubectl and then run the following set of commands to test it out. It should work properly.

```bash
kubectl get pods
kubectl get pods --all-namespace
```

I'll probably provide more context on the side project that I'm doing in the future on why is this is needed but for now, I'll leave this as it is. Till next time...
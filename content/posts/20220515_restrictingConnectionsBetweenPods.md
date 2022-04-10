+++
title = "Restricting connections between pods in a Kubernetes Cluster (Network Policy)"
description = "Restricting connections between pods in a Kubernetes Cluster by using Kubernetes Network Policy kind resource"
tags = [
    "devops",
    "google-cloud",
    "kubernetes",
]
date = "2022-05-15"
categories = [
    "devops",
    "google-cloud",
    "kubernetes",
]
+++

There is an old adage from security land that we should restrict access to resources/assets as much as we can. Users and applications should only access items that they need to operate themselves. Following this line of thought, that would mean that if we are to deploy application in a Kubernetes Cluster, we should ensure that pods should only accept communication that they've explicitly declared as "required". Is there a way to do so?

Well, naturally, since this blog post will be covering it; that would mean that there is a way to do so in Kubernetes. However, one thing to know is that in the past, some people would have done it via Service Meshes (you can refer to projects like Istio for examples of this). This functionality is highlighted front and centre in terms of the product pages of such service meshes (but of course, other functionality is just as important - e.g. Circuit Breaking, Rate limiting etc)

However, let's say, we have the security requirement of restricting network traffic between pods (pods that require such communication will require explicit declaration) but we don't want to take on the huge dependency of running a service mesh in our cluster. How can this be done?

There is a Kind called `NetworkPolicy`. We can demonstrate this with the following example:

## Setting up a Cluster, Deployments and Services

First step is to get ourselves a Kubernetes Cluster; maybe a Google Kubernetes Engine cluster? The more important bit is that we would set the Google Kubernetes Engine with NetworkPolicy enforcemenet enabled. In the Google Cloud Console (UI) at the time of writing, we can find that option under "Networking". There are 5 parts of the cluster that we configure for GKE which is Automation, Networking, Security, Metadata and Features. We would then want to run the following set of commands:

```bash
# Create a deployment with nginx image to be run in default namespace
kubectl create deployment lol-default --image=nginx

# Create a new namespace called yahoo
kubectl create namespace yahoo

# Create multiple deployments in yahoo namespace
kubectl create deployment lol-yahoo --image=nginx -n yahoo
kubectl create deployment miao-yahoo --image=nginx -n yahoo
```

At the end of this, we would have 3 pods in 2 namespaces:

```bash
# Get pods from default namespace
NAME                           READY   STATUS    RESTARTS   AGE
lol-default-5db5d6874f-prknx   1/1     Running   0          73m

# Get pods from yahoo namespace
NAME                         READY   STATUS    RESTARTS   AGE
lol-yahoo-59d5c4d954-vkb7l   1/1     Running   0          70m
miao-yahoo-b68745745-tvqh2   1/1     Running   0          64m
```

Let's the have the pods for `lol-default` deployment be exposed via a service.

```bash
kubectl expose deployment lol-default --port=80
```

If we now go into lol-yahoo pods and try to query for the lol-default pods via service, we would be allowed to do so:

```bash
# Format: kubectl exec -it <pod-name> -n yahoo -- /bin/bash
kubectl exec -it lol-yahoo-59d5c4d954-vkb7l -n yahoo -- /bin/bash
```

Within the container:

```bash
curl lol-default.default.svc
```

It should return the following:

```bash
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## Restricting the connections with NetworkPolicy

Let's try locking it down now - first step is to set an initial NetworkPolicy rule to deny all ingress for all pods within the default namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

Note the the empty podSelector. This would indicate that it should be apply to all pods within the namespace that this NetworkPolicy is in. Also, since there is no "Ingress" rule provided within this NetworkPolicy, we would be denying all ingress connections (although egress is ok).

If we try to curl for `lol-default.default.svc` from the lol-yahoo pod, we would not be able to connect properly. The command will just hang as connection is rejected.

Let's say we would want to set up such that only `lol-yahoo` can connect to `lol-default` but not `miao-yahoo`. How can we set such a configuration up?

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-lol-yahoo-lol-default
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: lol-default
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: yahoo
      podSelector:
        matchLabels:
          app: lol-yahoo
```

Let's go through step by step what this NetworkPolicy kind of means here:  
- NetworkPolicy is applied to default namespace -> so it will potentially pods within this namespace
- spec.PodSelector is not empty. It is applied to only pods that have the labels `app: lol-default`. So, if there are other pods in the `default` namespace, they will still affected by our default NetworkPolicy of denying all ingress traffic. 
- We declared `spec.Ingress` this time. Rules defined here are "allow" rules -> essentially, we're saying that pods or traffic from certain ip address are allowed to reach into pod.
- `spec.Ingress.from[0].namespaceSelector` was defined. If this was empty but podSelector was filled, it would mean that the rule is applied to `default` namespace since no namespace selector was passed to that entry. For more details on this, it's best to refer to Kubernetes documentation: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.23/#networkpolicypeer-v1-networking-k8s-io

With the above NetworkPolicy in place, this should allow us to run curl from `lol-yahoo` pod but not from `miao-yahoo` pod. This is `lol-yahoo` pod is the pod that has the labels of `app: lol-yahoo` and comes from `yahoo` namespace.

Refer to the following page as well for more details on NetworkPolicy and its usage: https://kubernetes.io/docs/concepts/services-networking/network-policies/

## Conclusion

NetworkPolicy is a little interesting exercise on how to limit traffic between pods; however, it comes with its set of limitations (refer to the link above). A lot of limitations seem to point that users that require such features should go for service mesh instead - which makes it seem that maybe, depending on one's requirement, one should explore service meshes such as Istio or Gloo etc.

A random thought that come up would be that the implementation of NetworkPolicy or any other technology that requires application developers to explicitly set which application can access it is additional administrative load on developers. I doubt that would be an automated way to do so - but I do look forward if there is any interesting development in this space.

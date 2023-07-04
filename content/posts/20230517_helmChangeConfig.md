+++
title = "Updating configuration in Kubernetes pods managed via Helm"
description = "Updating configuratin in Kubernetes pods managed via Helm chart - restarts required"
tags = [
    "golang",
    "kubernetes",
]
date = "2023-05-17"
categories = [
    "golang",
    "kubernetes",
]
+++

When building an application, a common way to alter and set the running properties of the application is to use configuration files that could be written with JSON or Yaml files. This is the same even if the application is simply deployed in a Virtual Machine or even in a container within a Kubernetes Cluster. The general assumption is that the configuration file does not change that often - if the configuration files is to be change, the usual way to have the application conform to the new configuration file would be stop the currently running the application and start it once more.

The restart of applications if it happen to be deployed in a Virtual Machine is relatively easier to handle. If the application is managed via systemd, we can simply using the `systemctl` command line tool to simply restart the application once we altered the configuration files on the virutal machine. However, this would be slightly different if we happen to be on Kubernetes cluster. The way it is done would be slightly different.

Let's assume that we deploy our applications into the Kubernetes cluster using plain old yaml manifest files. If this is to be done, we would need to first alter the manifest file to alter the configmaps which would apply the application configuration. Our application will be defined in Kubernetes deployment. In order to "restart" our pod created via Kubernetes deployment is by deleting the pod and the new pod will be recreated automatically - the configuration will be reloaded when the application starts in the new pod. However, do note of the manual action that we need to take here which is to delete pod after the new configmap has been applied to the cluster.

However, let's say if we were to manage our application via helm charts instead. Ideally, an upgrade of the helm chart on the cluster should be sufficient to ensure that the application is using the new configuration from the update configmaps. It wouldn't make sense for us to "upgrade" the application being managed by the helm chart and then delete pod just to ensure that the pod would pick up the new configuration. If we simply just upgrade the helm chart just as it is, the configmaps will be updated but the pods and deployment objects will not be updated (if there isn't any changes for the hydrated for the manifests). The pods would continue running with the old configuration.

Here, we can make use a useful property that comes with deployment object - if annotations for pod is to change - it would result in the defined pod being "different" and hence, the deployment would need to restart the rollout. We can simply apply it here and observe how it works:

Let's say we have a helm chart which accepts a configuration yaml which can be passed into helm chart installation process. The image to be deployed would be `yahoo:v30` which is also defined in the configuration yaml file. Let's say the configuration file is saved as `aa.yaml` here.

The following helm chart we are going to be referencing would be found in the following github repo:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicHelm  

```
image:
  repository: gcr.io/xxx/yahoo
  tag: v30

appConfig: |
  lol: caca
  miao: zzz
```

Within the `deployment.yaml`, we would need to define the annotations of our pod defined within the deployment as follows:

```yaml
...
spec:
{{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
{{- end }}
  selector:
    matchLabels:
      {{- include "basic-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        configmap-hash: {{ .Values.appConfig | sha256sum }}
      {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
      {{- end }}
      labels:
        {{- include "basic-app.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
...
```

To test this out, we can simply run the following set of commands to install it:

```bash
helm upgrade -f aa.yaml  --install basic-app ./basic-app
```

This would get a pod running:  

```bash
% kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
basic-app-584f4bd9df-htjts   1/1     Running   0          5m
```

If we were to update the `appConfig` field in our configuration file `aa.yaml` - we should see the following:

Updated `aa.yaml`...

```
image:
  repository: gcr.io/xxx/yahoo
  tag: v30

appConfig: |
  lol: caca
  miao: zzz
  anotherConfig: 12
```

And we would need to rerun the upgrade to bump up the helm chart:

```bash
helm upgrade -f aa.yaml  --install basic-app ./basic-app
```

We should observe the new pod being created.

```bash
% kubectl get pods
NAME                         READY   STATUS    RESTARTS   AGE
basic-app-584f4bd9df-htjts   1/1     Running   0          7m
basic-app-6847c48b69-cwb7b   0/1     Running   0          3s
```

With that, we can ensure that the new configuration would be applied to our application in the case where our application only reads the configuration on initial start up of the application.
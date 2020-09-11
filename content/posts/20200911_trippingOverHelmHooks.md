+++
title = "Tripping over helm hooks"
description = "Helm hooks configurations that have confusing behaviours during upgrades"
tags = [
    "kubernetes",
]
date = "2020-09-11"
categories = [
    "kubernetes",
]
+++

One typical way to do packaging for applications that are to targeted to be deployed into a Kubernetes environment would be to utilize the helm tool. The helm tool has been used widely enough to the point that there are whole ecosystems that support the usage of this tool. Refer to the website for this here: https://hub.helm.sh/

In basic setup, a helm chart would be deploying following a specific order set in the codebase. E.g. namespace -> configmaps next etc. If we are to follow that, then, developers would have no control over how their applications to the cluster. In a more complex scenario; e.g. where maybe a job needs to be deployed first which would do database migration before actual deployment happens, we can't just rely on the order that is set within helm codebase. We would probably need to have capability to control what resource is to be deployed to the cluster, when it would be deployed (e.g. like a pre-deployment step in order to get the data/machine to the state to accept the new version of the application). The mechanism for this is helm hooks. A good reference for this is to refer to the documentation that is already available on helm website: https://helm.sh/docs/topics/charts_hooks/

## Considering/Thinking about helm behaviours

Let's say we have a sample application that has a helm chart with the following snippets.

In /templates/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: basic-app-config
data:
  game.properties: |
    lol: caca
    miao: zzz
```

In /templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: { { include "basic-app.fullname" . } }
spec:
  template:
    spec:
      volumes:
        - name: foo
          configMap:
            name: basic-app-config
            items:
              - key: "game.properties"
                path: "game.yaml"
      containers:
        - name: { { .Chart.Name } }
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: { { .Values.image.pullPolicy } }
          volumeMounts:
            - name: foo
              mountPath: "/etc/foo"
              readOnly: true
// ... Shortened version presented here to focus on specific points - volume configuration
```

Other resources that are to be managed by the chart is not presented here.

Let's say we get the following chart and deployed it to a cluster. And let's say, eventually, we need the configmap to added as some sort of pre-hook (maybe we need to run a database migration before a application update)

In this case, we would add the configmap to the helm hooks to the configmap

New /templates/configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: basic-app-config
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
data:
  game.properties: |
    lol: caca
    miao: zzz
    newconfig: aaa // New configuration line added
```

In order to get the pod to get the new configmap - we would need to do some sort of change on deployment file - in this case, a typical way would be add sort of timestamp as sort of annotation to the deployment resource. With that the pod would be recreated and the configuration can be successfully loaded into the pod

If we do so, we'll see the following:

```
NAME                               READY   STATUS              RESTARTS   AGE
yahoo-basic-app-565d9dc8c4-22nfj   1/1     Running             0          32m
yahoo-basic-app-565d9dc8c4-jmknb   1/1     Running             0          32m
yahoo-basic-app-565d9dc8c4-kkkrv   1/1     Running             0          32m
yahoo-basic-app-565d9dc8c4-kksp6   1/1     Running             0          32m
yahoo-basic-app-bd6fcc946-mvs8w    0/1     ContainerCreating   0          31m
yahoo-basic-app-bd6fcc946-q2r6c    0/1     ContainerCreating   0          31m
yahoo-basic-app-bd6fcc946-x8rdq    0/1     ContainerCreating   0          31m
```

The new pods are stuck in ContainerCreating phase. Trying to describe the problem shows the following:

```
Events:
  Type     Reason       Age                From                                               Message
  ----     ------       ----               ----                                               -------
  Normal   Scheduled    4m8s               default-scheduler                                  Successfully assigned default/yahoo-basic-app-bd6fcc946-mvs8w to gke-cluster-1-default-pool-41a5ca1d-5nh4
  Warning  FailedMount  2m5s               kubelet, gke-cluster-1-default-pool-41a5ca1d-5nh4  Unable to mount volumes for pod "yahoo-basic-app-bd6fcc946-mvs8w_default(11a13ba5-0640-4766-96fb-7db3759a6cbc)": timeout expired waiting for volumes to attach or mount for pod "default"/"yahoo-basic-app-bd6fcc946-mvs8w". list of unmounted volumes=[foo]. list of unattached volumes=[foo yahoo-basic-app-token-dcvnm]
  Warning  FailedMount  2m (x9 over 4m8s)  kubelet, gke-cluster-1-default-pool-41a5ca1d-5nh4  MountVolume.SetUp failed for volume "foo" : configmap "basic-app-config" not found
```

To sum it up, none of the logs from the following components would show anything significant/obvious:

- Tiller component (if you used helm v2)
- Helm client tool (it won't complain of any errors)
- Kubelet logs
- Docker logs

A interesting thing to note is that now, the `basic-app-config` configmap is missing from the newly deployed. So what's happening here?

Apparently, this boils to understanding that helm actual tracks and monitors resources that it is suppose to manage. Prehook resources are technically not managed/tracked as part of the main part of the release (in the case we skip hooks, the resource would not be deployed).

So in the case of the following, what probably happen was: (we set v1 as the initial version where configmpas has no helm annotations and v2 as the one with helm annotations)

- v1 was deployed where configmap is part of main helm release
- Configmap is designated to be deployed as part of pre-hook
- v2 was deployed
- New configmap created as part of prehook
- Helm does a diff between resources in v2 release and v1 release. It finds configmap is not meant to be there and it removes the configmap resource
- Pod finally scheduled to the Worker node
- Pod attempts to read and get configmap; however resource is deleted
- It would complain that it is unable to mount the configmap resource

The chain of events are actually logical conclusions of what each tool/platform does. We do want additional resources that are removed from our helm chart to also be removed from the platform but as a side effect - this weird confusion happens when we randomly add helm annotations without any regard of the side effects it may cause.

## Conclusion

If we come across such scenario - we can either purge the helm chart. Or redeploy it once more - the problem would kind of go away (on the second time of redeploy, the configmap would be left undeleted).
This would be a weird kind of bug that one can easily attribute to flaky setup and probably rare for one to think and reason about.

To refer to a sample codebase that you can use to try this out:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicHelm

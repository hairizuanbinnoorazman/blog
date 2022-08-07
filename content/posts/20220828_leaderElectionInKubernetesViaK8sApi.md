+++
title = "Leader Election in Kubernetes via Kubernetes Configmaps and Leases"
description = "Leader Election in Kubernetes via Kubernetes Configmaps and Leases"
tags = [
    "golang",
    "google-cloud",
    "kubernetes",
]
date = "2022-08-28"
categories = [
    "golang",
    "google-cloud",
    "kubernetes",
]
+++

The leader election mechanism is a somewhat complex thing to kind of code up for an application. There are various Golang libraries that assist with this but it would be nicer if there were mechanisms within the environment that the application operate in which can help with this. In the case for the Kubernetes ecosystem - we can actual rely on the fact of how Kubernetes would usually etcd that does this leader election dance on our behalf. If we can tap on this mechanism, we can avoid introducing this mess of a complexity within our application.

This mechanism is made possible by having the application interact and attempt to create/update a configmap or endpoint resource. There is a "resource version" that can be passed within such create/update requests and if there were 2-3 applications concurrently doing this operation, only 1 of it would be processed - the rest would fail. With this, we can use the one which successfully processed its operation and have that become the leader - the rest becomes the followers.

## Leader election in app via Kubernetes mechanics

Refer to the following codebase: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/leaderElectionWithK8s

It is somewhat fortunate that leader election is a common enough use case that it's availability as a utility within the `client-go` Kubernetes client library. Refer to the specific part of the `client-go` library here: https://pkg.go.dev/k8s.io/client-go/tools/leaderelection

The important bits for the portion for doing leader election is to first create the resource lock that would be used to store the details of how the leader election details would be held. I've generally dealt with leader election in Kubernetes Operators via Configmaps and that's the one I'm somewhat more familiar with so hence, this is why the Configmap resource is chosen here but I doubt either has advantages/disadvantages. They are the more minimalistic APIs that can be utilized for leader election.

```golang
rl, err := resourcelock.NewFromKubeconfig(resourcelock.ConfigMapsLeasesResourceLock, "default", "app-lock", resourcelock.ResourceLockConfig{
		Identity: POD_NAME,
	}, config, 10*time.Second)
```

The more important bit is to define the information for leader election struct and how to define the information that is to be used for leader election.

```golang
    ctx := context.Background()
	LESettings := leaderelection.LeaderElectionConfig{
		Lock:          rl,
		LeaseDuration: 10 * time.Second,
		RenewDeadline: 5 * time.Second,
		RetryPeriod:   2 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: zzz,
			OnStoppedLeading: func() {
				fmt.Println("Stopped")
				panic("stopped leading")
			},
			OnNewLeader: func(id string) {
				if id != POD_NAME {
					fmt.Println("is not the leader")
					leaderState = false
				} else {
					fmt.Println("is the leader")
					leaderState = true
				}
			},
		},
		Name: "debugging",
	}

    // ... Some other code can go here

    leaderelection.RunOrDie(ctx, LESettings)
```

The resource lock that we created earlier is passed here into the LeaderElection configuration struct. Other things that we need to configure would be:

- Lease duration (How long to hold the "leader" state for a pod safely)
- Renew deadline (How long for leaders to retry getting "leader" role)
- Retry period (How long before other clients try to get leader role)

Renew deadline parameter has to be less than lease duration - if you attempt to configure it as less than lease duration - you will see a runtime error and the application will panic and crash (Due to the `RunOrDie` function)

The other parameter that needs to be filled up here would be the callbacks - we need to define actions on what to do when leader election is successful - and what to do when the other pod is the leader instead of current pod. The above example is pretty much too simple of an example - additional error checks would probably need to be done in order to make sure it works with less errors/confusion.

With all of that, our leader election struct will be fully configured and we can pass it to our `RunOrDie` function which would do a leader election as the application runs. We can decide on what needs to be done if the pod becomes a leader.

## Deploying app with leader election

In general, I'd imagine that applications that require leader election would also need stable network identities as well. This is partially why, within that code base - the application is deployed via StatefulSets. This would allow us to potentially send data to specific pod endpoints that only leaders can handle (but this would covered in a future post). Right now, the focus for this codebase is to test that leader election works as expected and applications can become leader if required.

One of the more important things to handle is the RBAC permissions needed to get this whole application to run. Firstly, we would need to Cluster permissions to read Pod information (part of the `zzz` function - a tad unnecessary but this was a past functionality - leader election was added after that function was built). The important one for the leader election capability is the following RBAC specs.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: leader-election-configmaps
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["configmaps"]
  verbs: ["get", "watch", "list", "create", "update"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "list", "watch", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: leader-election-configmaps
subjects:
  - kind: ServiceAccount
    name: leader-election-app
    namespace: default
roleRef:
  kind: Role 
  name: leader-election-configmaps
  apiGroup: rbac.authorization.k8s.io
```

The application definitely needs capability to get, create and update configmaps and leases. (list and watch may not be too necessary but I haven't tested removing them). This can be added to the `leader-election-configmaps` which is then added to the `leader-election-app` service account user. This user will be the one that would be mounted into the pod where the application would then have permissions to access the kubernetes API to retrieve the relevant information or to manipulate the k8s resources accordingly.

## Lease API - just a lightweight way to do heartbeats?

We can kind of ignore the details behind the implementation of this function but if we try to dig around behind the needs of the rbac spec that needs to be specified to get this to work, we would kind of stumble and wonder - what is this Lease API and what's its for?

It is somewhat easy to follow along the codebase in `client-go` library to figure out what the `RunOrDie` function do. However, the thing is - most of the codebase don't explain why the Lease API even exist and how it helps with the whole leader election business.

Just basing of the following github issues - my guess is that Lease API was created to create a lightweight API which can be used to do heartbeat checks (part of Leader Election mechanism) - essentially, if a "application/node" fails to renew and extend the deadline of it being a leader - it is assumed to have fail and leader election would need to take place in order to figure who to be the leader next.

References:  
https://github.com/kubernetes/kubernetes/issues/14733  
https://github.com/kubernetes/kubernetes/issues/80289  

I guess to properly understand it, one would need to read the implementation of the Lease API or the KEP documentation that mentions it but I guess that should be covered in another blog post.

## Future work

I will probably further build out this application further to attempt to replicate some sort of nosql database a little (but a very very bad version of it) - maybe it can store data in json format. Some of the things to look at and to build out:

- Data that is to be written to file storage can be sent to any pod within the Statefulset but it'll be redirected to master pod
- Data is replicated and mirrored and shared accordingly (consistent hashing mechanism)
- Any pod can be used for reading except for the leader. Leader would redirect the request followers since it should be busy with writing data into storage backend

Eventually, I'd want to also explore implementing this leader election without this Kubernetes mechanism - probably use the various Golang raft libraries for building such functionalities.
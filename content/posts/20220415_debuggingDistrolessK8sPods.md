+++
title = "Debugging Distroless Kubernetes Pods"
description = "Debugging Distroless Kubernetes Pods with kubectl debug command"
tags = [
    "devops",
    "kubernetes",
    "docker",
    "google-cloud",
    "golang",
]
date = "2022-04-15"
categories = [
    "devops",
    "kubernetes",
    "docker",
    "google-cloud",
    "golang",
]
+++

There is a trend of images that follow the philosophy of minimizing the size of image by removing almost everything out of image. This helps with getting image downloaded more quickly by kubelet into the nodes as well as possibly reducing the attack surface of the container even further (I suppose it's harder to do things in a container if utilities like shell or bash don't exist within it). You would probably see errors such as this for those containers that have somewhat remove the shell/bash:

```bash
error: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "cc558cb1b205490e0f5b604c06d542ea997748485ab1c869d97240e8b8792d77": OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: "/bin/bash": stat /bin/bash: no such file or directory: unknown
```

How do we get such a container? Let's go step by step and go from creating such a golang application, build a docker image for it and then running it in the cluster.

Important note here is that the following files are for Golang 1.14. Apparently, later versions of Golang require certain modules files etc to be in place.

```golang
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	port := 8080

	http.HandleFunc("/", helloWorldHandler)

	log.Printf("Server starting on port %v\n", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("serving", r.URL)
	fmt.Fprint(w, "This is a test. Hello World Miaoza!!\n")
}
```

Save the following file in `main.go` in a folder. This is just a simple Golang application that has one single route. You can run it locally with `golang run main.go` and then, use curl/wget to get the responses of it.

Next would be the docker image; we would be using an image that starts with distroless. Distroless images are images that have characteristics that were mentioned in the top part of the blog: removal of as much of the container as possible to reduce the image size as well as attack surface. You can refer to the project here: https://github.com/GoogleContainerTools/distroless

Let's have the following Dockerfile to build our docker image:

```Dockerfile
FROM golang:1.14 as build
WORKDIR /app
ADD . .
RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/base-debian11:nonroot
COPY --from=build /app/app /app
EXPOSE 8080
CMD ["/app"] 
```

As mentioned, this uses golang:1.14 docker image to build the app. The app binary is then copied over to a debian "nonroot" distroless container. Let's save the file in `Distroless.Dockerfile`

We can build the dockerfile and the run the image generated from it using the following commands: 

```bash
docker build -t testing -f Distroless.Dockerfile .
docker run -p 8080:8080 --name testing testing
```

The first line in the above command is to be build the docker image. The build docker image will be tagged with the name "testing". We would then use that built image "testing" and run it - not forgetting to map our host machine's port 8080 to the container's port 8080. To test that the application works of the docker image, we can just run curl against it

```bash
curl localhost:8080
```

That should return the following response:

```bash
This is a test. Hello World Miaoza!!
```

Normally, if us as developers would like to inspect what is going on within the image, we would want to try to run the shell command and then inspect the files within it etc. If we tried to run a command that to do so:

```bash
docker exec -it testing /bin/bash
```

We would see this error instead:

```bash
OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: "/bin/bash": stat /bin/bash: no such file or directory: unknown
```

This is as expected from a container built with a distroless base. We would expect such utility capabilities to not be available. For debugging purposes, it might be better to not rely on distroless but instead, use a plain old debian image - that would allow us to debug more easily locally.

However, in the case where we would need to debug it in a production setting? E.g. Engineering management mandating that every team in the company utilizes distroless base image. How do we debug this on production? Would it be possible?

Let's try to demonstrate this with this image on a Google Kubernetes Engine cluster.

First step would be to push the built image to Google Container Registry. We can do so by retagging the "testing" image with the appropiate tag as follows:

```bash
docker tag testing gcr.io/<project id>/distroless-hello-world:v1
```

We can then push the image into Google Container Registry (assuming that you have already done all the steps to authorize your workstation to push it automatically there)

```bash
docker push gcr.io/<project id>/distroless-hello-world:v1
```

The next step would be to have a yaml file that would contain the deployment kubernetes manifest to get our application into production. We would apply the following manifest file by running the kubectl apply command as follows.

```bash
# Assuming that the below file is called "secure.yaml"
kubectl apply -f secure.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: distroless-helloworld-1
  labels:
    run: helloworld-1
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      run: helloworld-1
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        run: helloworld-1
    spec:
      securityContext:
        # https://kubesec.io/basics/containers-securitycontext-runasuser/
        runAsUser: 20000
        runAsGroup: 20000
        fsGroup: 20000
      containers:
        - image: gcr.io/<project id>/distroless-hello-world:v1
          name: helloworld
          ports:
            - containerPort: 8080
          securityContext:
            allowPrivilegeEscalation: false
            privileged: false
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - all
      restartPolicy: Always
```

The following deployment yaml file would deploy such a pod that utilizes the above built image and start it up in pod. For extra good measure, we added additional security options that normal basic web applications should respect such as not running in privileged mode, not running as root and not requiring any special linux kernal capabilities. We can then check that the pod is running by doing the following:

```bash
kubectl get pods
```

This would get all the pods on the clusters at the moment; which if you run this on a "fresh" GKE instance, it would show the following:

```bash
NAME                                       READY   STATUS    RESTARTS   AGE
distroless-helloworld-1-5d8dd7f664-xsvl2   1/1     Running   0          3m27s
```

If we wish to check that the application still works, we can run a port forward to make sure that application is still working and serving the right traffic.

```bash
# Example format
# kubectl port-forward <pod name> 8080:8080
kubectl port-forward distroless-helloworld-1-5d8dd7f664-xsvl2  8080:8080
```

We can run curl against localhost:8080 to check that the application is still serving traffic as expected.

However, let's say we go into the situation where we would need to check the files of our application container? Can we run the some sort of "shell" to check for that? If we tried to do so here:

```bash
kubectl exec -it distroless-helloworld-1-5d8dd7f664-xsvl2 -- /bin/bash
```

We would have the following error (as expected):

```bash
error: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "3929950fd0d4be8c20b2e4efd3db1693b59d665750954f2260b66bbc766d32f4": OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: "/bin/bash": stat /bin/bash: no such file or directory: unknown
```

It is somewhat similar to the error message at the top of this post. So, is there a mechanism that would allow us to do this sort of check?

One method right now is to run a kubectl debug command (or a variant of it). There is still plenty of development around surrounding this component so, its usefulness is still not maximized but in some cases like this, it's good enough. If we run the debug statement as follows:

```bash
kubectl debug distroless-helloworld-1-5d8dd7f664-xsvl2 -it --image=ubuntu --share-processes --copy-to=debugging-pod
```

This step literally **creates a new pod** with a ubuntu sidecar as well as a copy of the application that we're trying to debug (it is not the same application but a copy). We can then run the following command:

```bash
ps ax
```

This would list all processes in the whole pod (note the additional flag of share-processes that allow us to see processes in the other container in the pod)

```bash
    PID TTY      STAT   TIME COMMAND
      1 ?        Ss     0:00 /pause
      7 ?        Ssl    0:00 /app
     16 pts/0    Ss     0:00 bash
     25 pts/0    R+     0:00 ps ax
```

From what we know, the `/app` is the process that our main "app" docker image is running. We can continue debugging by running curl commands locally or running other checks against the other container. Or we can even check the files on the other container. This can be done by the following:

```bash
# Format:
# cd /proc/<process id of /app>/root
cd /proc/7/root
```

That will put us in the file system of the container that is running the /app command. This would useful to kind of inspect possibly rendering of configuration files or seeing how the application responds to live traffic and how it manipulates the file system.

The above is a tiny exercise of how Kubernetes continues to be improved to make it easier to debug applications. Unfortunately, the debug subcommand still has issues here and there (you can't debug an actual "live" application by maybe creating a temporary image alongside the live container?). The functionality is still under development work (possible to use but it seems certain flags need to be turned on? Or it could be I misunderstand if that's the functionality being offered)

The following source code is also available in the following Github repo as well:
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicWeb
+++
title = "Deploy Golang Apps that interact with headless service in Kubernetes"
description = "Deploy Golang Apps that interact with headless service in Kubernetes"
tags = [
    "golang",
    "docker",
    "kubernetes",
    "google-cloud",
]
date = "2023-07-12"
categories = [
    "golang",
    "docker",
    "kubernetes",
    "google-cloud",
]
+++

In certain application scenarios - there is a need to have applications that need to do client side load balancing to a bunch of servers. Such cases are pretty rare - but we won't be covering the exect reasons or scenarios or when these are needed. Instead, we will cover how we can do so with Golang applications in Kubernetes cluster.

## Building out the Golang application

We would need 2 types of applications to demonstrate this. One side of the application that will attempt to contact the servers that can scale up and down. This side will be "firer" application that will fire http requests - it will query the headless services (via DNS resolution lookup). The other application will simply be a simple http server and would just return a simple text data (with datetime) to show that the request is real and to differentiate the different requests on the server logs.

We can build 1 simple Golang application that can switch between the 2 different modes: "firer" vs "server" modes. The below code is the entire code base - it would still need to wrapped in a docker image etc before it can be deployed to the server.

```golang
package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"time"
)

func firer() {
	hostName := os.Getenv("SERVER_HOST")
	if hostName == "" {
		fmt.Println("hostname not defined. will exit")
		os.Exit(1)
	}
	for {
		ips, err := net.LookupIP(hostName)
		if err != nil {
			fmt.Printf("unexpected error while looking up ips: %v", err)
		}
		for _, ip := range ips {
			fmt.Printf("%v ips found. Will contact ip: %v", len(ips), ip.String())
			time.Sleep(2 * time.Second)
			resp, err := http.Get(fmt.Sprintf("http://%v:8080", ip.String()))
			if err != nil {
				fmt.Printf("unexpected error when contacting: %v\n", err)
			}
			raw, _ := io.ReadAll(resp.Body)
			fmt.Printf("Output from ip: %v, %v", ip.String(), string(raw))
		}
	}

}

func server() {
	port := 8080

	http.HandleFunc("/", helloWorldHandler)

	log.Printf("Server starting on port %v\n", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("serving", r.URL)
	fmt.Fprintf(w, "This is a test. Hello World Miaoza!! Time: %v\n", time.Now())
}

func main() {
	mode := os.Getenv("MODE")
	if mode == "firer" {
		firer()
	} else if mode == "server" {
		server()
	} else {
		panic("Mode not properly defined. Will terminate")
	}
}

```

The most critical piece of the above code would be the following:

```golang
        ips, err := net.LookupIP(hostName)
		if err != nil {
			fmt.Printf("unexpected error while looking up ips: %v", err)
		}
```

This part would attempt to resolve our k8s service. Normally, for DNS Resolution - one hostname would usually resolve to 1 IP address - we would usually not bother doing a query and then managing that dns query within our codebase.

When deploying the above application, we would need to deploy the following k8s service object - NOTE: there will be one very important line that would convert it from a "normal" kubernetes service to headless one.

```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: server
    component: server
  name: headless-server
spec:
  ports:
  - name: http
    port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: server
    component: server
  type: ClusterIP
  clusterIP: None
```

The most important line here would be the `clusterIP: None`. This would let kubernetes know not to provision a new IP for this kubernetes service but instead - simply expose all the IPs of the pods that are tagged to mentioned labels within.

## Deploying the headless server and firer

We can refer to the following codebase: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/headlessService

If we are to utilize the above codebase, we would first build the following docker image.

```bash
docker build -t gcr.io/<project id>/headless-service-app:v3 .
```

We can then push the image into the container registry:

```bash
docker push gcr.io/<project id>/headless-service-app:v3
```

After which, we can then utilize the `kustomize` tool to then deploy the services once we have a GKE cluster.

```bash
kustomize build . | kubectl apply -f -
```

Initial deploy would only show 1 replica of the server. We can scale it out to 4 replicas.

```bash
kubectl scale deployment server --replicas=4
```

Once we have 4 replicas, we can view the logs on our `firer` application.

```bash
4 ips found. Will contact ip: 10.8.0.12Output from ip: 10.8.0.12, This is a test. Hello World Miaoza!! Time: 2023-10-22 13:13:43.428359366 +0000 UTC m=+3105.938009744
4 ips found. Will contact ip: 10.8.0.146Output from ip: 10.8.0.146, This is a test. Hello World Miaoza!! Time: 2023-10-22 13:13:45.431671786 +0000 UTC m=+3355.873443571
4 ips found. Will contact ip: 10.8.0.13Output from ip: 10.8.0.13, This is a test. Hello World Miaoza!! Time: 2023-10-22 13:13:47.435236353 +0000 UTC m=+3109.942062831
4 ips found. Will contact ip: 10.8.0.66Output from ip: 10.8.0.66, This is a test. Hello World Miaoza!! Time: 2023-10-22 13:13:49.449002043 +0000 UTC m=+2997.637140403
```

## References

Refer to the following resources:

- Full code demo for this: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/headlessService
- Headless service: https://kubernetes.io/docs/concepts/services-networking/service/#headless-services
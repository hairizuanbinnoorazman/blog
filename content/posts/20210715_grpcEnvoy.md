+++
title = "Using Envoy for GRPC Applications in Kubernetes"
description = "Using Envoy for GRPC Applications in Kubernetes"
tags = [
    "google cloud",
    "kubernetes",
]
date = "2021-07-15"
categories = [
    "google cloud",
    "kubernetes",
]
+++

As of now, one of the common and easier way to have services communicate with each other would be over HTTP. In real world use cases, HTTPS is usually used (in order to ensure communications are secure) and this communication is done following some sort of REST framework. This provides some sort of structure of how to standardize such communications for the various software applications out there. It got to the point where entire companies are developing in order to support this: e.g. Apigee, SmartBear

However, with HTTP based communications, there is some sort of overhead in order to do the communication. A recent version update of HTTP to HTTP/2 allows the services to setup the communication with less overhead by creating long lived connections and multiplexing communications over each other as well as sending data in an encoded format. Refer to this possible video for a point of reference on this: https://www.youtube.com/watch?v=RoXT_Rkg8LA.
However, we're not going to go deep into this as that is not the primary focus of this article. This article focuses on trying to setting up of golang grpc services and load balance such traffic with envoy on Kubernetes.

Refer to the following link while following this article:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicGRPC  
There would be updates on it as time goes on - updates to the codebase will be listed on the README.md file  

# Protobuff file generation

The following file is to be saved in "ticketing" module. The proto file would be used to generate the golang files that is to be used to intepret the messages that are being passed back and forth between the client and server services.

```proto
syntax = "proto3";

option go_package = "github.com/hairizuanbinnoorazman/basic-grpc/ticketing";

package ticketing;

service CustomerController {
    rpc GetCustomer(GetCustomerRequest) returns (Customer) {}
    rpc CreateCustomer(CreateCustomerRequest) returns (Customer) {}
    rpc ListCustomers(ListCustomersRequest) returns (CustomerList) {}
}

message GetCustomerRequest {
    string id = 1;
}

message CreateCustomerRequest {
    string first_name = 1;
    string last_name = 2;
}

message ListCustomersRequest {}

message CustomerList {
    repeated Customer customers = 1;
}

message Customer {
    string id = 1;
    string first_name = 2;
    string last_name = 3;
}
```

We need to then produce the required golang files to handle the messages in golang

Run the following command:

```bash
protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    ticketing/ticketing.proto
```

That would produce 2 files: `ticketing.pb.go` and `ticketing_grpc.pb.go`. These said files would then be used as part of the golang services.

# Golang GRPC Server

This would be golang GRPC Server that utilize the ticketing proto golang files

```golang
package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"

	"github.com/hairizuanbinnoorazman/basic-grpc/ticketing"

	"google.golang.org/grpc"
)

var podID string = "test"

type actualCustomerControllerServer struct {
	ticketing.UnimplementedCustomerControllerServer
}

func (a actualCustomerControllerServer) GetCustomer(context.Context, *ticketing.GetCustomerRequest) (*ticketing.Customer, error) {
	log.Println("Hit Get Customer rpc call")
	defer log.Println("End Get Customer rpc call")
	return &ticketing.Customer{
		Id:        podID,
		FirstName: "acac",
		LastName:  "accqqq",
	}, nil
}

func main() {
	fmt.Println("Server Start")

	var exists bool
	podID, exists = os.LookupEnv("POD_NAME")
	if !exists {
		fmt.Println("Value of podID is test")
	}

	lis, _ := net.Listen("tcp", fmt.Sprintf("0.0.0.0:12345"))
	var opts []grpc.ServerOption
	grpcServer := grpc.NewServer(opts...)
	ticketing.RegisterCustomerControllerServer(grpcServer, actualCustomerControllerServer{})
	grpcServer.Serve(lis)
}
```

The `POD_NAME` is used to provide context on where the reply is coming from. This Golang application is being assumed to be running on Kubernetes environment. An environment variable is needed to be fed to the application to be able to uniquely identify the differents pods which would reply to the client portion of the application.

# Golang GRPC Client Application

This would be golang GRPC Client that utilize the ticketing proto golang files

```golang
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/hairizuanbinnoorazman/basic-grpc/ticketing"

	"google.golang.org/grpc"
)

func main() {
	domain, exists := os.LookupEnv("SERVER_DOMAIN")
	if !exists {
		domain = "localhost"
	}

	port, exists := os.LookupEnv("SERVER_PORT")
	if !exists {
		port = "12345"
	}

	var opts []grpc.DialOption
	opts = append(opts, grpc.WithTimeout(3*time.Second), grpc.WithInsecure())
	conn, err := grpc.Dial(fmt.Sprintf("%v:%v", domain, port), opts...)
	if err != nil {
		fmt.Println(err)
		panic(err)
	}
	defer conn.Close()

	for {
		getCustomerDetails(conn)
		time.Sleep(3 * time.Second)
	}
}

func getCustomerDetails(conn *grpc.ClientConn) {
	client := ticketing.NewCustomerControllerClient(conn)
	log.Println("Start GetCustomerDetails")
	defer log.Println("End GetCustomerDetails")
	zz, err := client.GetCustomer(context.Background(), &ticketing.GetCustomerRequest{})
	if err != nil {
		fmt.Println(err)
	}
	log.Println(zz)
}
```

It would be best to construct the code such that it would accept the `SERVER_DOMAIN` and `SERVER_PORT` as environment variables. These variables would vary based on deployment - and in the case of the application, it would be specific for a Kubernetes environment.

Note on the part that the establishing of the communication between client and server does not immediately end after the messages get send from server to client. Messages can still be sent back and forth with terminating the connection. This establishing of connection is the overhead being referred to at the top of the article which is the resources being saved for not required the applications to re-establish it over and over again.

# Build the docker image

Since we're deploying to a Kubernetes environment, we would need docker images for this. We can do this by having the following dockerfile.

```dockerfile
FROM golang:1.16 as base
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

FROM base as client
COPY . .
RUN go build -o app ./client
CMD ["/app/app"]

FROM base as server
COPY . .
RUN go build -o app ./server
CMD ["/app/app"]
EXPOSE 12345
```

Some interesting points of the Docker image to build the golang images is to add the `go.mod` and `go.sum` files to the base image first. These 2 dependency files are used to be able to pull the required golang modules. With this, that would allow the docker images to form a single layer image that can be cached as long as the golang module dependency files is not changed. 

An example of how a docker image that would be from this Dockerfile would be: `docker build --target client -t gcr.io/XXXXXXXX/grpc-client:XXXXXXXXXXX .`

Note on how the image is being tagged here - identified by the `-t` flag. In our example here, we're trying to deploy all of these into GKE, which is best used alongside GCP Container Registry. We do this by using the gcr.io domain which would be where the docker images would be sent to.

# Deploy it into Kubernetes

We would first need to deploy 1 client and at least 2 server instances of it into kubernetes. In the case of the yaml definitions below, it would be best to alter the images of the grpc client and grpc server. We can utilize kustomize to do so. See the github link from above for a reference to this.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-client
  labels:
    app: client
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
      - name: client
        image: grpc-client:latest
        command: ["/app/app"]
        env:
        - name: SERVER_DOMAIN
          value: envoy
        - name: SERVER_PORT
          value: "8443"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-server
  labels:
    app: server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: server
  template:
    metadata:
      labels:
        app: server
    spec:
      containers:
      - name: server
        image: grpc-server:latest
        command: ["/app/app"]
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: APP_VERSION
          value: V1
        ports:
        - containerPort: 12345
---
apiVersion: v1
kind: Service
metadata:
  name: app-server-headless
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: server
  ports:
    - protocol: TCP
      port: 12345
      targetPort: 12345
```

An important thing to note is that we would need to create a "headless" service rather than a normal service. A normal service (essentially not setting the `clusterIP: None`) would only release 1 IP address which is insufficient information to be passed to envoy. Headless services would provide the full list of ip address.

Essentially, a headless service would mean we are not relying on Kubernetes to do load balancing of web streams from applications.

The yaml definition is for deploying the envoy that would be used to load balance grpc traffic

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: envoy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: envoy
  template:
    metadata:
      labels:
        app: envoy
    spec:
      containers:
      - name: envoy
        image: envoyproxy/envoy:v1.18.3
        ports:
        - name: https
          containerPort: 8443
        volumeMounts:
        - name: config
          mountPath: /etc/envoy
      volumes:
      - name: config
        configMap:
          name: envoy-conf
---
apiVersion: v1
kind: Service
metadata:
  name: envoy
spec:
  selector:
    app: envoy
  ports:
  - name: https
    protocol: TCP
    port: 8443
    targetPort: 8443
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-conf
data:
  envoy.yaml: |
    static_resources:
      listeners:
      - name: listener_0
        address:
          socket_address:
            address: 0.0.0.0
            port_value: 8443
        filter_chains:
        - filters:
          - name: envoy.filters.network.http_connection_manager
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
              access_log:
              - name: envoy.access_loggers.stdout
                typed_config:
                  "@type": type.googleapis.com/envoy.extensions.access_loggers.stream.v3.StdoutAccessLog
              codec_type: AUTO
              stat_prefix: ingress_https
              route_config:
                name: local_route
                virtual_hosts:
                - name: https
                  domains:
                  - "*"
                  routes:
                  - match:
                      prefix: "/"
                    route:
                      cluster: echo-grpc
                      max_grpc_timeout: 2s
              http_filters:
                - name: envoy.filters.http.router
                  typed_config: {}
      clusters:
      - name: echo-grpc
        connect_timeout: 0.5s
        type: STRICT_DNS
        dns_lookup_family: V4_ONLY
        lb_policy: ROUND_ROBIN
        http2_protocol_options: {}
        load_assignment:
          cluster_name: echo-grpc
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: app-server-headless.default.svc.cluster.local
                    port_value: 12345
    admin:
      access_log_path: /dev/stdout
      address:
        socket_address:
          address: 127.0.0.1
          port_value: 8090
```

Once we deployed all of the above Kubernetes resources, we should be able see the logs of the client application and see the traffic would be load balanced across the server application.

It is important to take note that during GRPC communication - it is not the same as normal http communication. The communication is established, and is maintained. The messages get passed back and forth between client and server. It is expected that resource requirements to handle this form of communication should be way lower as compared as to normal http rest-based traffic.

# Resources

List of useful URLs

- https://github.com/envoyproxy/envoy/tree/main/examples
- https://github.com/GoogleCloudPlatform/grpc-gke-nlb-tutorial
- https://github.com/GoogleCloudPlatform/grpc-gke-nlb-tutorial/blob/master/envoy/k8s/envoy-configmap.yaml
- https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/traffic_splitting

+++
title = "Dockerizing application that use unix sockets"
description = "Dockerizing applications that use unix sockets"
tags = [
    "golang",
    "docker",
]
date = "2020-04-12"
categories = [
    "golang",
    "docker",
]
+++

While trying to understand how components that deal with Container Storage Interface (CSI) in Kubernetes, I came across mentions of how the components were using Unix domain sockets to communicate with each other. A quick read on why unix domain sockets seem to reveal that its use is to reduce the amount of overhead while such components talk to each locally. If the components had required to talk across to multiple nodes, it would have used TCP instead.

The following blog post is a good reference of using unix domain sockets for communication for golang.

https://eli.thegreenplace.net/2019/unix-domain-sockets-in-go/

## Running it on local machine

With reference from the following gist on github:  
https://gist.github.com/hakobe/6f70d69b8c5243117787fd488ae7fbf2

We can try to run the following on a local machine with bash available. (macos and linux). Save the following as `main.go`

```golang
package main

import (
	"io"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
)

// NOTE - CHANGE THE SOCKET FILE LOCATION ACCORDINGLY
var SocketFile = "/tmp/go.sock"

func echoServer(c net.Conn) {
	for {
		buf := make([]byte, 512)
		nr, err := c.Read(buf)
		if err != nil {
			if err == io.EOF {
				log.Println("END OF FILE")
				return
			}
			log.Println("error in trying to read data")
			return
		}

		data := buf[0:nr]
		println("Server got:", string(data))
		_, err = c.Write(data)
		if err != nil {
			log.Fatal("Writing client error: ", err)
		}
	}
}

func main() {
	log.Println("Starting echo server")
	ln, err := net.Listen("unix", SocketFile)
	if err != nil {
		log.Fatal("Listen error: ", err)
	}

	sigc := make(chan os.Signal, 1)
	signal.Notify(sigc, os.Interrupt, syscall.SIGTERM)
	go func(ln net.Listener, c chan os.Signal) {
		sig := <-c
		log.Printf("Caught signal %s: shutting down.", sig)
		ln.Close()
		os.Exit(0)
	}(ln, sigc)

	for {
		fd, err := ln.Accept()
		if err != nil {
			log.Fatal("Accept error: ", err)
		}

		go echoServer(fd)
	}
}

```

We can run the following by building the golang binary and running it or just running `golang run main.go`

We can try to run the following command and it would send "foo" to the application

```bash
echo -e '\x66\x6f\x6f' | nc -U $(pwd)/tmp/go.sock
```

## Dockerized app that uses unix domain sockets

Let's say we try to dockerize it.

```dockerfile
FROM golang:1.13
# This is so that internally, we can exec in and test it from inside
RUN apt update && apt install -y netcat-openbsd
ADD . .
RUN go build -o app ./main.go
CMD ["/go/app"]
```

We can then run the following command:

```bash
# Make a tmp folder in current directory
mkdir ./tmp

# Build container
docker build -t lol .

# Run container - and mount volume into it
# You should see the go.sock file created in the ./tmp folder that you created above
docker run -v $(pwd)/tmp:/tmp lol
```

With that, we would have created a running container that would run the application above. It would create a `go.sock` file within the `tmp` folder that you specified to mount to the container. However, if we were to try to use the run the command to communicate and send messages to the socket, it wouldn't work:

```bash
echo -e '\x66\x6f\x6f' | nc -U $(pwd)/tmp/go.sock
```

Reason for this seems to be so:  
https://forums.docker.com/t/cant-connect-to-host-listening-unix-socket-from-container-vm/15526/2

Sockets made via linux containers can't be used on macos systems to communicate to it. The only exception here would `docker.sock` and that is because efforts have been made to make it work.

However, if you do so on linux based hostsystem, it would work fine. The messages would get sent across as expected.

But, if this is still to be tested on macos, we can do the following:

- Run the above built docker container - we would deem this the container2.
- That would give us another linux container to work with. We can then run the `docker exec -it ... /bin/bash` on the second container.
- Run `docker logs ...` to get the logs from container 1
- Running the `echo -e '\x66\x6f\x6f' | nc -U /tmp/go.sock` in container 2. We should see the logs coming out that mention that it received messages that contain foo for container 1.

## Applying it back to what is seen in K8s CSI components

The set of components that provide storage plugins to Kubernetes via CSI (namely the hostpath-plugin) has a statefulset where a volume is bound to it. The statefulset here has 3 containers within it. The socket file is mounted to the all 3 containers where they would all be communicating with each other. The volume can be read and modified by any of the 3 containers.

Refer to the following yaml file:  
https://github.com/kubernetes-csi/csi-driver-host-path/blob/master/deploy/kubernetes-1.15/hostpath/csi-hostpath-plugin.yaml

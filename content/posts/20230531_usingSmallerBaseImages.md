+++
title = "Using smaller base images for applications, slim images? alpine images? distroless images"
description = "Using smaller images for applications - dealing with ssl certifications or musl vs glibc"
tags = [
    "golang",
    "docker",
]
date = "2023-05-31"
categories = [
    "golang",
    "docker",
]
+++

When building applications in docker images, there is sometimes a need to consider the size of the containers. There are multiple reasons for us to monitor and check this:

- In the case where our container registry is actually by us rather than the on public registries. The size of the container would affect the cost of storing all those artifacts. Let's say we are to look at some of the private container registries that we can setup on public clouds such as Google Cloud - there is a pricing set on per GB of storage as well as networking costs for shifting the container images out of the container registry.
- A smaller image is simply faster to move around. Let's say if we have a Kubernetes cluster that would need to run the container and let's also say that we need the container be run on multiple nodes of the cluster. Evidently, a container with a smaller footprint will take a way shorter time to pull the images from the registry. A larger container that could easily be in the Gigabyte range - e.g. images that container language runtimes etc. would take a way longer time to download as well as startup.
- One can kind of argue that the less stuff inside the container, the smaller the container would contain an application that has a security loophole.

With that, it is beneficial for us to build "smaller" container images - the benefits would be more evident more so for the infrastructure teams rather than the application teams. To application teams, we would probably have to suffer quite a bit since smaller container images would mean "useful" stuff would be removed from the container.

Let's demonstrate the various ways of building a container built with Golang.

Refer to the following github url: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basic  

## Naive Dockerfile

We can naively building the docker image by simplying using a base image that containers that Golang runtime - naturally, it would pretty huge (but we have a image that we can run on another machine)

```Dockerfile
FROM golang:1.18
WORKDIR /helloworld
ADD . .
RUN go build -o app .
CMD ["/helloworld/app"]
EXPOSE 8080
```

This simply builds a container but it includes the entire Golang runtime (which is usually unnecessary in a production environment). We can build the container but running the following command:

```bash
docker build -t naive-app -f Dockerfile .
```

## Using Slim Dockerfile

The first level of reduction that can be done would to simply use a debian or ubuntu container image. However, we can simply just to the "slimmed" down version of such images by using the "slim" editions of it - this can be done by simply using the slim tag - refer to the Dockerfile definition below.

```Dockerfile
FROM golang:1.18 as builder
WORKDIR /helloworld
ADD . .
RUN go build -o app .

FROM debian:bookworm-slim
RUN apt update && \
    apt install -y ca-certificates && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080
```

The important thing to note here is the need to update the `ca-certificates` apt package. If we skipped the installation of `ca-certificates` package, we will face the following issue:

```bash
2023/08/07 16:41:43 Hello world sample started.
2023/08/07 16:41:49 Start DoHTTPReq
2023/08/07 16:41:49 Attempting to query the following url https://www.github.com
2023/08/07 16:41:49 unable to get data from url Get "https://www.github.com": x509: certificate signed by unknown authority
2023/08/07 16:41:49 End DoHTTPReq
```

The application cannot query https endpoints since they don't have the updated global ca-certifactes - it cannot establish the chain of trust of modern of websites. Once we update `ca-certificates` - this becomes a non-issue.

We can build the docker image by running the following command:

```bash
docker built -t slim-app -f slim.Dockerfile .
```

## Using alpine Dockerfile

The next level of cutting the size of container images down would be using the alpine set of images. Alpine images are generally well known as a set of images that is usually smaller than the ones containers of the official linux distributions such as debian or ubuntu or centos?

Refer to the following Dockerfile definition:

```Dockerfile
FROM golang:1.18 as builder
WORKDIR /helloworld
ADD . .
RUN go build -o app .

FROM alpine:3.16
RUN apk add gcompat
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080
```

The important step would be the following line:

```Dockerfile
RUN apk add gcompat
```

It is important for us to understand the usual "c" tooling that Golang relies is not available here. By default, Golang actually builds and relies on glibc - it kind of depends on it for networking etc. Alpine doesn't have the glibc stuff - it has musl instead - which is different enough to the point that compiled binaries that rely on glibc will not run on musl. If we didn't add that line, we will face the following issue:

```bash
exec /helloworld/app: no such file or directory
```

A further explanation on this can be found on this link:

https://stackoverflow.com/questions/66963068/docker-alpine-executable-binary-not-found-even-if-in-path

Alternatively, we can simply build the binary without CGO by setting it to disabled and then embed it into the alpine base container image. It should work with little to no issue here.

```Dockerfile
FROM golang:1.18 as builder
WORKDIR /helloworld
ADD . .
RUN CGO_ENABLED=0 go build -o app .

FROM alpine:3.16
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080
```

To build the container, we can do so by running the following command:

```bash
docker build -t alpine-app -f alpine.Dockerfile .
```

## Additional Info on Golang and Glibc

On a side note, as another proof that default Golang compilation kind of depends on Glibc is to build the following Dockerfile with the application mentioned in the github link:

```Dockerfile
FROM golang:1.20 as builder
WORKDIR /helloworld
ADD . .
RUN go build -o app .

FROM debian:jessie-20170606
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080
```

When we attempt to start the application from the built image, we would face the following issue:

```bash
/helloworld/app: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.32' not found (required by /helloworld/app)
/helloworld/app: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by /helloworld/app)
```

If we built the Golang library without cgo

```Dockerfile
FROM golang:1.20 as builder
WORKDIR /helloworld
ADD . .
RUN CGO_ENABLED=0 go build -o app .

FROM debian:jessie-20170606
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080

```

It would work as normal

## Using distroless Dockerfile

The final frontier for cutting out the unnecessary stuff from the container and simply focus on the application just having the small necessary stuff to run it would be to rely on Distroless base images. Distroless base images are the most minimalistic container images that almost has nothing within it - and that includes not having a shell - which makes debugging really really difficult. But then again, do you need really need debugging tooling in production settings? - shouldn't we use obsevability tools to ensure that we know what's happening with our application?

Here is a Dockerfile that relies on Distroless base images

```Dockerfile
FROM golang:1.18 as builder
WORKDIR /helloworld
ADD . .
RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/static-debian11:nonroot
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080

```

Refer to the following github repo for more information with regards to distroless images: https://github.com/GoogleContainerTools/distroless

We can simply follow the instructions and examples from the distroless github link - one can assume that it is has a somewhat similar structure as Alpine images except it is a "stripped" down version of it.

We can build the container by running the following command:

```bash
docker build -t distroless-app -f distroless.Dockerfile .
```

## Quick comparisons

Once we build all the containers from the above Dockerfiles, we can finally compare the sizes and see the benefits that we gain by using the right base images so that we can create smaller images.

```bash
naive-app           latest      eeffd65a394a    54 seconds ago      972MB
distroless-app      latest      c5d38cc0c66e    2 hours ago         9.34MB
alpine-app          latest      988b265abc84    2 hours ago         15.1MB
slim-app            latest      e785101ac2c8    2 hours ago         91.5MB
```

From the above, distroless images are the smallest, followed by alpine and then slim based images. Slim images are way better that the first naive approach of building the container and using the base image that contains the Golang runtime.

Although having smaller footprint for container size, we should also realize the dificulty when dealing with the alpine or distroless base images. We are dealing with newer set of tooling - apt etc is not exactly available out of the box. There is a need to relearn how do things such as debugging or running networking tooling etc.
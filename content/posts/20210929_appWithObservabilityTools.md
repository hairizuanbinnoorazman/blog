+++
title = "App with Metrics, Logs and Distributed Traces"
description = "Sample application that has metrics, logs and distributed traces that will be gathered"
tags = [
    "google cloud",
    "kubernetes",
]
date = "2021-09-29"
categories = [
    "google cloud",
    "kubernetes",
]
+++

In a previous post, it details some information of how to setup some open source tooling to capture logs, retrieve metrics as well as capture distributed trace information from apps. The previous blog post would cover the setup of logging system which is Loki, distributed tracing system which is Tempo and metrics collection system which is Prometheus. Refer to the link below here.

[Setting up observability tooling in GKE](/setting-up-observability-tooling-in-gke/)

In order to have all this operating information be captured, applications need to be "instrumented" to expose all of this information. I'm mostly familiar with Golang so I will be providing code samples of how a sample app that is instrumented in Golang may look like. Each of these operational information is collected in different ways. For metrics, it is mostly done via pull approach where there would be a probe by Prometheus on a specified endpoint on the application on a specified schedule (usually known to be the "agentless" approach). For logs, log information is written to local files that is managed by the container tool which would then be fetched and pushed by an agent - in the case of the setup from the previous blog, would be promtail. For distributed traces, we would embed some library (mostly Jaeger which used to be the defacto way of collecting traces) and that library would contain some functionality on how to push the traces over the wire to the distributor trace collector's endpoints.

Here is a sample codebase of how this can be done:  
https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/fullObservability

The codebase will continuously be updated as time goes by - there are news of [https://github.com/open-telemetry](https://github.com/open-telemetry) which could be used as a one stop alternative to manually instrumenting each of these information one at a time. However, at the time of writing this, there still seems to be heavy development work for this, so it might be worth to wait further down the line to see how things go. Also, for companies that are already working in the space, I would expect that many of them have already used older libraries/systems such as prometheus libraries/jaeger libraries rather than opentelemetry libraries and I expect it would take a while before the transition happens.

## Application Basics

The application is a simple API server that just sleeps and then returns a OK response to a querier. It can be configured such that the API server would call other underlying application's API server as well. As of now configuration is done via environment variables. This would provide some kind of simple control of how applications can be set to with some sort of application dependencies between applications. Future iterations could be altered such that the configurations can be set via yaml/json configs passed in via Kubernetes Configmaps.

There are also other "administrative" portions of application building that would also need to be created which would be the healtcheck and readiness probes. These probes would indicate the health of the application (whether its stuck in processing and is unable to process any item further etc). These endpoints need to be created and made available to accessed when deployed in GKE. The endpoints that are created for this purpose are `/healthz` and `/readyz` endpoints.

## Metrics - Monitoring

There isn't much to monitor in such a simple application; the only easy one would be no of requests that the application receives - not counting the `/healthz` and `/readyz` endpoints.

```golang
var (
	requestsTotal = promauto.NewCounter(prometheus.CounterOpts{
		Name: "requests_total",
		Help: "The total number of processed events",
	})
)
```

## Logging

In order to make it "easier" for analysis - logs are configured to be written in JSON format using the logrus golang library. There is a JSON formatter that comes along with it; so we'll just need to "switch it on"

## Distributed traces

In order to make it easier to manage distributed traces, it would be best to just follow what the client library has in terms of controlling the collection of such traces. Refer to the Jaeger library that was used for this app here: https://github.com/jaegertracing/jaeger-client-go. The README of the repo contains the environment variables that can be read and used to manipulate the collection of the trace data. Examples of how else to initialize the Jaeger collector can be found here: https://github.com/jaegertracing/jaeger-client-go/blob/master/config/example_test.go

```golang
cfg, err := jaegercfg.FromEnv()
```

Future iterations of this sample application may be modified to ensure that metrics when collecting traces is also collected. We would want to monitor that traces are successfully sent to collector and not failing due to amount of traces being generated.

The environment variables that are to be used to control how the distributed trace data can be collected would eventually be definted within the Kubernetes manifest files. This would be covered in the Deployment section of this blog post.

## Deployment

Application will of course be deployed into a Kubernetes Cluster. We would need to have a Dockerfile which would be used to build the docker images or OCI images. The built images will then be pushed into Google Container Registry which would serve as a container store for GKE.

To deploy and run the containers in the cluster, we would rely on simple Kubernetes manifest yaml files. To templatize parts of it, we would utilize Kustomize. With Kustomize, we can then specify which images to be used and that would be injected into the manifest files before applying it into the cluster.

A large part of the Kubernetes manifest files would be defining the environment application that would be control the behaviour of the application as well as distributed trace collection etc.

```yaml
          env:
            - name: WAIT_TIME
              value: "1"
            - name: TARGET
              value: "MIAO"
            - name: SERVICE_NAME
              value: app2
            - name: CLIENT_URL
              value: "http://app3:8080"
            - name: JAEGER_AGENT_HOST
              value: tempo-tempo-distributed-distributor
            - name: JAEGER_REPORTER_LOG_SPANS
              value: "true"
            - name: JAEGER_SAMPLER_TYPE
              value: const
            - name: JAEGER_SAMPLER_PARAM
              value: "1"
```

Environment variables that prefix with `JAEGER` are related to the distributed traces collection. `WAIT TIME` refers to how long before the API responds. `SERVICE_NAME` is as it refers - which is to flag to the various services the name of the service - name is passed to distributed trace. `CLIENT_URL` refers to potential endpoint that this service should call before returning to the caller. For actual logic, please refer to the code base.

Within the `makefile`, there are a couple of convenience functions that can be used to serve as convenience command. They can be used to build the images, push the images to the container registry as well as deploy said images into the GKE cluster. The makefile has already been configured to accept params such as `VERSION` to specify version of image to be built and push.

```bash
make build VERSION=0.0.5
make push VERSION=0.0.5
make deploy VERSION=0.0.5
```
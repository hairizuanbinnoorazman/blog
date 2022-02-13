+++
title = "Kubernetes Ingress for applications with branded links on GKE"
description = "Kubernetes Ingress for applications with branded links on GKE - demonstration done with Golang aplication"
tags = [
    "golang",
    "kubernetes",
    "google-cloud",
]
date = "2022-02-13"
categories = [
    "golang",
    "kubernetes",
    "google-cloud",
]
+++

While dealing with branded links during my course of work, I kind of wondered how it can be tackled if I were to do it in a Google Kubernetes Engine Cluster. The situation I would imagine that would need to solve is this:

- The application is to be deployed via Helm Chart
- Maybe due to legal/business reasons, it has been arranged such that 1 copy of the application will only 1 customer. So if we have 5 customers, we would need to deploy the above Helm Chart 5 times with different configurations that are accustomed to each customer.
- We don't want to handle too many clusters as it will cause too much overhead for maintainence and cost of running 1 cluster per customer (we would also need to manage monitoring etc). It would be best to deploy all those applications to 1 single cluster and then have some sort of mechanism to redirect customer to their specific pod on the cluster.
- Each customer will access the application with their own branded link. It has been previously arranged such that each customer can purchase their own domain and by accessing that domain, they should able to access the application deployed on that cluster.

## Deploying separate charts with different configurations

As an example, we can try deploying the following application from this repo: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicHelm

The reason for proposing to test with the following application is that we can alter the environment variable `TARGET` within the helm chart to simulate different configurations of the applications. The application will return the value of `TARGET` in its response - so by altering it, we can have the same application but its behaviour slightly made different.

We can build the docker image for this and prep it to be used by Google Kubernetes Engine by running the following commands:

```bash
# Replace the XXXX with your own project ID
docker build -t gcr.io/XXXX/yahoo:v1 .
docker push gcr.io/XXXX/yahoo:v1
```

To change the config file - alter the value of the environment value of `TARGET` in the `deployment.yaml` file of the helm chart with the `basic-app` folder. Once done, we can deploy it via the following command:

```bash
# Assume that the environment value of TARGET was changed to yahoo
helm upgrade --install yahoo ./basic-app

# Assume that the environment value of TARGET was change to lola
helm upgrade --install lola ./basic-app
```

This should hopefully get the application to run. The initial version of the chart sets the replica count to 5 - so maybe this might be too high for an example use case; you might want to adjust it to a lower replica count value.

```bash
kubectl get pods
```

Response of the above command:

```bash
NAME                               READY   STATUS    RESTARTS   AGE
lola-basic-app-6957f859cf-4cw98    1/1     Running   0          3h41m
lola-basic-app-6957f859cf-85n5d    1/1     Running   0          3h41m
lola-basic-app-6957f859cf-gqqjp    1/1     Running   0          3h41m
lola-basic-app-6957f859cf-jz5zn    1/1     Running   0          3h41m
lola-basic-app-6957f859cf-mnsnm    1/1     Running   0          3h41m
yahoo-basic-app-7bfcc945d7-65tkf   1/1     Running   0          4h3m
yahoo-basic-app-7bfcc945d7-j2br9   1/1     Running   0          4h3m
yahoo-basic-app-7bfcc945d7-pzjlr   1/1     Running   0          4h3m
yahoo-basic-app-7bfcc945d7-qljcm   1/1     Running   0          4h3m
yahoo-basic-app-7bfcc945d7-snxhf   1/1     Running   0          4h3m
```

To check that the application is somewhat running properly, we can "exec" into a container and run some commands to make sure it kind of works (don't forget that the application deployed here allows one to do so. Other production ready applications out there are usually configured to not allow this to improve the security posture of deploying such containerized applications.)

```bash
kubectl exec -it yahoo-basic-app-7bfcc945d7-snxhf -- /bin/bash
```

Once inside the container, we can run the following command:

```bash
curl localhost:8080/
```

We would probably get the following response:

```bash
root@yahoo-basic-app-7bfcc945d7-snxhf:/home# curl localhost:8080
Hello World: Yahoo!
```

With that, we can proceed to the next step of externalizing the application.

## Single entry point

There many ways to fulfil the above situation. One way is to create 1 load balancer per customer in Google Cloud. Unfortunately, doing that might not be most wise - having 1 load balancer is already above $10-$15 (may vary). The price overhead might be a little high if we are to run it by that approach. 

Another approach is to use Kubernetes Ingress - under the hood, it would set up a single Load Balancer and that single load balancer will be used to set up the various incoming traffic (ingress) rules and how to treat each incoming traffic.

You can see an example of such an ingress (We can have multiple ingress definition yaml files - Kubernetes is able to combine them). The following ingress file is used to define 2 branded domains that customers can access.

```yaml
# Save the file as all-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
spec:
  rules:
    - host: yahoo.example.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: yahoo-basic-app
              port:
                number: 8080
    - host: lola.example.com
      http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: lola-basic-app
              port:
                number: 8080
```

We get the services of where to send the traffic from ingress by inquiring the services on Kubernetes

```bash
kubectl get services
```

Response for the above command:

```bash
NAME              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
kubernetes        ClusterIP   10.116.0.1     <none>        443/TCP    4h55m
lola-basic-app    ClusterIP   10.116.1.211   <none>        8080/TCP   3h53m
yahoo-basic-app   ClusterIP   10.116.6.9     <none>        8080/TCP   4h50m
```

We will apply the ingress rules to the Kubernetes cluster by running the following command

```bash
kubectl apply -f all-ingress.yaml
```

Once applied, we can check the state of ingress.

```bash
kubectl get ingress
```

Note that for GKE, it will take above 2-5 minutes for IP to come up on Address field. Under the hood, GKE actually contacts Google APIs to create 1 load balancer on our behalf and then apply the rules to said Load Balancer. It would then attempt and work to ensure that ingress rules are synced up to the load balancer.

```bash
NAME           CLASS    HOSTS                                ADDRESS         PORTS   AGE
test-ingress   <none>   yahoo.example.com,lola.example.com   34.111.138.89   80      175m
```

## Testing

In order to test this out, we can then add the address of the ip address that was assigned for this to our `/etc/hosts` file (not sure if there is anything similar for windows. We're trying to assign an ipaddress to a domain name)

```bash
34.111.138.89 yahoo.example.com
34.111.138.89 lola.example.com
```

Append the above to the mentioned file. Be careful when handling this file, other programmes could have added entries to the file and manipulating the `/etc/hosts` file without any care may cause issues with said programmes. You can try avoiding this by making a backup of the `/etc/hosts` file just in case. If things go south, you can replace the altered `/etc/hosts` with the backup file.

We can now run curl on domains `yahoo.example.com` and `lola.example.com` and it should be able to return an expected response from the deployed application

```bash
curl yahoo.example.com

# Response
# Hello World: Yahoo!                       
```

```bash
curl lola.example.com

# Response
# Hello World: Lola!
```
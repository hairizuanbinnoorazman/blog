+++
title = "Python Flask Apps in GKE"
description = "Python Flask Apps in GKE. Showing how python microservices are deployed and tested"
tags = [
    "google cloud",
]
date = "2021-04-18"
categories = [
    "google cloud",
]
+++

This are some notes in the case where one wants to deploy a bunch of python "microservices" to a GKE cluster. These notes emphasize on the basics rather than the various nuances of running a "production" grade python application.

This is our python flask application that we would deploy - a simple flask app

```python
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, World!\n'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

To run the flask app, it would be best to have some form of requirements file to handle the various dependencies

```
click==7.1.2
Flask==1.1.2
itsdangerous==1.1.0
Jinja2==2.11.3
MarkupSafe==1.1.1
Werkzeug==1.0.1
requests==2.25.1
```

Since we're deploying it to GKE, we would need to create a container out of it. So this would be dockerfile for it

```Dockerfile
FROM python:3.6
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD python sample-flask-app.py
```

To deploy such an application to GKE, we can run the following commands. (Once we have our GKE cluster and we have connected to it - our kubectl tool can access and query/modify the cluster accordingly)

```bash
# Building the image
docker build -t sample-app .

# After building, we would to test that the app works as expected as well
docker run -p 8080:8080 -d sample-app 

# Retag the image for Google Container Registry
docker tag sample-app gcr.io/XXX/sample-app:v1

# Push to Google Container Registry
docker push gcr.io/XXX/sample-app:v1

# Create a "deployment" in GKE
kubectl create deployment sample-app --image gcr.io/XXX/sample-app:v1

# Create a "service" in GKE
# Wait for the ip address and curl against it
kubectl create service loadbalancer sample-app --tcp=80:8080
```

Now that we have the most basic setup working. Let's instead move to a scenario where we have multiple python services. We have one python service calling our `sample-app` python service as previously mentioned

```bash
# Delete load balancer service
kubectl delete service sample-app

# Create internal ip - we don't want to expose it this time
kubectl create service clusterip sample-app --tcp=8080:8080

# Check response and can access it
kubectl create deployment test --image=nginx
kubectl exec -it <pod-name> -- /bin/bash

# Inside the container
apt update
apt install dnsutils
nslookup sample-app
curl sample-app:8080
```

We now know what is the address to contact our sample app is on, let's embed it into our second application. Note: It is actually better to make this one configurable in order to allow operators of the application to change the address if needed. If this wasn't done, that would mean we would need to rebuild the app each time that is address update of the sample-app service


```python
from flask import Flask
import requests

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'First Service!\n'

@app.route('/main')
def first_service_handler():
    resp = requests.get("http://sample-app:8080")
    return resp.text

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

This is the dockerfile for it. It uses the same requirements.txt file as above

```Dockerfile
FROM python:3.6
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD python first-service-app.py
```

How do we test it locally though?

We would generally utilize docker-compose here since it's pretty troublesome to understand and go through the whole docker networking stack to get something up and running between the various services

If we are to simulate the above in a docker-compose setup

```docker-compose
version: "3.5"
services:
  "sample-app":
    build:
      context: .
    ports:
      - "8080:8080"
  "first-service":
    build: 
      context: .
      dockerfile: first-service.Dockerfile
    ports:
      - "8081:8080"
```

Note the weird issue here when using it in Google Cloud Shell: https://github.com/google-github-actions/setup-gcloud/issues/128

```bash
export LD_LIBRARY_PATH=/usr/local/lib
```

To get all the python services above to run locally, we can run the following commands:

```bash
# To bring all the services up
docker-compose up

# To bring it all down
docker-compose down
```

With local testing out of the way, let's now focus on deploying the `first-service` application

```bash
# Build the first service docker image
docker build -t gcr.io/XXX/first-service:v1 -f first-service.Dockerfile .

# Push the first service docker image
docker push gcr.io/XXX/first-service:v1

# Deploy service
kubectl create deployment first-service --image=gcr.io/XXX/first-service:v1

# Create load balancer to have traffic go to it
kubectl create service loadbalancer first-service --tcp=80:8080
```
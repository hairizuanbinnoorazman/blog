+++
title = "Accessing Google Compute Instances via Cloud Run"
description = "Accessing Google Compute Instances via Cloud Run without Serverless VPC Access"
tags = [
    "docker",
    "google-cloud",
    "python",
]
date = "2023-08-30"
categories = [
    "docker",
    "google-cloud",
    "python",
]
+++

The typical way to access Google compute instances from Cloud Run is usually done via the Serverless VPC Access. However, setting this up would mean that we are essentially create an instance that would be used as a proxy to send traffic from Cloud Run to the Google Compute instance.

Things have changed quite a bit now. We no longer need this; we can now connect directly to Google Compute Instance without Serverless VPC Access. This would be the best page reference for this: https://cloud.google.com/run/docs/configuring/vpc-direct-vpc

This would be the flask app that we would use to test this functionality

```python
from flask import Flask
import requests
import logging

app = Flask(__name__)

@app.route("/access-instance")
def access():
    try:
		# TODO: Allow this to be configurable externally
        resp = requests.get("http://10.128.0.30")
        logging.info(resp.status_code)
        return "<p>" +  resp.text + "</p>"
    except Exception as e:
        logging.error(e)
        return "<p>Failed to access isntance 1</p>"


@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"
```

The root endpoint is simply to allow us to check that the application is working as expected. For `/access-instance` endpoint - it will be the endpoint that would reach out to Google Compute instance. It'll be good to point out here that the ip address above should be something that you would need to configure - it'll be the private IP address that is assigned to your created google compute instance.

Naturally, for Google Cloud Run instances, we would need Docker images as well - which would naturally mean, we need Dockerfiles

```Dockerfile
FROM python:3.11.7-slim-bookworm
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY hello.py .
CMD ["flask", "--app", "hello", "run", "--host", "0.0.0.0"]
```

To run our flask application, we would need the `flask` and `requests` python library. This would be defined in `requirements.txt` file.

```text
flask
requests
```

To push our image to our registry, we can run the following commands:

```bash
docker build -t gcr.io/xxx/flask-test:0.0.1 .
docker push gcr.io/xxx/flask-test:0.0.1
```

We can then go to Google Cloud Console to create our Google Cloud Run services as usual. Some of the properties that we need to set would be:

- Which container that our Google Cloud Run instance would use?
- Maximum number of instances that our Cloud Run scale to
- Set that Google Cloud Run service to be accessible without authentication externally (for easier testing)

However, the most important configuration to set is the networking section. We would simply need to set the flask tester's networking section to be able to access a VPC - if our google compute instance is in the Default VPC.

![create-flask-tester](/20230830_cloudRunToVPCInstance/create-flask-tester.png)

After the configuration work, we should something like this in the networking tab.

![cloud-run-network](/20230830_cloudRunToVPCInstance/cloud-run-network.png)

The next part is simply to do the following:

- Create a google compute instance in the VPC that we set in our Google Cloud Run (we can technically create this before we create our Google Cloud Run VPC - they're not totally dependent on each other). For convenience to go into the server to configure it, we can just set it to have public ip address
- On our google compute instance, install nginx - which is a convenient http server that would immediately provide an endpoint that we can connect to (without writing up some server code)
- Use the Google Cloud Run endpoint that's automatically generated and access the `/access-instance` endpoint to check that we're receiving the traffic properly and is able to get the result as expected.

With that, we have a small demo to demonstrate and figure out how this feature works here.

However, there are a few things to take note or figure out for future blog posts:

- The following blog post talk about how a Cloud Run accesses a Google Compute Instance. Apparently, we're accessing it via IP address - which is technically not ideal. In most cases, IP addresses for Google Compute instances are randomly assigned (unlikely we use static ip addresses). Might be good to figure out a way where we can try to access it by name instead. However, this might not be needed since if we're talking about a service in virtual machines that can scale, we would need it behind a load balancer after all. Maybe there should be a blog that explores of how we can connect Google Cloud Run to an internal load balancer where a couple of virtual machines sit behind it.
- We only mention about how Google Cloud Run can connect to Google Compute instance but not the other way round. That is probably a topic for another time to talk about how we can connect from Google Compute instance to a Google Cloud Run service.
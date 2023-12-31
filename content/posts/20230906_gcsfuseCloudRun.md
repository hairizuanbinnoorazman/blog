+++
title = "Persistance in Google Cloud Run with FUSE storage to Google Cloud Storage"
description = "Persistance in Google Cloud with FUSE storage to Google Cloud Storage"
tags = [
    "docker",
    "google-cloud",
    "python",
]
date = "2023-09-06"
categories = [
    "docker",
    "google-cloud",
    "python",
]
+++

Google Cloud Run is a serverless compute platform that automatically scales applications in response to traffic. It is designed to run stateless containers, meaning that the instances of your application are ephemeral and can be spun up or down as needed. This design choice has implications for data storage, particularly when it comes to persistence.

One notable limitation of Google Cloud Run is that it doesn't have built-in persistent storage. Each instance of a Cloud Run service operates independently and is stateless. When an instance is scaled down to zero or replaced by a new one, any data stored locally on that instance is lost.

However, not all applications can conform to the nature of being completely stateless where data doesn't need to be stored. Some still require the data to be stored somewhere on disk, which is where conveniently enough - we can setup some of "fake" filesystem which some of these application can take advantage of. Refer to the following details: https://cloud.google.com/run/docs/tutorials/network-filesystems-fuse

## Building the application and include fuse in it

We can have a simple python app that would create on "disk". Here is one example of such an app

```python
from flask import Flask
from datetime import datetime
import os

app = Flask(__name__)

@app.route("/create")
def access():
    value = datetime.now()

    if os.getenv("FOLDER") is not None:
        folder = os.getenv("FOLDER")
    else:
        folder = "/app/"

    file_location = folder + value.strftime("%Y-%m-%d-%H-%M-%S")

    try:
        with open(file=file_location, mode='w') as file:
            file.write(str(value))
        return "the following file is created: {}".format(file_location)
    except Exception as e:
        print(e)
        return "unable to create file. check logs for error"

    

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"
```

On calling the `/create` endpoint, it would simply create some files with dates printed in it.

For the `requirements.txt`, we would only need the flask module.

```text
flask
```

Here is the dockerfile for our application. Note that we're simply following the guide from the above url - which is to use the `tini` utility tool.

```Dockerfile
FROM python:3.11.7-slim-bookworm
RUN apt-get update && apt-get install -y curl gnupg lsb-release tini && \
    gcsFuseRepo=gcsfuse-`lsb_release -c -s` && \
    echo "deb https://packages.cloud.google.com/apt $gcsFuseRepo main" | \
    tee /etc/apt/sources.list.d/gcsfuse.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key add - && \
    apt-get update && \
    apt-get install -y gcsfuse && \
    apt-get clean
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY hello.py .
COPY gcsfuse_run.sh .

# Set fallback mount directory
ENV MNT_DIR /mnt/gcs
ENV BUCKET hairizuan-cloud-run-gcsfuse

# Ensure the script is executable
RUN chmod +x /app/gcsfuse_run.sh

# Use tini to manage zombie processes and signal forwarding
# https://github.com/krallin/tini
ENTRYPOINT ["/usr/bin/tini", "--"] 

# Pass the startup script as arguments to Tini
CMD ["/app/gcsfuse_run.sh"]

```

For the running of the application, we would need to do two things:

- Start the gcsfuse binary to mount the bucket to a particular folder
- Start our python application
- Bonus points: Any SIGTERM signal sent to the shell script is actually propagated to all relevant processes

Hence, here is the shell script for it:

```shell
#!/usr/bin/env bash
set -eo pipefail

# Create mount directory for service
mkdir -p $MNT_DIR

echo "Mounting GCS Fuse."
gcsfuse --debug_gcs --debug_fuse $BUCKET $MNT_DIR 
echo "Mounting completed."

flask --app hello run --host 0.0.0.0
```

For getting the above docker image to run on Cloud Run, we would simply do the usual of building and pushing the docker image to container/artifact registry.

```bash
docker build -t gcr.io/xxx/flask-tester:0.0.1 .
docker push gcr.io/xxx/flask-tester:0.0.1
```

## Manual steps to take note

For running of our cloud run service, we would do a few things:

- Create a service account (ideally)
- Ensure that the service account has access to "Storage Object Admin" to allow the service account to be able to list and create and manipulate objects on the bucket. It also probably need the "Cloud Run Invoker" to ensure that it is able to start the Cloud Run service accordingly.
- Ensure that `FOLDER` environment is set. In the case that we aren't altering the default `MNT_DIR`, we can simply have `FOLDER` be `/mnt/gcs/`. For the above python script (would be great thing to fix for the future), we would need to add the last slash behind gcs since we aren't properly creating file paths that we can use.
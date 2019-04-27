+++
title = "Using Docker Multi Stage builds to run unit tests"
description = "Using Docker Multi Stage builds to run unit tests"
tags = [
    "python",
    "docker",
]
date = "2017-10-17"
categories = [
    "python",
    "docker",
]
+++

This is a suggestion piece and not a recommended way of using docker or anything.

## Motivation

The question we would want to know here is how do we exactly run the full on/all the unit tests for our applications built via Docker. One way to do this is to rely on a build server like Jenkins to create the required environment which we would need for a build and then run the unit test needed. However, this would mean that there is need to bootstrap a environment to do so.

## Idea 1: Embed the testing scripts into the Dockerfile for building the application

We would not be able to use the previous Dockerfile which we would have used to build the system. If we were to try to run a test command via RUN in the Dockerfile, it might be cached in future builds which we definitely don't want to happen.

Another reason not to just run the testing command in the Dockerfile used for building the application is that we might overload the docker with unnecessary files and that totally goes against one of the better practises of Docker which is to keep images small and minimal.

With that, this might be a bad way of running unit tests. I would say that this solution kind of works but it has that sense of inelegance? We would need to sacrifice the last set of layers as well as have bloated containers which would contain testing scripts and testing data in it.

## Idea 2: Create separate Dockerfiles to run tests and separate Dockerfiles for builds

We can have separate Dockerfiles in order to run tests and create the application builds. This would allow us to load up the required testing scripts and testing faux data to the testing container which can then be used to run unit tests.

However, if you think about it, if the two Dockerfiles (one for tests and one for builds) are separated that way, we would need to ensure that the environments between the two are exactly the same or else the benefits of using Docker kind of goes away with it. This would mean that we now need to have a third Dockerfile that serves as a form of "base" which we can then use to build up the testing and application Dockerfiles.

I wouldn't recommend having this though. Having three Dockerfiles sounds like a pain to maintain.

## Idea 3: Making use of Multistage builds for Docker but not for its intended purposes

If you are to read the purpose of the multistage builds feature in docker, it is really not meant for testing code. It is meant for providing users the ability to create light weight containers without adding useless files that is meant only for use in production.

The main example usually provided are Go applications. Go applications compile down to a binary and only that is needed to be able to run on the containers. You can see the example of this and benefits of it in the article below.

Multistage build for Docker
https://docs.docker.com/engine/userguide/eng-image/multistage-build/

Ok, but back to the topic. How should we use it for our scenario?

Let's first have a 2 files. A testing python script and a Dockerfile. (I would imagine it would work with other languages as well?)

**content of test_sample.py**

```python
def inc(x):
return x + 1

def test_answer():
assert inc(3) == 4
Save the file above as a test_sample.py
```

**Install pytest python library as well as add all files in current directory**

```Dockerfile
FROM python:3 as base
RUN pip install pytest
ADD . .
```

**This is the container build that will run the "unit tests"**

```Dockerfile
FROM base
RUN pytest test_sample.py
```

**This is the container build statements that will create the container meant for deployment**

```Dockerfile
FROM base
CMD python
```

Save the file above as Dockerfile

As you can see from above, there is the concept of the three Dockerfiles as mentioned in the second idea but instead, all the statements are all in the same file. Another good thing is that it is possible to refer to intermediate builds (refer to the base which we use to build up the container to run tests and another to run for deployment)

We can run the Docker build command as follows:

```bash
docker build -t awesome_app .
```

This works! Unfortunately, the problem that was mentioned in Idea 1 will need to be mentioned here again. The test script line will be cached but we don't want it to be cached at all! It's unit tests; it needs to run every build to ensure we are hitting the minimum application spec.

We can resolve this by adding the following line to the Dockerfile, a build argument. ARG cache=1. If we adding it to our testing snippet

**Building the base image and dependencies**

```Dockerfile
FROM python:3 as base
RUN pip install pytest
ADD . .
```

**Meant for running tests**

```Dockerfile
FROM base
ARG cache=1
RUN pytest test_sample.py
```

**Meant for building the deployment container**

```Dockerfile
FROM base
CMD python
```

Instead of running the docker build command from above, we would need to alter it slightly so that it always bust the cache for the portion of the docker build process that does testing.

```bash
docker build -t awesome_app --build-arg cache=\$(date +%Y-%m-%d:%H%M:%s) .
```

This would ensure that cache is always busted accordingly.

But, if you read the docker docs, you can argue that if a cache is busted for one of the lines in the dockerfile, then the cache for the rest of the layers above it would also be busted which might mean a rebuild of the application.

Lucky for us, this does not happen. Apparently the ARG layer being busted only affected that container specified in that section of the multi stage build. To test this we can alter the Dockerfile above to the following:

**Building the base image and dependencies**

```Dockerfile
FROM python:3 as base
RUN pip install pytest
ADD . .
```

**Meant for running tests**

```Dockerfile
FROM base
ARG cache=1
RUN pytest test_sample.py
```

**Meant for building the deployment container**

```Dockerfile
FROM base
RUN pip install requests
RUN pip install flask
CMD python
```

If we are to run this continuously multiple times via the following command:

```bash
docker build -t awesome_app --build-arg cache=\$(date +%Y-%m-%d:%H%M:%s) .
```

On the initial build, there would be a install of requests and flask. Subsequently, the section of the Dockerfile that install requests and flask would keep using the ones that are already cached. And the section that runs the tests would always be rerun no matter what as the build arguments would cause the cache to be busted for each and every docker build.

Anyways, just a random thought here. I would assume that unit tests only need to run when new code is added so if I'm not wrong, the ADD should be busting the cache if that happens and all statements above that would be invalidated and need to be run. You might not need the approach mentioned here and with careful organization of the steps in the Dockerfile, it is possible to have a simpler Dockerfile.

TLDR;
Idea 3 seems to be best in terms of the following:

Keeping to a single Dockerfile rather than complicating any software project further (and the ability to run unit tests as well)

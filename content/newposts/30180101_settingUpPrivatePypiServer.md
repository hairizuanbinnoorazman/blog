+++
title = "Setting up a Private Pypi Server"
description = "Setting up a Private Pypi Server using Docker on Google Cloud Platform"
tags = [
    "google-cloud",
]
date = "3018-05-02"
categories = [
    "google-cloud",
]
+++

As one writes several python applications to be targeted on the Google Cloud Functions platform, it becomes increasingly obvious to pull out the more common bits of code out into its own library. Let's have an example on the reason for this.

Let's say you have a small function integrates with Slack APIs. It takes in json blobs and manipulate such blobs before forwarding it towards Slack. When you do your first integration with Slack with another service, it seems pretty simple and straightforward; just refer to the json being used to that service. However, after doing the integration for the fifth time, it points to the need for some sort of common code that can be used to build up the structure of json blob to be sent to the service. We need some sort of client package to do this.

There are a few benefits for having a client package; the consumers of said services does not need to look to deep of what inputs that are used to sent over. They can just import the client library and begin to use said service with relative ease as compared to the alternatives of requiring to build the clients.

## Ways to have client packages

In python, there are several ways to import packages. The most common way is to have the import packages from the public python repositories but that would only be for public packages. If one wants to have a private python packages, alternatives are to put it on pypi packages server (private), utilize private git repositories (you can install python packages from a git repository without building the python package) or hosting the python package on your pypi-server setup.

For this post, it'll explore on how to set up pyivate python package hosting with your own pypi-server setup

## Building the Sample Package

Refer to the following git repository:  
https://github.com/hairizuanbinnoorazman/local-pypi-server/tree/master/sample

With reference to packages such as `requests`, we can copy some code structures from said packages to create our sample python package. The sample package here only has one function: `sample_print_stmt`. It takes a string input and prints it out as well as returns it.

The only folder that matters here is the `sample` folder. The `sample.egg-info` as well as `dist` folders are generated while building the python package. To build the package the package, we would run the following command:

```bash
python setup.py sdist bdist_wheel
```

## Building pypi-server docker image

There is a python package that provides the capability to have the pypi server. It is availble on this repo: https://github.com/pypiserver/pypiserver. Within this repo, we can see that it also provides the Dockerfile and Docker images that would contain the pypi-server codebase to serve python packages. We can then build our required Docker image based on that.

```Dockerfile
FROM pypiserver/pypiserver
ADD ./sample/dist /data/packages
ADD ./.htpasswd /
ENTRYPOINT ["pypi-server", "-p", "8080", "-P", "/.htpasswd", "-a", "update,download", "./packages"]
```

The python packages would be served from a specified location as seen in the entrypoint section of the dockerfile. After running the build command to build the python packages, we can just add the built zipped python packages to the right directory.

In order to "protect" our python package repository, we would create a htpasswd file that would require consumers and uploaders the need to provide a username and password to the service. With the `-a` flag, we can set it such that it would require usernames and password when a update or download is happening.

We can build the container and run it accordingly.

```bash
docker build -t pyserver .
docker run -p 8000:8080 pyserver
```

With the above docker commands, we now have a local pypi-server serving python packages on port 8000.

## Using the sample package from private pypi-server

To try installing it, we can then run the following command: (I assume that you would know how to create your own virtual python environment)

```bash
pip install --index=http://localhost:8000/simple sample
```

The sample package would be installed with that. We can then try to import said package and use the function.

```python
import sample

sample.sample_print_stmt("caacc")
```

It works even with `Pipenv`. The only thing you would need to do before installing it is to add the following source after the original pypi source as an alternative source that the pip tool can use to find python package.

```
[[source]]
url = "http://localhost:8000/simple"
verify_ssl = false
name = "sample"
```

After this step, you can just run the following to install the sample package. It should not have any issues from installing or even locking it into the requirements.

```bash
pipenv install sample
```

+++
title = "Setting up a Private Pypi Server"
description = "Setting up a Private Pypi Server using Docker on Google Cloud Platform"
tags = [
    "google-cloud",
]
date = "2019-02-01"
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

## Additional thoughts

As I was sharing this with other engineers, a few mention about how using pip and pipenv tools, you can potentially just install the package directly from the git repository by itself. This is possible and can be done for both public and private python git repositories.

However, after doing a few quick tests on this, I kind of realized that installing python packages via this way will lead to me losing intellisense for the entire package when I am coding it in Visual Studio Code. (Not sure about other editors, didn't exactly try them). For a small package, the lost of intellisense while coding might be ok but if this was a big package; this is gonna be a huge drawback. I'm currently heavily reliant on this intellisense systems and if its not able to point the next possible direction which I can take my code in, it'll just hamper my progress significantly.

Another minus point for installing python packages directly from git repositories is that they don't seem to install package sub-dependencies alongside the targeted package. Take an example `pandas`. The `pandas` python library is heavily dependent on a `numpy` python package. However, if you try to install directly via git repositories, this error would come up:

```bash
Obtaining pandas from git+https://github.com/pandas-dev/pandas#egg=pandas
  Cloning https://github.com/pandas-dev/pandas to /Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/src/pandas
    Complete output from command python setup.py egg_info:
    Traceback (most recent call last):
      File "/Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/lib/python3.7/site-packages/pkg_resources/__init__.py", line 357, in get_provider
        module = sys.modules[moduleOrReq]
    KeyError: 'numpy'

    During handling of the above exception, another exception occurred:

    Traceback (most recent call last):
      File "<string>", line 1, in <module>
      File "/Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/src/pandas/setup.py", line 737, in <module>
        ext_modules=maybe_cythonize(extensions, compiler_directives=directives),
      File "/Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/src/pandas/setup.py", line 480, in maybe_cythonize
        numpy_incl = pkg_resources.resource_filename('numpy', 'core/include')
      File "/Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/lib/python3.7/site-packages/pkg_resources/__init__.py", line 1142, in resource_filename
        return get_provider(package_or_requirement).get_resource_filename(
      File "/Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/lib/python3.7/site-packages/pkg_resources/__init__.py", line 359, in get_provider
        __import__(moduleOrReq)
    ModuleNotFoundError: No module named 'numpy'

    ----------------------------------------
Command "python setup.py egg_info" failed with error code 1 in /Users/XXX/.local/share/virtualenvs/url-checker-VRYs4T2O/src/pandas/
```

I'm guessing that during python packaging, it does some work to inform the `pip` tool regarding the dependencies of the package as well.

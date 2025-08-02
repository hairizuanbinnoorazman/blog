+++
title = "Container Signing Experimentation"
description = "Container Signing Experimentation"
tags = [
    "google-cloud",
    "devops",
    "docker",
]
date = "2025-07-31"
categories = [
    "google-cloud",
    "devops",
    "docker",
]
+++

One of the major things that I was researching on for security stuff for distributing software is the capability to answer "is this software produced from your company"? This led me to a rabbit hole for the signing mechanism for containers. The signing mechanism is somewhat similar to us install packages from rpm or deb repos for the various linux repos - there is a need to ensure that the package received is truly from the correct source.

I once saw about a "Notary" tool for containers but apparently - Notary V1 is no longer a recommended tool. There are tools such as `cosign` and `notation` but a quick search on Google and ChatGPT kind of seem to indicate that `cosign` might be a better tool for now.

This post kind of commands to try to the signing of the containers and move the containers between different registries.

We need to install 3 main tools here:
- docker (container runtime to run docker)
- skopeo (mostly just copying container between registries)
- cosign (for signing containers)

```bash
# Start 2 different registries
docker run -d -p 5000:5000 registry
docker run -d -p 5001:5000 registry

# Pull nginx container and push to our local registry
docker pull nginx:latest
docker tag nginx:latest localhost:5000/nginx:latest
docker push localhost:5000/nginx:latest

# Sign the container on registry 1 (the one that is exposed via port 5000)
cosign sign --key cosign.key --tlog-upload=false localhost:5000/nginx:latest

# Copy the container from registry 1 to registry 2
skopeo copy --dest-tls-verify=false --src-tls-verify=false \
    docker://localhost:5000/nginx:latest \
    docker://localhost:5001/nginx:latest

# Copy the container signature from registry 1 to registry 2
skopeo copy --dest-tls-verify=false --src-tls-verify=false \
    docker://localhost:5000/nginx:sha256-3651f5785567a226fd58e33adcfb27b41a83ba0c3649d9ee9ac590acd97bad51.sig \
    docker://localhost:5001/nginx:sha256-3651f5785567a226fd58e33adcfb27b41a83ba0c3649d9ee9ac590acd97bad51.sig

# Verify the container signature of the pushed nginx container straight on registry 2
# Note that we didn't sign the container on registry 2
cosign verify --key cosign.pub --insecure-ignore-tlog=true localhost:5001/nginx:latest
```

## Issue with Skopeo

I first tried to install the skopeo via plain old apt. However, i faced the following issue.

```bash
FATA[0000] creating an updated image manifest: preparing updated manifest, layer "sha256:803acddaac35131e459cb398d6c900b136afec849b1dcb6e4d14c5a27569cdad": unsupported MIME type for compression: application/vnd.dev.cosign.simplesigning.v1+json 
```

Apparently, main cause of this is due to version - apparently, a newer version of skopeo won't face this issue. My WSL2 environment is `VERSION="22.04.2 LTS (Jammy Jellyfish)"`. Only installs skopeo version 1.4.1

Apparently, it doesn't seem to be possible to install the skopeo tool directly. The only way it seems to clone the repo and build the tool on my own machine - static building looks to troublesome, so we will try to rely on the binary that is dynamically linked to the packages on my machine

```bash
sudo apt install libgpgme-dev libassuan-dev libbtrfs-dev pkg-config
# Cannot use this one - seems like this causes the build to happen to a container
# However, build it a container results in it linking to a newer glibc - mine is older
# sudo make binary
# Use the following make command instead
sudo make bin/skopeo

sudo mv bin/skopeo /usr/local/bin/
sudo chmod +x /usr/local/bin/skopeo
```
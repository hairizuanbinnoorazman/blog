+++
title = "Private Go Modules in Google Cloud Build"
description = "Setting up a CI/CD modules for Go projects that utilize private Go modules in Google Cloud Build"
tags = [
    "google-cloud",
    "golang",
]
date = "2019-03-01"
categories = [
    "google-cloud",
    "golang",
]
+++

So recently, I've been needing to automate my builds for my few Golang projects via Google Cloud Build. However, rather than building docker containers, I needed Golang binaries instead, which kind of meant that I would need to have the CI/CD pipeline have a Go environment/runtime to build them. However, when it comes to these CI/CD solutions, including private Golang packages/modules in siad projects is usually quite troublesome. Private Golang packages usually take the code from private Github/Bitbucket/Gitlab repos and getting the `go get` command to fetch them successful require a bit of hacks here and there to make it work successfully.

Let's go over an example of how to get this done:

## Creating a private golang package

We can have a private golang module that consist of this. This repo needs to be a private repo in any of the public git repository systems e.g. github, gitlab or bitbucket. In my case, I was trying with gitlab; didn't try with the other git providers.

**Note: This example uses go modules, so I believe you would need at least go1.11 and above**

Let's call this file: `fakecars.go`

```go
package fakecars

import (
	"fmt"
	"time"
)

// FakeCar represents a vehicle that can be used to modify cars
type FakeCar struct {
	RegistrationNum string
	Wheel           int
	Country         string
	Date            time.Time
}

// NewFakeCar creates a new vehicle. One needs to provide a registration number for use
func NewFakeCar(registerNum string) (FakeCar, error) {
	return FakeCar{
		RegistrationNum: registerNum,
		Wheel:           4,
	}, nil
}

// Valid checks whether the vehicle is a valid vehicle that can be used
func (f *FakeCar) Valid() error {
	if f.Wheel < 2 {
		return fmt.Errorf("No vehicle can have less have than 2 wheels")
	}
	return nil
}
```

This file is generated when we call `go mod init gitlab.com/hairizuanbinnoorazman/fakecars`
This file is called `go.mod`

```bash
module gitlab.com/hairizuanbinnoorazman/fakecars
```

With all that, we would have created a golang private package called `fakecars`

## Consuming it in a project

We can create the "main" project in another repo. This project would call the private project and its function within its code base. This example project would be called fakegarage

Let's call this `main.go`

```go
package main

import (
	"fmt"

	"gitlab.com/hairizuanbinnoorazman/fakecars"
)

func main() {
	fmt.Println("Yea!!")
	hehe, _ := fakecars.NewFakeCar("kjanjcnajkcn")
	fmt.Printf("%+v", hehe)
}
```

If this is also going to be a private project, then this too will require `go mod init XXX`

```bash
module gitlab.com/hairizuanbinnoorazman/fakegarage
```

The next step is to actually run `go get ...` commands in order to retrieve the modules needed to build this project. You can't just run `go get gitlab.com/hairizuanbinnoorazman` just like that because the tool will actually stop at attempting to authenticate. The go get tool's default is set such that the terminal prompts are disabled. One way to do so is to run with the following command:

```bash
env GIT_TERMINAL_PROMPT=1 go get gitlab.com/hairizuanbinnoorazman/fakecars
```

For some odd reason, this works/doesn't work consistently. With this command, it would prompt you to key in your username and password multiple times and end up failing for the first time. However, if one tries again, it would suddenly work fine; I'm not too sure why but then again, this post is not meant to explore why this happens. This would be for linux environments.

On OSX machines, the credential helper would come in to help with authenticating to private git repository, so on the initial set of the environment variable above, the package would installed without requiring to keep keying in the username and password values over and over again.

The more 'official' stance from many other blog posts/guides out there is to actually do the following instead:

- Generate a ssh key with the command: `ssh-keygen -o -t rsa -b 4096 -C "XXX@gmail.com"`
- Add the ssh key as deploy keys to the fakegarage and fakecars project
- Run the following command: `git config --global --add url."git@gitlab.com:".insteadOf "https://gitlab.com/"`. This would result in the private packages being called via ssh rather than over https. That would allow you to skip user authentication entirely.

At the end of this process, we would see our `go.mod` file for the fakegarage project turn to something like this:

```bash
module gitlab.com/hairizuanbinnoorazman/fakegarage

require gitlab.com/hairizuanbinnoorazman/fakecars v0.0.0-20190224070000-fffffffffff
```

A `go.sum` would also be generated to lock the versions of the packages being used in the project

Now with all this set up, we should be able to run a `go build .` command safely. The command should be able to run the build and compile a binary, and we should be able to run the binary with little issues.

## Prepping it for CI/CD in Google Cloud Build

On CI/CD platforms like Google Cloud Build, one doesn't expect and require interactivity. You would expect to just push code into git repository. After doing so, the build system should build and compile the solution accordingly.

This would mean the method of setting `env GIT_TERMINAL_PROMPT=1` won't be good for the workflow. We need to go with the official stance of handling go private modules which uses ssh to fetch the packages instead. That would also mean that we somehow need to add ssh keys to the build pipeline. Doing so might not be so safe, so we would ideally use another service to encyrpt the keys accordingly.

Command line to encrypt. One would need to set up a keyring `test` and a key `test1` to do this encryption.

```bash
gcloud kms encrypt \
    --key test1 \
    --keyring test \
    --location global \
    --plaintext-file id_rsa \
    --ciphertext-file id_rsa.enc
```

With that, we can then properly test a workflow that creates the automated golang build pipeline.

```yaml
steps:
  - name: "gcr.io/cloud-builders/gcloud"
    args:
      - kms
      - decrypt
      - --ciphertext-file=id_rsa.enc
      - --plaintext-file=/root/.ssh/id_rsa
      - --location=global
      - --keyring=test
      - --key=test1
    volumes:
      - name: "ssh"
		path: /root/.ssh

  - name: "golang:1.11.4"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        ssh-keyscan gitlab.com > /root/.ssh/known_hosts
        git config --global --add url."git@gitlab.com:".insteadOf "https://gitlab.com/"
        chmod 0600 /root/.ssh/id_rsa
        go build -o main-test .
    volumes:
      - name: "ssh"
		path: /root/.ssh

artifacts:
  objects:
    location: 'gs://testing-golang-builds/'
    paths: ['main-test']
```

With that code, you should have set up the full workflow. There are plenty of fixed values used here, so one would replace it with variables that can be injected in order to fit the use case.

## References

Here are some examples for creating this example

- https://github.com/golang/go/issues/26134
- https://cloud.google.com/cloud-build/docs/quickstart-go
- https://cloud.google.com/cloud-build/docs/configuring-builds/store-images-artifacts

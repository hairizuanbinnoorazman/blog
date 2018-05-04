+++
title = "Lessons from Gophercon SG"
description = ""
tags = [
    "conference",
    "golang",
]
date = "3018-05-16"
categories = [
    "conference",
    "golang",
]
+++

This is the list of talks provided in the reccent Gophercon Conference held in Singapore on 4th May 2018

- Go with Versions
- Project-driven journey to learning Go
- Resilency in Distributed Systems
- Understanding Running Go Program
- Go for Grab
- Optimize for Correctness
- Build your own distributed database
- The Scandalous Sotry of Dreadful Code Written by the Best of Us
- Erlang for Go developers
- Go and the future of offices
- Reflections on Trusting Trust for Go
- The lost art of bondage

Below are some of the more interesting points raised during the talk (View the full talk to understand the context on what and why a certain point was raised.)

## Go with Versions

- Versioning in Golang has always been lacking
- Golang community combined their efforts together to create a tool called `Dep` which is a package management tool which implements the usual package management that other languages like Ruby and Python have (bundler and pip respectively). Includes some sort of config file; `Gopkg.toml` file as well as as a lock file `Gopkg.lock` file.
- Several use cases of how using Dep can result in fissures in package management ecosystem due to the fact that the tools, when asked to upgrade, kind of takes up the latest version of the package; even if the latest result in breakages etc
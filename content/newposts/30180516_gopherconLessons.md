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

The list of videos from Gophercon can be found here:  
https://engineers.sg/conference/gopherconsg-2018  

## Go with Versions

- Versioning in Golang has always been lacking
- Golang community combined their efforts together to create a tool called `Dep` which is a package management tool which implements the usual package management that other languages like Ruby and Python have (bundler and pip respectively). Includes some sort of config file; `Gopkg.toml` file as well as as a lock file `Gopkg.lock` file.
- Several use cases of how using Dep can result in fissures in package management ecosystem due to the fact that the tools, when asked to upgrade, kind of takes up the latest version of the package; even if the latest result in breakages etc - needed some locks to prevent it from taking up bad versions
- Refer to the following commit for the full discusion on the `vgo` proposal:  
  https://github.com/golang/go/issues/24301  

## Resiliency in Distributed Systems

- Microservice talk by Go-Jek
- Fault vs Failures: A fault is a state where system is unhealthy but is still working; a failure would mean that users would not be able to interact with the system.
- Fault could happen from:
    - Database slowdown
    - Memory leaks
    - Blocked threads
    - Dependency Failure
    - Bad Data coming in/going through the system
- https://github.com/gojektech/heimdall
- The capability of a system of preventing faults turn to failures is called resilency
- Ways to handle it:
    - Timeouts (Never ever wait for a client/server forever)
    - Retries (System that can eventually recover - don't need intervention to manually retry stuff)
    - Circuit Breakers (Prevent stampeding herd all over system)
    - Fallbacks (E.g. Does the service really need to be up; can a alternative be served in the mean time - third party integrations can have their alternatives be served when the primary integration failed.)
    - Resilency Testing (Using chaos monkeys systems etc to do a test run to see what happens if stuff happened to the system)
    - Rate limit/throttling (Prevent stampeding herd situation where failures in parts of the system don't cascade over to other parts of the system)
    - Bulk heading
    - Queueing (Queue slows down the system - reduce stress on the systems where it is not needed for fast and immediate responses)
    - Monitoring/Alertings
    - Canary releases (Release new versions of the software slowly - release to a small percentage and see if errors spike etc; if not, release to a bigger and bigger group until it becomes the version that is the majority of the system)
    - Redundancies

## Go for Grab

- Internally, they have a toolkit called `Grabkit` which they used for bootstrapping their microservice applications. The toolkit was inspired by `Gokit`
- Talks on microservices and how the importance distributed applications became problems that had to be solved on a company wide level
- Interesting point raised: _Make your functions accept context: you'll be glad you did_
- Difficulty of doing debugging and root cause analysis - central logging systems as well as good monitoring and alerting systems would be helpful

## Optimize for Correctness

- Article that was used in the presentation: https://github.com/ardanlabs/gotraining/blob/master/topics/go/README.md
- More code == more bugs; lesser code is better
- Every decision made comes at a cost, more abstractions might result in more complexity making it difficult to predict the performance of the code etc

## The Lost Art of Bondage

- Some C applications are just too expensive to be ported over to Golang; instead, bindings are introduced. Golang has a library called cGo which would interface with such C code. Examples of c code interfaced with that was brought up during the talk is Cuda
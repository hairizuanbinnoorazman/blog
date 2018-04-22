+++
title = "A sample bookcase application case via Gokit Golang Library"
description = ""
tags = [
    "golang",
]
date = "3018-03-14"
categories = [
    "golang",
    "web",
]
+++

This is an application based on a previous blog post on Bookcase application.

# Learning 1: Benefitting of the separation concerns

Previously we built the application using the Gin Golang library. The application is built where any third party component is extracted out to some sort of middle layer. With that, we can just easily reuse the very same models to implement the aplication in Gokit instead.

# Learning 2: Gokit is decorators taken to the extreme

Decorator pattern is a design pattern that allows a programmer to provide additional capability to a class/struct without affecting the internals workings of it. In our case with gokit, we model our business logic and application; after which, we add a bunch of decorators onto that business logic which immediately allow logging, instrumentation, metrics collections, tracing etc to be collected from the application.

Some of the above mention features (e.g. logging) is something that is a cross cutting concern - something that affects all applications - essentially, all applications need to have some sort of logging in order to allow users to have the application monitored accordingly.




+++
title = "A sample bookcase application case via Gorilla Golang Library"
description = ""
tags = [
    "golang",
]
date = "3018-03-21"
categories = [
    "golang",
    "web",
]
+++

The bookcase application that is to be built via the Gorilla library follows roughly the same pattern as the way the application is built in the Golang Gin Web library. The only thing is that the Gorilla library is a lot more raw; you work with the same `ServeHTTP` codebase as with the rest.

This application happens to be just as similar as the one built in the Gin Golang library; not much has changed. We would copy most of our models and even our services. The controllers would be the only that would be altered -> Gorilla don't provide the inputs with the `context` param as how Gin provides. Instead we work with the same old handlers functions from the standard library.
+++
title = "A sample bookcase application case via Gin Golang Framework"
description = ""
tags = [
    "golang",
]
date = "2018-03-07"
categories = [
    "golang",
    "web",
]
+++

This is an application based on a previous blog post on Bookcase application.

# Learning 0: Tools/Libraries

Some of the below tool/libraries would be useful when added the Bookcase application

- [Viper](https://github.com/spf13/viper) - Reading Configuration Files
- [Negroni](https://github.com/urfave/negroni) - Middleware Management
- [Sendgrid](https://github.com/sendgrid/sendgrid-go) - Transaction Email
- [JWT Tokens](https://github.com/dgrijalva/jwt-go) - Auth token library


# Learning 1: Structuring the application

A few important things to note here is that we would want to structure our app such that the components within the application is extensible; it gives us, the users, an opportunity to switch the different parts of architecture. An example of such a scenario is the usage of the database in the application.

Normally, models in a MVC sort of architecure has the `save` function to persist the model into the database. A good example of this would be the Ruby on Rails framework. There is even a shell that allow you to do such manipulation of data with relative ease.

Unfortunately, typing a database to the model object has several consequences; one of which is that it makes it hard to kind of test the model without using database mocks or even having a test database in place. This makes it hard to test the logic in the model.

Rather than needing end to end testing, we will just focus on the part that would really need such tests; which would be the logic. One can assume that the saving of data into the databases or other persistent system as of now.

We would do a few things when structuring the application:
- Put all of our logic (or as much as possible) into our models; in this case, it would be structs.
- Have a service layer that would deal with interfacing our model and logics with a persistance system (it could be something that could be stored in memory, a file system or even db). The service layer does nothing except to take the model/entity that it is suppose to 'service' and save/store it.
- Our controller would consume the concrete service (defined through structs that have functions attached to it) and it would only be concerned about transport only.

## TDD immediately available

With such a structure, we can approach the app in TDD style. It's slightly unfortunate that we don't really have any complex algorithms to apply to really test the approach but this structure does provide an interesting structure to work with.

From the blog post on the requirements of the bookcase application, we already have some sort of specs. We can convert the spec (constraints) on the model and get the tests out of the way. This video covers on how we can imagine this scenario. [TDD for those who don't need it](https://www.youtube.com/watch?v=a6oP24CSdUg)

As a matter of convenience, we would you this pretty decent approach of create a list of tables of test cases that is to be tested with each model's implementation. Refer to this youtube video for inspiration on this. [Advanced Testing with Go](https://www.youtube.com/watch?v=8hQG7QlcLBk&t=2222s)

## Additional challenges

(Not yet implemented)

For an additional challenge when making this applicaiton, we would try to see if we can add the following:
- Utilize multiple data storage options. For some of the endpoints, we can see if we can make multiple implementations of the same service and make it easier to switch (or refactor) for 3rd party storage components.
  - Redis
  - MySQL
  - Google Datastore
- Create an endpoint which is customized for a view (a subset of a domain model or a subet of a joined data model). Test the implementation of such an endpoint.

# Learning 2: Applying the decorator pattern

For every application that is to be deployed, we have to do a few final steps before making the app fully production ready. All of such concerns affect all application (some would call it cross cutting concerns). Some of the things that is to be added would:
- Logging (Different granularity of logging)
- Application Metrics (Sending functions call count etc to a prometheus server)
- Tracing (In microservices -> Opentracing)

Some of the properties such as Circuit Breaking/Retry logic; it's vital to have them if we are in the microservices. Reason is because if we were to deploy such services in Kubernetes, we can rely on the istio or other service meshes which can deal it on the cluster level; we would be impacted by some latency but unless it's absolutely necessary to respond at blazing speeds, it is kind of resolved issue.






+++
title = "A sample bookcase application case via Gin Golang Framework"
description = "Web application using Golang"
tags = [
    "golang",
]
date = "2018-03-08"
categories = [
    "golang",
    "web",
]
+++

This is an application based on a previous blog post on Bookcase application.

The link to the code base of the application:

https://github.com/hairizuanbinnoorazman/golang-web-gin-book-store

There is a chance that when you are on the code base, the application is not fully operational; I am still adding code to it to add functionality to the application

# Learning 0: Tools/Libraries

Some of the below tool/libraries would be useful when added the Bookcase application

* [Viper](https://github.com/spf13/viper) - Reading Configuration Files
* [Negroni](https://github.com/urfave/negroni) - Middleware Management
* [Sendgrid](https://github.com/sendgrid/sendgrid-go) - Transaction Email
* [JWT Tokens](https://github.com/dgrijalva/jwt-go) - Auth token library

# Learning 1: Structuring the application

A few important things to note here is that we would want to structure our app such that the components within the application is extensible; it gives us, the users, an opportunity to switch the different parts of architecture. An example of such a scenario is the usage of the database in the application.

Normally, models in a MVC sort of architecure has the `save` function to persist the model into the database. A good example of this would be the Ruby on Rails framework. There is even a shell that allow you to do such manipulation of data with relative ease.

Unfortunately, typing a database to the model object has several consequences; one of which is that it makes it hard to kind of test the model without using database mocks or even having a test database in place. This makes it hard to test the logic in the model.

Rather than needing end to end testing, we will just focus on the part that would really need such tests; which would be the logic. One can assume that the saving of data into the databases or other persistent system as of now.

We would do a few things when structuring the application:

* Put all of our logic (or as much as possible) into our models; in this case, it would be structs.
* Have a service layer that would deal with interfacing our model and logics with a persistance system (it could be something that could be stored in memory, a file system or even db). The service layer does nothing except to take the model/entity that it is suppose to 'service' and save/store it.
* Our controller would consume the concrete service (defined through structs that have functions attached to it) and it would only be concerned about transport only.

## TDD immediately available

With such a structure, we can approach the app in TDD style. It's slightly unfortunate that we don't really have any complex algorithms to apply to really test the approach but this structure does provide an interesting structure to work with.

From the blog post on the requirements of the bookcase application, we already have some sort of specs. We can convert the spec (constraints) on the model and get the tests out of the way. This video covers on how we can imagine this scenario. [TDD for those who don't need it](https://www.youtube.com/watch?v=a6oP24CSdUg)

As a matter of convenience, we would you this pretty decent approach of create a list of tables of test cases that is to be tested with each model's implementation. Refer to this youtube video for inspiration on this. [Advanced Testing with Go](https://www.youtube.com/watch?v=8hQG7QlcLBk&t=2222s)

## Additional challenges

(Not yet implemented in the code base - it will be slowly substituted in)

For an additional challenge when making this applicaiton, we would try to see if we can add the following:

* Utilize multiple data storage options. For some of the endpoints, we can see if we can make multiple implementations of the same service and make it easier to switch (or refactor) for 3rd party storage components.
  * Redis
  * MySQL
  * Google Datastore
* Create an endpoint which is customized for a view (a subset of a domain model or a subet of a joined data model). Test the implementation of such an endpoint.

# Learning 2: Applying the decorator pattern

For every application that is to be deployed, we have to do a few final steps before making the app fully production ready. All of such concerns affect all application (some would call it cross cutting concerns). Some of the things that is to be added would:

* Logging (Different granularity of logging)
* Application Metrics (Sending functions call count etc to a prometheus server)
* Tracing (In microservices -> Opentracing)

Some of the properties such as Circuit Breaking/Retry logic; it's vital to have them if we are in the microservices. Reason is because if we were to deploy such services in Kubernetes, we can rely on the istio or other service meshes which can deal it on the cluster level; we would be impacted by some latency but unless it's absolutely necessary to respond at blazing speeds, it is kind of resolved issue.

# Learning 3: All fields in structs that are to be stored in DB need to be public

Although it would ideal that certain fields such as password are set to private to prevent the property from being overwritten in a haphazard manner -> as well as to reduce the amount of exported fields, the fields need to public to allow functions and other packages to make use of them as well.

This kind of affects any language which has public/private fields in their class/struct definitions; even java. A random fact while going through is this: In Java, there is a Hibernate orm library; the framework is able to access private libraries. It accesses them via reflection -> I would assume you would need to do the same thing here as well in golang world if you want to do same. However, this is adding unnecessary complexity to an application, making it slower as well as more fragile.

Alternatively, we can rearrange the whole application to fit the need by changing the folder structure and package structure:

List of folders in current version:

* Models (Handles the domain structs as well as functions that does validation, checks and other calculations)
* Services (Handles the integration of domain structs to 3rd party components such as APIs, libraries as well as DB)
* Controllers (Calls the service by providing a concrete service method)

Possible alternative way:

* Domains (e.g. User)
  * File that contain struct declarations
  * File that implements the intergration between the DB and the structs
  * Test files

There are a few disadvantages between using the current approach vs the alternative approach; one of which is the restriction of utilizing external libraries and packages to help build our software. There is no guarantee that external packages are able to read private fields like hibernate does.

# Learning 4: Inspiration from usage of GORM library

The GORM library has a pretty nice way of handling relationships between model structs. An initial version of the design was quite restrictive:

Let's take an example of an item in the store:

```go
type Item struct {
	ID            string
	Name          string
	Description   string
	CategoryID    string
	SubCategoryID string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}
```

With the `CategoryID` and `SubCategoryID` there, it is kind of a way of how the data is related to those said models. However, this would mean that we can't manipulate the item's subcategory data of an item via the item struct. We would have to call it from the database to retrive the category struct which is linked to this item struct which we can then modify. There are too many steps involved.

If one uses the GORM library and observe the way of how relationships is represented in the struct:

```go
type Item struct {
	ID            string
	Name          string
	Description   string
	Category      Category
	CategoryID    string
	SubCategory   SubCategory
	SubCategoryID string
	CreatedAt     time.Time
	UpdatedAt     time.Time
}
```

We now see the `Category` and `SubCategory` struct also being part of the item struct. This would allow us to modify the item as one single entity which makes it more natural to manipulate etc.

```go
// We can query for parts of the Item struct this way:
// retrivedItem is Item data retrieved from database
fmt.Println(retrivedItem.Category.Name)
```

Notice that the `CategoryID` and `Subcategory` would still need to be defined. Without them, those foreign keys won't be stored in the database. Read more in the `GORM` documentation for more details.

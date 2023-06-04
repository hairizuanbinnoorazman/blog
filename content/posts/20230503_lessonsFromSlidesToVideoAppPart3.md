title = "Rethinking migrations in Golang Applications"
description = "Migrations are a critical part of an application. Taking shortcuts with convenient library functions will eventually bite you back. Lessons from building Slides to Video App Part 3"
tags = [
    "golang",
    "slides-to-video",
]
date = "2021-05-03"
categories = [
    "golang",
    "slides-to-video",
]
+++

This is more of a reminder post for me that every aspect of application development is critical and sufficient thought should be put behind it. This time around, it's on database migration within applications.

As a matter of convenience, I use a Golang ORM library called Gorm that would handle database interactions. It is definitely a convenient way to manage and handle database records. Even if people mention how bad ORMs is, at the end of the day, you would still want to manage the data coming from application in some form of struct where the types are obviously set. If this was the goal, even if you use the raw mysql golang libraries - you would still write up code that would map the raw database responses to Golang structs before it's being passed around the application.

However, this time around, this post isn't exactly aiming to focus on the ORM portion of the library but more of the database migration bit. The GORM library comes with some functionality that helps users with database migration simply based on Golang structs. All we need to do is denote the structs that would be managing the data we wish to store in database with some `gorm` struct tags, and then, the said information will be used by Gorm library to create the necessary tables/columns that would be used to store the data on the database. The convenient function that is being used to handle it is the `AutoMigrate` function. https://gorm.io/docs/migration.html

In general, the `AutoMigrate` function works fine in most cases. At the end of the day, you would want to work with latest schema that works with your application. One of the biggest benefits of this function is that it allows you to do database migrations without needing to think of writing sql migration scripts etc - which is usally a major pain. Database migrations are usually one of the main reasons for why applications cannot be updated simply:

- There is too much data in database and a naive database migration would result in an outage
- A table that the application is using needs be broken up, maybe another round of database migration needs to be done?
- A bad database migration due to programming error and it's required for the database schema to be reverted
- Deploed application and its database schema are extremely outdated. It's impossible to update it unless one uses old binaries and keep swapping/upgrading binaries till the right database schema is reached for updating the application to the latest version.

The `AutoMigrate` function kind of nudges the developer in the direction to not think of such scenarios. However, reality always strikes back at the worst possible timings and it's always better to have such capabilities in place rather than not having it at all.

An alternative (albeit better in my opinion) for handling database migration is to utilize something like `golang-migrate`? https://github.com/golang-migrate/migrate. The library provides a CLI but we can embed said functionality into our application. One of the primary capabilities it provides is a "migration" database schema table that allows us to track the version of the database schema we are on. At the same time, it also allows us to update database schema one at a time. We can jump multiple database migrations at one go or we can go one database migration at a time to ensure database will not suffer any outage.

Here is a sample application from my many sample golang application that utilizes the `go-migrate` library. https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

For reference on all other posts with regards to the building of the slides to video application:  

- [Lessons from building Slides to Video App - Part 1](/lessons-from-building-slides-to-video-app-part-1)
- [CORS with Golang Microservices and Elm Frontend is difficult](/cors-with-golang-microservices-and-elm-frontend-is-difficult)
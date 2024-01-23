+++
title = "Multiple Database Support - MySQL and SQLite support"
description = "Multiple Database Support - MySQL and SQLite support"
tags = [
    "golang",
]
date = "2023-10-04"
categories = [
    "golang",
]
+++

I intend to try out the [Turso](https://turso.tech/) service in order to see if there is any other potential serverless database that would have pretty decent type of billing for small projects. There isn't a proper SQL based database that can be billed in a similar way to the Cloud Run product - it'll be great if the billing of the database product would be along the amount of data being stored or amount of read/write requests done for the data instead of the usual charged based on how long the instance being run (based on how Cloud SQL is billed).

Turso is a database that is somewhat based on SQLite - but not exactly SQLite. The usual SQLite libraries generally deal with files but in this case - we would need to form some sort of network connection to "turso" which is usually unlike the usual way of dealing with SQLite databases.

I tried to do a quick integration via Golang to Turso using plain SQLite libraries that already existed but apparently, that doesn't exactly work too well expected. A quick search as well lead to the following PR for adding support for sqld server like Turso: https://github.com/golang-migrate/migrate/pull/1000

Although the integration to the Turso database can't be done yet, it should still be possible to start preparing the sample application that I've been using all this while to accept multiple database integrations - the integration needs to handle for both database migration as well as running the application which would access the database. The sample application that I've been using (also mentioned in many of my previous blog posts) is available in this folder in the repo: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

For now, I'm adding SQLite support as well as MySQL database support.

SQLite and MySQL have slightly differing syntax-es, with that, we need to separate it into appropiate folders for this. https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate/migrations. Within this migrations folder, there is one for MySQL and one for SQLite. When we're dealing with MySQL database, we would rely on the migrations within the MySQL folder. Likewise, for the SQLite database, we would rely on the migration scripts within the SQLite folder.

As of now, I haven't thought too deep on how to abstract the logic for handling the different databases - right now, since there is only 2 databases supported here, it is handled via a simple if, else conditional statements. The various critical information is pasased to it via environment variables.

```golang
...
		dbUser := os.Getenv("DATABASE_USER")
		dbPass := os.Getenv("DATABASE_PASSWORD")
		dbHost := os.Getenv("DATABASE_HOST")
		dbName := os.Getenv("DATABASE_NAME")
		useTLS := os.Getenv("DATABASE_USE_TLS")
		dbType := os.Getenv("DATABASE_TYPE")

		var d source.Driver
		var err error
		dsn := ""
		if dbType == "" || dbType == "mysql" {
			dsn = fmt.Sprintf("mysql://%v:%v@(%v:3306)/%v", dbUser, dbPass, dbHost, dbName)
			if strings.ToLower(useTLS) == "true" {
				fmt.Println("database tls mode on")
				dsn = dsn + "?tls=true"
			}
			d, err = iofs.New(fs, "migrations/mysql")
			if err != nil {
				log.Fatal(err)
			}
		} else if dbType == "sqlite" {
			sqliteFile := os.Getenv("SQLITE_FILE")
			dsn = fmt.Sprintf("sqlite3://%s?query", sqliteFile)
			d, err = iofs.New(fs, "migrations/sqlite")
			if err != nil {
				log.Fatal(err)
			}
		} else {
			fmt.Println("unexpected dbType provided. Please check inputs")
			os.Exit(1)
		}
...
```

Do notice of how we're referencing the right folder - if we're on MySQL or MariaDB, we're using `migrations/mysql`, if we're on SQLite, we're using `migrations/sqlite`

In order to make it convenient to test the integration of MySQL/MariaDB/SQlite to the application, there is a makefile to do so.

```makefile

all-mysql: start-mysql build
	sleep 30
	make migrate-mysql 
	make start-app-mysql
all-sqlite: build create-sqlite migrate-sqlite start-app-sqlite

start-mysql:
	docker run --name some-mysql -e MYSQL_DATABASE=application -e MYSQL_ROOT_PASSWORD=my-secret-pw -e MYSQL_USER=user -e MYSQL_PASSWORD=password -p 3306:3306 -d mysql:5.7

stop-mysql:
	docker stop some-mysql
	docker rm some-mysql

build:
	go build -o lol .

migrate-mysql:
	DATABASE_NAME=application DATABASE_USER=user DATABASE_PASSWORD=password \
	DATABASE_HOST=localhost DATABASE_TYPE=mysql \
	./lol migrate

start-app-mysql:
	DATABASE_NAME=application DATABASE_USER=user DATABASE_PASSWORD=password \
	DATABASE_HOST=localhost DATABASE_TYPE=mysql \
	./lol server

migrate-sqlite:
	DATABASE_NAME=application DATABASE_USER=user DATABASE_PASSWORD=password \
	DATABASE_HOST=localhost DATABASE_TYPE=sqlite SQLITE_FILE=application.db \
	./lol migrate

start-app-sqlite:
	DATABASE_NAME=application DATABASE_USER=user DATABASE_PASSWORD=password \
	DATABASE_HOST=localhost DATABASE_TYPE=sqlite SQLITE_FILE=application.db \
	./lol server

test-app:
	curl -X GET localhost:8888/health
	curl -X POST localhost:8888/user -d '{"first_name":"zzz","last_name":"zzz"}'
	curl -X GET localhost:8888/user/1

create-sqlite:
	sqlite3 application.db ".databases"


```

For testing the application with MySQL/MariaDB - we can simply run the `make all-mysql`. Once the application is running, we can use the following command: `make test-app`.

For testing the application with SQLIte - we can simply run the `make all-sqlite`. Once the application is running, we can use the following command: `make test-app`.
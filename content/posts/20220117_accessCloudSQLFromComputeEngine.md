+++
title = "Database migration via Cloud SQL Proxy for Cloud SQL in Google Compute Engine VM"
description = "Database migration for golang application via Golang migrate via Cloud SQL Proxy for MySQL (Cloud SQL) where app is in Google Compute Engine VM"
tags = [
    "google-cloud",
    "golang",
]
date = "2022-01-17"
categories = [
    "google-cloud",
    "golang",
]
+++

Database migration is kind of a critical bit when it comes to running and operating applications. In Golang, it is kind of appealing to rely on ORM (Object Relational Mapping) libraries. It allows one to kind of map structs to tabular structures within the database storage. One such example of an ORM library that I've found on the first page of Google is [GORM](https://gorm.io/index.html).

The Gorm package allow application developers to mostly focus on application logic and move some of the "administrative" stuff of reading data from cursors being returned from database responses into Golang structs. The amount of effort to do this is the reason why ORMs continue to exist - despite the various negatives from the usage of the libraries. As of now, essentially, as long as a developer understand the limitations of such libraries and how functions within the ORM translate into SQL queries - the library is a useful tool in a developer arsenal.

However, one such feature that is "appealing" to use but definitely bad to have is the auto-migrate in GORM. Refer to the following page: https://gorm.io/docs/migration.html

The auto migrate is extremely awesome to use - we can easily create the sql statements that would be able to create the necessary tables and columns that is needed for application to run. It is nice to use it for bootstraping applications and to get the database tables so that we can focus on writing application logic rather than bother about the administrative effort to write proper migration scripts.

However, as one would guess by now, this convenience comes at a cost. Auto migrate doesn't seem to track the version of database schema that our application is using. We have little control of knowing how the the auto-migrate feature would alter the database tables. Although in a large number of cases, we would only add database columns etc - however, we also need to take note that this lack of control could lead to inconsistent database migrations. In the case where we need to apply database migrations across multiple datacentres across the time where the application is needed to be operated in - the database structure would be inconsistent - and this inconsistency could easily open the door to potential bugs where a bug would only exist in certain datacentres (maybe due to accidental reference to a column that used to be needed but application structs have been altered such that auto-migrate would not create that column).

In this blog post, I would be covering a potential library/approach to database migration using the [golang-migrate](https://github.com/golang-migrate/migrate) library. It will be demonstrated using Cloud SQL (which will be accessed via Cloud SQL Proxy) and the application is being hosted in a Google Compute Engine Virtual Machine.

## Creating the environment

First, let's get a Google Compute Engine VM. Please make sure to enable CloudSQL api for the Virtual Machine

Also, in order for this whole thing to work, we would ensure the following API is enable for the Google Cloud Project: Cloud SQL Admin API

This section will be covering on installing on mysql client - which we may/may not need here - mostly used for debugging purposes only. We can probably skip this step safely.

```bash
sudo apt update && sudo apt install -y wget
wget https://dev.mysql.com/get/mysql-apt-config_0.8.20-1_all.deb
sudo dpkg -i mysql-apt-config_0.8.20-1_all.deb 
sudo apt update
sudo apt install -y mysql-client
```

This step would be needed - install the cloud sql proxy. Cloud SQL proxy is needed in the case where we are not having the Cloud SQL restricted to only one VPC. If we need that same database to be accessed from compute engine VMs from multiple VPCs.

```bash
sudo apt update && sudo apt install -y wget
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
sudo chmod +x cloud_sql_proxy
```

With that, we now have the VM somewhat prepped up. The next step would to just to create a Cloud SQL - MySQL instance. We would using a "public" connection instead of "private". We would also need to create the database within that MySQL instance manually. After that, we can then copy the sql connection name from the overview of the Cloud SQL instance and paste it into our VM for our auth proxy to work.

```bash
./cloud_sql_proxy -instances=<sql connection name>=tcp:3306
```

As one can guess, the cloud sql proxy that we download and start running is just a binary that forwards/"proxies" the traffic meant for the database to the Cloud SQL instance. We need to use that to ensure that the database connection is secure and authorized - with that, we can just use the simple way to connect to mysql (as how most tutorials do it). We don't need to concern ourselves to secure it etc. The proxy allow us to just send data to "localhost:3306" even though our database instance is definitely not being on that machine.

To test this out, we can run it in shell but I'd imagine that the better way to manage this would be to put the `cloud_sql_proxy` binary into systemctl's control. This is so that we can ensure that the binary will be restarted accordingly should it the application crash etc.

## Running migrations

There are multiple ways of doing this; one way is to download the `golang-migrate` CLI tool.

```bash
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.15.1/migrate.linux-amd64.tar.gz | tar xvz
```

An important thing to take note is it would best if we ensured that migrations are all idempotent - this would mean that if migrations were to be accidentally "rerun", it should not mess up the database schema. An upgrade/downgrade of the database schema shouldn't impact the running of the application as much as possible so that would ensure that we would not need to introduce downtime just in order to be able to upgrade the application or run database schema upgrades.

With the golang migrate tool, we can upload the sql migration scripts in order to alter the database scheme accordingly. We can run the `migrate` command on top of all the sql migration scripts. The problematic thing is that using this methodology, we would need to sync the sql migrations scripts over or provide some sort of online link to said migration scripts (which actually feels less secure here) and that does kind of create an additional administrative step to handle all that.

An alternative to using the golang-migrate tool as CLI directly is to embed into the application that we're building. I have a reference aplication here: https://github.com/hairizuanbinnoorazman/Go_Programming/tree/master/Web/basicMigrate

In this application, we are relying on Golang's capability to embed files into the built binary (previously, you would have to somehow get some sort of package that would do this but now, this is natively supported). The embed feature is available from Golang 1.16 onwards. Refer to the release notes for it here: https://go.dev/blog/go1.16

The Go migrate package now supports this feature - we just need to import said packages into our binary as well:

```golang
"github.com/golang-migrate/migrate/v4/source/iofs"
```

This is the package that would be needed to support the portion of being able to use the embedded files for sql migration by the go-migrate package. 

The sample binary here is built with 2 subcommands. One subcommand is the `migrate` subcommand which serves to invoke the functions to run the migration. The one being built here is on the "simpler" side where we would do migration straight to the latest schema but I'd imagine that it could be possible where we can possible control the number of migrations to run/upgrade upwards - this might be needed in the scenario where we have a extremely old version of the application running in some datacentre; we can sync latest version of the application; open up a maintainance window and upgrade the schema one upgrade at a time to the latests (if there was issues, we can pause it there and identify the troubling migration version)

## Code for reference application

Since the application is still somewhat simple, I can still add it to this blog post with little issue. However, updates won't be propagated here so it would be best to refer to the github link that contains the source code that is being referred to discuss on this topic.

```golang
package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"

	gormMySQL "gorm.io/driver/mysql"
	"gorm.io/gorm"

	"embed"

	migrate "github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/mysql"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	"github.com/spf13/cobra"
)

//go:embed migrations/*
var fs embed.FS

type User struct {
	ID        int `gorm:"primaryKey,autoIncrement"`
	FirstName string
	LastName  string
}

var rootCmd = &cobra.Command{
	Use:   "app",
	Short: "This is a sample golang migrate application",
}

var migrateCmd = &cobra.Command{
	Use:   "migrate",
	Short: "Run database migration",
	Run: func(cmd *cobra.Command, args []string) {
		d, err := iofs.New(fs, "migrations")
		if err != nil {
			log.Fatal(err)
		}

		m, err := migrate.NewWithSourceInstance(
			"iofs", d, "mysql://user:password@(localhost:3306)/application")

		if err != nil {
			panic(fmt.Sprintf("unable to connect to database :: %v", err))
		}
		m.Up()
	},
}

type UserGet struct {
	DB *gorm.DB
}

func (h UserGet) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	rawUserID := vars["userID"]
	userID, err := strconv.Atoi(rawUserID)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}

	var u User
	result := h.DB.First(&u, userID)
	if result.Error != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("bad connection"))
		return
	}

	rawResp, _ := json.Marshal(u)
	w.WriteHeader(http.StatusOK)
	w.Write(rawResp)
}

type UserCreate struct {
	DB *gorm.DB
}

func (h UserCreate) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	raw, err := ioutil.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}

	type userCreate struct {
		FirstName string `json:"first_name"`
		LastName  string `json:"last_name"`
	}

	var uc userCreate
	json.Unmarshal(raw, &uc)

	u1 := User{FirstName: uc.FirstName, LastName: uc.LastName}
	result := h.DB.Create(&u1)
	if result.Error != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("bad connection"))
		return
	}

	rawResp, _ := json.Marshal(u1)
	w.WriteHeader(http.StatusOK)
	w.Write(rawResp)
}

var serverCmd = &cobra.Command{
	Use:   "server",
	Short: "Run server",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("server start")
		dsn := "user:password@tcp(127.0.0.1:3306)/application"
		db, err := gorm.Open(gormMySQL.Open(dsn), &gorm.Config{})
		if err != nil {
			panic(fmt.Sprintf("unable to connect to database :: %v", err))
		}

		r := mux.NewRouter()
		r.Handle("/user", UserCreate{DB: db}).Methods("POST")
		r.Handle("/user/{userID}", UserGet{DB: db}).Methods("GET")

		srv := &http.Server{
			Handler: r,
			Addr:    ":8888",
		}

		log.Fatal(srv.ListenAndServe())
	},
}

func init() {
	rootCmd.AddCommand(migrateCmd)
	rootCmd.AddCommand(serverCmd)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
```




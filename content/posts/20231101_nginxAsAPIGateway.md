+++
title = "Nginx as API Gateway - focusing on auth_request directive"
description = "Nginx as API Gateway - focusing on auth_request directive. Setup done via docker compose"
tags = [
    "microservices",
    "docker",
    "golang",
    "nginx",
]
date = "2023-11-01"
categories = [
    "microservices",
    "docker",
    "golang",
    "nginx",
]
+++

On virtual machine
How to "protect" api requests
https://www.nginx.com/blog/deploying-nginx-plus-as-an-api-gateway-part-1/

Mostly is the `auth_request` directive


Microservices are a software architectural style that structures an application as a collection of loosely coupled, independently deployable services. Each service in a microservices architecture represents a specific business capability and communicates with other services through well-defined APIs (Application Programming Interfaces). These services are designed to be small, focused, and can be developed, deployed, and scaled independently. Its a somewhat common architectural pattern that many companies go to when it comes to scaling out their development teams to build out their product.

While microservices offer several advantages, managing communication and interaction between them can become complex as the number of services increases. This is where an API Gateway becomes crucial. Some of the advantages that come with introducing API Gateway would be:

- Unified Entry Point
- Protocol Translation 
- Security and Authentication
- Load Balancing
- Monitoring and Analytics

For this blog post, let's explore how we can add nginx to a bunch of services and then, tackle the authentication aspect of securing services. Out of convenience, we would set up our applications and nginx via docker containers. The docker containers would orchestrated and composed up with the docker compose tool.

## Main application

Our main application would simply return a small text response and a 200 ok response. We would have only one root endpoint that would respond to any request.

```golang
package main

import (
	"log"
	"net/http"

	"github.com/gorilla/mux"
)

type basic struct{}

func (b basic) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Println("started basic handler")
	defer log.Println("ended basic handler")
	w.Write([]byte("successfully called basic handler"))
}

func main() {
	log.Print("App started")

	r := mux.NewRouter()
	r.Handle("/", basic{})
	srv := http.Server{
		Handler: r,
		Addr:    "0.0.0.0:8080",
	}
	log.Fatal(srv.ListenAndServe())
}

```

The docker image for it would it would be something like so:

```Dockerfile
FROM golang:1.21 as builder
WORKDIR /helloworld
COPY . .
RUN CGO_ENABLED=0 go build -o app ./cmd/app

FROM debian:bookworm-slim
RUN apt update && \
    apt install -y ca-certificates && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
CMD ["/helloworld/app"]
EXPOSE 8080

```

For the docker image, we would build the binary and then, the binary would simply be copied over to a debian image.

We can test our application by simply starting our docker image and testing againt our root endpoint:

```bash
curl localhost:8080/
```

## Auth application

Our auth application would provide a few endpoints:

- `/` - A root endpoint that would provide a webpage that would provide a form where we can put in username and password
- `/signin` - An endpoint that would check the username and password input. If the username and password is not correct - it would return a 403 unauthorized response.
- `/auth` - This is simply endpoint that would check that a cookie is set. If the cookie is set, that would mean that the user/browser is "valid". Normally, we would need to check that the user is valid and still authenticated.

This would be the golang application:

```golang
package main

import (
	"log"
	"net/http"
	"text/template"

	"github.com/gorilla/mux"
)

type signinPage struct{}

func (b signinPage) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Println("started signin-page handler")
	defer log.Println("ended signin-page handler")

	tmpl := template.Must(template.ParseFiles("layout.html"))
	tmpl.Execute(w, nil)
}

type signin struct{}

func (b signin) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	log.Println("started signin handler")
	defer log.Println("ended signin handler")

	name := r.FormValue("name")
	password := r.FormValue("password")
	if name == "admin" && password == "password" {
		cookie := http.Cookie{
			Name:  "test",
			Value: "test-cookie",
			Path:  "/",
		}
		http.SetCookie(w, &cookie)
		w.Write([]byte("successfully login"))
		return
	}
	w.WriteHeader(http.StatusUnauthorized)
	w.Write([]byte("unauthorized login"))
}

type auth struct{}

func (a auth) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	_, err := r.Cookie("test")
	if err == nil {
		log.Println("cookie found, will return 200 ok")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("cookie found - successfully in"))
		return
	}
	w.WriteHeader(http.StatusUnauthorized)
	w.Write([]byte("invalid"))
}

func main() {
	log.Print("Auth started")

	r := mux.NewRouter()
	r.Handle("/", signinPage{})
	r.Handle("/signin", signin{})
	r.Handle("/auth", auth{})
	srv := http.Server{
		Handler: r,
		Addr:    "0.0.0.0:8080",
	}
	log.Fatal(srv.ListenAndServe())
}

```

The frontend part that would allow us to key in username and password would be:

```html
<html>
    <head></head>
    <body>
        <h1>Sign In Page</h1>
        <form action="/api/v1/auth/signin" method="post">
            <label for="name">Name:</label><br>
            <input type="text" id="name" name="name"><br>
            <label for="password">Password:</label><br>
            <input type="password" id="password" name="password">
            <input type="submit" value="Submit">
        </form>
    </body>
</html>
```

The docker image for our auth application

```Dockerfile
FROM golang:1.21 as builder
WORKDIR /helloworld
COPY . .
RUN CGO_ENABLED=0 go build -o app ./cmd/auth

FROM debian:bookworm-slim
RUN apt update && \
    apt install -y ca-certificates && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /helloworld
COPY --from=builder /helloworld/app /helloworld/app
COPY ./cmd/auth/layout.html /helloworld/layout.html
CMD ["/helloworld/app"]
EXPOSE 8080

```

With that, we can set up the docker container. We can then use the browser to check that the auth application would work. We can go through the endpoints in the following order.

- Go to `/` endpoint. It will render a html page to allow user to insert username and password. We can submit the form that would send user to the `/sigin` endpoint
- Go to `/signin` endpoint. This endpoint will compare username and password via some logic. This would return a cookie to the browser
- Go to `/auth` endpoint that would simply check the cookie is setup.

## Setting up entire application stack

Once we have applications available, we can setup all our containers via docker compose tool.

```yaml
version: '3.3'

services:
  app:
    build:
      context: .
      dockerfile: app.Dockerfile
    restart: always
  auth:
    build:
      context: .
      dockerfile: auth.Dockerfile
    restart: always
  fw:
    image: nginx:1.25.3
    ports:
      - 8080:80
    restart: always
    volumes:
      - type: bind
        source: ./conf
        target: /etc/nginx/conf.d/
        read_only: true

```

For the nginx configuration, we can use the following configuration.

```conf
server {
    listen       80;
    listen  [::]:80;
    server_name  localhost;

    #access_log  /var/log/nginx/host.access.log  main;

    location ~ ^/api/v1/basic/ {
        auth_request /auth;
        rewrite ^/api/v1/basic(.*) $1 break;
        proxy_pass         http://app:8080;
        proxy_set_header   Host              $http_host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    location = /auth {
        internal;
        proxy_pass http://auth:8080;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URI $request_uri;
    }

    location = /api/v1/auth/auth {
        return 404;
    }

    location ~ ^/api/v1/auth/ {
        rewrite ^/api/v1/auth(.*) $1 break;
        proxy_pass         http://auth:8080;
        proxy_set_header   Host              $http_host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}
}
```

Some of the important aspects of our the nginx

- `/api/v1/basic/` would direct users to the main application - done via `rewrite` directive. Do take note of the trailing slash - without the trailing slash, it would return a 404 error
- The `/api/v1/basic` uses the `auth_request` directive. This directive would do a quick check against the auth application to ensure that the user is still validated.
- `/api/v1/auth/` would direct users to the auth application - done via `rewrite` directive. Do take note of the trailing slash - without the trailing slash, it would return a 404 error
- Allow users to access `/signin` and `/` paths from the auth application. These are accessed via endpoint `/api/v1/auth/sign` and `/api/v1/auth/`.We would only use the `/auth` if we're accessing the main application's endpoint. (Technically it would be accessed via `/api/v1/auth/auth`)
- The `/auth` endpoint would check against the `/auth` endpoint of the auth application.
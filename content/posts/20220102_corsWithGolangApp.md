+++
title = "CORS with Golang Microservices and Elm Frontend is difficult"
description = "Issues with using CORS with Golang microservices via Golang rs/cors package and Elm frontend to use cookie based token systems"
tags = [
    "hugo",
    "elm",
    "golang",
]
date = "2022-01-02"
categories = [
    "hugo",
    "elm",
    "golang",
]
+++

I am still building up my personal pet project: https://github.com/hairizuanbinnoorazman/slides-to-video; the aim of this project is a personal one - to build up a set of microservices that is able to be deployed in various ways such as locally via Docker Compose or even to Kubernetes or the serverless Cloud Run platform on Google Cloud Platform. There was a previous blog post describing an initial part of this journey: [Lessons on building the project - Part 1](/lessons-from-building-slides-to-video-app-part-1/)

As a reminder - the set of microservices/applications being build is here Slides to Video application - it takes in a PDF containing slides; user would be adding a script to each slide (which will be used to narrate that slide) and end of the process, the user would be able to download a video file that is fully voiced over.

The architecture for this can be quickly summed to the following:

- Frontend (Elm)
- API Server - Manager (Golang)
- PDF Splitter Worker (Golang)
- Image to Video Worker (Golang)
- Video Concatenation Worker (Golang)

Manager work with the worker by send messages to a queue system which depends on how it is deployed. If docker-compose within the repo was used, it would be using Nats.

## Migrating from JWT Tokens to Cookies

Initially, the application was built to use JWT Tokens to pass the authentication token from backend to frontend. It does seem like the modern way of doing things nowadays - everytime a mention of single page applications (SPA) come along, the JWT token would be mentioned there. Fyi, JWT means JSON Web Token; it's an open standard which defines a way to send data (usually authorization data) to and fro the server. Best to refer to the [JWT Website](https://jwt.io/introduction)

The usage of JWT went fine until I needed to get some images that restricted to specific users. Generally, when we request for such resources, we would usually do it via GET requests - especially in the case of getting images from a server. If the website sets cookies for the site, it would send cookies along with every requests. Unfortunately, this is not the case for sending of JWT Tokens. Headers are not automatically sent with every request. If one is to check that `<img>` html tag - you will not find any possible way to modify the way it request images from the server. This makes it quite difficult to ensure that only authenticated users get to retrieve the images for that specific user.

In order to try to manage this situation, I thought of having the Elm application having the functionality to download images and prep them in the app state and render them in the page once downloaded. However, this does feel like hugely unnecessary complexity introduced to the applications just to follow the "JWT" approach of handling authorizations on the frontend. That's not the only issue though; the `elm-image` library doesn't exactly make the whole experience an easy, pleasant journey: https://github.com/justgook/elm-image/issues/9. If we had just use cookies, we wouldn't even bother to add the authorization headers for every request - the required tokens will be sent automatically, which would considerably make the frontend code way simpler.

With that, I decided to make the move to utilize cookies for sending tokens to and fro between frontend and backend. However, there is some communication between the various microservices to the API server and for that, JWT tokens will be the ideal way to pass the data between the microservices (to reduce the need for the microservices to keep checking the database if user is authorized to do that action).

## Issues with CORS and cookies

In order to allow the Elm frontend to communicate with the golang backend, we would first need to enable CORS in the backend. In the gorilla set of libraries, it is possible to provide the CORS capability. A initial version of configuration that somewhat work (just to be able to have the frontend communicate with the backend) is something like this:

Important note here that even though both backend and frontend are on the localhost domain - they're both using different ports. Apparently, this diffence is enough for browser to distinguish them as "different domains" which would require us to initially set up this CORS mechanism.

```golang
cors := handlers.CORS(
    handlers.AllowedHeaders([]string{"Content-Type", "Authorization"}),
    handlers.AllowedOrigins([]string{"*"}),
    handlers.AllowedMethods([]string{"GET", "POST", "PUT"}),
)
```

This is where problems start to arise. With the above configuration, the browser recognizes this as a "unsafe" configuration and will not set the cookies which is sent from the backend. One of the main troubling configuration that is considered bad is the `*` configuration for `AllowedOrigins`. That is understandable - ideally, backend should not trust all frontends from other domains that is trying to reach the server.

I attempted this configuration instead - apparently, a forum post in one of the stack overflow mention about the need to set the `Access-Control-Allow-Credentials` to be true as well - so, I added that setting as well.


```golang
cors := handlers.CORS(
    handlers.AllowedHeaders([]string{"Content-Type", "Authorization", "Set-Cookie"}),
    handlers.AllowedOrigins([]string{"http://localhost:8000"}),
    handlers.AllowedMethods([]string{"GET", "POST", "PUT", "OPTIONS"}),
    handlers.AllowCredentials(),
)
```

Other settings I've remembered reading involved the cookie settings. This was done with reference to the following post: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie. It mentions that browsers now only "sets the cookie" for websites where frontend and backend is of different domain by having the `SameSite` setting to None. However, in order for the browser to safely accept that, the `Secure` setting of the cookie should also be set to true. However, based on the `Secure` setting - it mentions that the cookie is only sent if frontend is using `https` protocol. It sounds too troublesome just for local development. It make sense in production settings to have all these settings but requiring all this weird config settings on dev makes it extremely unappealing to try to develop it locally.

```go
cookie := &http.Cookie{
    Name:     h.Auth.CookieName,
    Value:    encoded,
    Path:     "/",
    Secure:   true,
    HttpOnly: true,
    Domain:   "localhost",
    SameSite: http.SameSiteNoneMode,
}
```

Unfortunately, even after tinkering with all these settings - I still couldn't get the cookie to be set on the frontend site; and I definitely don't want to go hack around just to get it working locally. It would be ideal if this mode is available "out of the box" without huge changes to the codebase to allow for it to work in local environment.

Luckily, the accepted answer in this stackoverflow question hinted on a possible escape hatch that we can try out that make it easier to handle this situation: https://stackoverflow.com/questions/46288437/set-cookies-for-cross-origin-requests

## Proxy to both backend and frontend

As mentioned in the previous section of this blog post - if ports are different, the browser takes that as "different" origins. So, if we somehow manage proxy requests, maybe via nginx to both frontend and backend via localhost:8080 - we wouldn't need to handle CORS configuration.

Firstly, we would need to understand how I usually develop this locally:

- API server + other backend workers + database (mysql) + queue server (Nats) - are all setup via docker-compose. They exposed on specific ports. API Backend is exposed on local workstation port 8880.
- For development of frontend, I generally just stick to vanilla elm reactor. Usual port for this is exposed on port 8000.

Initially, I wanted to get the proxy as a nginx container as part of the docker-compose setup but a quick think regarding that setup kind of automatically rule that out. If we are to do it by adding the proxy to the docker-compose setup - the main question is on how to get the proxy to sent traffic via the proxy container back out to the local workstation on a specific port. (Requires some docker networking magic to make that work.)

The easiest way to get this whole setup working is to just install nginx on the workstation, and then add the nginx rules to redirect to the elm reactor exposed port as well as the exposed ports of the backend api server. The rules should all fall under the same "server" construct in nginx.

```nginx
http {

    ...

    server {
        listen      8080;
        server_name localhost;

        ...

        # This is for slides to video api
        location /status {
            proxy_pass http://localhost:8880/status;
        }

        location ~ ^/api/(.*)$ {
            proxy_pass http://localhost:8880/api/$1;
        }

        location / {
            proxy_pass http://localhost:8000;
        }

        ...

    }

}        
```

## Implications to deployment

Of course, there are impacts from deciding to go down the route of attempting not to deal with CORS. It would mean that the backend and frontend has to be deployed and exposed to the same domain - I would definitely need some sort of proxy for this. 

The simplest case would be to deploy everything into a single VM and set the domain to access the frontend from the public IP address of the VM. The Elm application has to be translated back into html, css and javascript and a http server is definitely needed to expose this.

In the case where if this application is to be deployed on a Cloud Environment and the applications are to be deployed on separate VMs, a Load Balancer (which is now a pretty common tool) can be used. Different paths can be set to sent the "/" path to frontend and for paths that start with "/api" to be sent to backend.

In the case where this application is to be deployed to Kubernetes instead; the application can be deployed into a single domain by making use of Kubernetes ingress. Similar to the case for the load balancer in a Cloud Environment, with the Kubernetes ingress, we can map certain paths to send traffic to frontend and the rest to be sent to backend.


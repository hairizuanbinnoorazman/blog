+++
title = "Using nginx to serve as ingress to multiple servers"
description = "Using nginx to serve as an ingress to multiple web servers"
tags = [
    "golang",
    "nginx",
]
date = "2018-09-29"
categories = [
    "golang",
    "nginx",
]
+++

This is a little experiment to see how this would work; in the case where we have multiple Go binaries with multiple web applications. If we wanted to expose this via a single http endpoint rather than providing a whole multitude of web endpoints.

We would have a single nginx server hit 3 different local backend endpoints. Although, for a more complete demo, we should host them on different machines for completeness. However, what we can potentially do would be to have all of these endpoints on a single machine and have nginx reach to them via different paths.

## Installing the nginx

This would be the easy bit. Since I am most familiar with debian/ubuntu, I would usually just use the following command to install it:

```bash
sudo apt install nginx
```

This would install nginx on the machine

## Adding 3 local backend endpoints to reach to

We would use Go to have our 3 backends for this example

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

// Alter this port number from 8000, 8001, 8002
var portNum = 8002

func sayHello(w http.ResponseWriter, r *http.Request) {
	log.Printf("Say Hello to %v", portNum)
	msg := fmt.Sprintf("Application port: %v", portNum)
	w.Write([]byte(msg))
}

func status(w http.ResponseWriter, r *http.Request) {
	msg := fmt.Sprintf("Status: %v", portNum)
	w.Write([]byte(msg))
}

func main() {
	log.Println("This is a main")
	defer log.Println("Exit Main")
	http.HandleFunc("/", sayHello)
	http.HandleFunc("/status", status)
	if err := http.ListenAndServe(fmt.Sprintf(":%v", portNum), nil); err != nil {
		panic(err)
	}
}
```

The small binary above would build to a small web binary that would just spit out which port the web request is being served to.

To further simplify the setup on server, it would be best to just compile locally and then just scp the binary over to the remote machine. (We shouldn't this for productions systems, create proper CI/CD/gated deployment systems that can help reduce risks during deployment)

```bash
env GOOS=linux GOARCH=amd64 go build -o test1 ./main.go
```

With the above, we can then set up backends by compiling 3 different binaries that deploy to ports 8001, 8002 and 8003 respectively.

We can then just transfer the binaries over to the machine via `scp` command.

```bash
scp ./test1 {name on server}@{server ip address}:~

# Full example
# Need to define absolute path on remote machine
scp ./test1 nameonserver@192.0.0.105:~
```

We can then finally run the applications on the remote machine via the following command.

```bash
./test1 &
```

We can test it via `curl` command

```bash
curl localhost:8000
```

It should be print out the application and its port number

## Configuring nginx

For the nginx configuration, the main configurations section can be found in the following directory `/etc/nginx/`. The default configuration imports configs from the `/etc/nginx/sites-enabled` folder. But the files in this folder is symlinked to the files in the `/etc/nginx/sites-available` folder. Which would eventually mean the following workflow:

1. Create the nginx configuration required in the sites-available folder
2. Create the symlinked folder
3. Check that nginx configuration is valid and can be loaded with no issues
4. Actually reload the nginx configuration and watch how nginx would work its magic

### Configuring nginx

Firstly, we would need to add the configuration to the sites-available folder. The following config below can be added. Let's say we added it as testConfig

```
server {
    listen 80;
    listen [::]:80;

    location /test1 {
      return 302 /test1/;
    }

    location /test2 {
      return 302 /test2/;
    }

    location /test3 {
      return 302 /test3/;
    }

    location /test1/ {
      proxy_pass http://localhost:8000/;
    }

    location /test2/ {
      proxy_pass http://localhost:8001/;
    }

    location /test3/ {
      proxy_pass http://localhost:8002/;
    }
}
```

Notice that there is a `/test1` and `/test1/`. The slash at the back of the matters a lot here. Without it, it would only mean that all configs that has path ends there. There are no further paths that extend beyond that. E.g. If we only have `/test1`, then `http://example.com/test1` and `https://example.com/test1/test/test` all lead to `http://example.com/test1`. With the slash at the back, the paths can then be interpreted properly.

With the above configuration, we would have `test1` path hit for `localhost:8000` backend. The `test2` path would hit for `localhost:8001` and the `test3` path would hit for `localhost:8002` endpoint.

### Creating symlinked file on sites-enabled

We would then need to creat the symlinked file on the `sites-enabled` folder.

Use the following command:

```bash
# Assuming that you're in the sites-enabled folder
# This would create a test1 symlink to your test1 nginx symlink file
ln -s ../sites-available/test1 test1
```

### Checking nginx configuration is fine

Use the following command to see what nginx has for its configuration right now and to check whether configurations specified in the files is what that is expected

```bash
sudo nginx -t

# OR

sudo nginx -T
```

If there are any issues in the nginx files, it would probably gripe and complain; (it also tells you the exact line where it doesn't accept the configuration which is quite nice. So that would allow us to quickly iterate and create a valid configuration)

### Reload nginx

For many linux systems out there, there has been a shift to use `systemd`. We can use that to serve to control our nginx process. So, we can refresh the configurations on nginx (without it going down)

```bash
sudo systemctl reload nginx
```

After running that command above without any issues, it can be assumed that nginx reloaded with no issues. We can proceed to pummel nginx with our requests and servers. Try curling the server to see if it works accordingly.

```bash
# Assuming that you're on the server
curl localhost/test1
curl localhost/test1/status
curl localhost/test2
curl localhost/test3
```

## Final thoughts

With the above, we can potentially mix and match the rules on the server that can provide us the configuration we want. In the case above, we have an nginx ingress that would send the traffic inside our server to the multiple backends but if you think it from a multi server point of view; that would make more sense. Imaging going to a service provider, and the provider offered several ip address that you would need to call. To get your job done, it would require you could call these multiple ip addressees -> that would be a hard to use service.

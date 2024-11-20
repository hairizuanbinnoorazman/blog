+++
title = "Using systemd to manage services"
description = "Using systemd to manage services, capture logs, restrict resources and manage scheduled executions of the application"
tags = [
    "golang",
]
date = "2021-06-10"
categories = [
    "golang",
]
+++

## What and why systemd?

Systemd is a convenient set of tooling that can be used to manage services and applications on a linux server. When we are managing applications on a server, we would want the following properties automatically for most application - the requirements are somewhat for most applications:

- Application should be able to restart if application panics/errors out
- Application should start even if we rebooted the server
- Logs should be able to handled by a tool that should hopefully do log rotation

It would be good to follow the filesystem when putting the files on the server https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard 

## Managing golang app with systemd

The golang application that is to be deployed is this. It is just a simple golang application serving some quick text data:

```golang
package main

import (
	"fmt"
	"log"
	"net/http"
)

func main() {
	port := 8888

	http.HandleFunc("/", helloWorldHandler)

	log.Printf("Server starting on port %v\n", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("serving", r.URL)
	fmt.Fprint(w, "This is a test. Hello World Miaoza!!\n")
}
```

To build the golang application on a mac, we would probably need to cross compile.

```bash
GOOS=linux GOARCH=amd64 go build -o golang-app app.go
```

We would need to create the `golang-app` linux user. The user needs to be created to be used to run the application. We would also probably need to copy the application binary for 

```bash
# In the case we need to generate new ssh keygen
# NOTE: We may need to connect to public ip
ssh-keygen -t ed25519
scp -i <ssh file> <local file> <remote file location>
ssh -i <ssh file> <username>@<local ip address>

sudo useradd golang-app
sudo mv ~/golang-app /usr/local/bin/golang-app
sudo vim /etc/systemd/system/golang-app.service
sudo systemctl enable golang-app
sudo systemctl start golang-app
sudo systemctl status golang-app

# To view logs of the application
sudo journalctl -u golang-app -f
```

A simple systemd configuration file to run this application. Save the following configuration to `/etc/systemd/system/golang-app.service`

```
[Unit]
Description=Golang Application
Requires=network-online.target
After=network-online.target

[Service]
User=golang-app
Group=golang-app
Restart=on-failure
ExecStart=/usr/local/bin/golang-app
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
```

For `[Install]` section, refer to https://unix.stackexchange.com/questions/404667/systemd-service-what-is-multi-user-target

To test the application on the server, we would need to be in the terminal of the linux server and use `wget` or `curl` to get a http response against the application.

```bash
curl http://localhost:8888
```

## Bonus Content: Use nginx to access application

Port 8888 is not a common port that is being used by most people. It is best to stick to well known ports for accessing websites - for insecure http websites; it will be port 80. For accessing websites in secure fashion protected by ssl certificates, it will be port 443.

If we simply just change our code to use port 80, we will see the following error:

```bash
Nov 20 14:55:08 instance-20241120-143311 systemd[1]: Stopped golang-app.service - Golang Application.
Nov 20 14:55:08 instance-20241120-143311 systemd[1]: Started golang-app.service - Golang Application.
Nov 20 14:55:08 instance-20241120-143311 golang-app[1367]: 2024/11/20 14:55:08 Server starting on port 80
Nov 20 14:55:08 instance-20241120-143311 golang-app[1367]: 2024/11/20 14:55:08 listen tcp :80: bind: permission denied
Nov 20 14:55:08 instance-20241120-143311 systemd[1]: golang-app.service: Main process exited, code=exited, status=1/FAILURE
```

Reason for this is because the initial set of ports below 1000 being priviliged ports.

Instead of doing some trickery/hackery to get this to work, we can simply rely on nginx - nginx already has developed a mechanism where nginx (a pretty mature application) - it is a common ways to do this

```bash
sudo apt install nginx
```

We then need to add some configuration in nginx to point nginx to our application.

```text
        server_name _;

        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
				# We simply need to comment out the following line and then add proxy_pass
                #try_files $uri $uri/ =404;
                proxy_pass http://localhost:8888;
        }
```

This would then allow us to access the web application from port 80 without changing the user for our application to be root user.

## Configuration via Environment variables

There are a couple of ways to configure our application:

- Extract configuration from a external provider (e.g. Secrets Manager?)
- Configuration file
- Environment variables

For extracting configuration from external provider, if we're using a cloud provider, we can have utilize the service account attached to virtual machine to access the apis accordingly.

In the case of a configuration file, we would usually code out our application to be able to read files via usual functions that would read and parse the files. The configuration files can be in various formats such as yaml, json, toml etc. This mechanism isn't too affected by us deploying a service and managing it via systemd.

However, when it comes environment variables - this is the one that would be different. Systemd has a approach to pass environment variables on a per service level (e.g. we can 2 or 3 different long lived serivces managed by systemd and each of them can have entirely different configured environment setups)

```golang
package main

import (
	"fmt"
	"log"
	"os"
	"net/http"
)

func main() {
	port := 8888

	applicationName := os.Getenv("APPLICATION_NAME")
	if applicationName == "" {
		fmt.Println("APPLICATION_NAME environment variable is unset")
	} else {
		fmt.Printf("APPLICATION_NAME environment set: %v\n", applicationName)
	}

	http.HandleFunc("/", helloWorldHandler)

	log.Printf("Server starting on port %v\n", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("serving", r.URL)
	fmt.Fprint(w, "This is a test. Hello World Miaoza!!\n")
}
```

We need to alter our systemd file slightly by adding the following in the `[Service]` section.

```bash
Environment="APPLICATION_NAME=miao"
```

```bash
[Unit]
Description=Golang Application
Requires=network-online.target
After=network-online.target

[Service]
Environment="APPLICATION_NAME=miao"
User=golang-app
Group=golang-app
Restart=on-failure
ExecStart=/usr/local/bin/golang-app
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
```

Once we made the change, we would then need to reload it and then restart the service.

```bash
sudo systemctl daemon-reload
sudo systemctl restart golang-app
```

## Limiting resources via systemd

The above set of files and configuration is to setup a basic golang application that can be managed with systemctl. Let's change it up and see another feature that comes along with systemd - it can be used to restrict resources for a application. We can limit cpu, memory, io, tasks etc.

In the following example, we would have an application that would keep allocating large portions of memory. Once it hits a the 1 Gigabyte limit, application should crash (in order to demonstrate the limits being set on the application)

We would keep appending a set of bytes to the `storeValue` variable - the number of times the set of bytes is appended to the `storeValue` will be logged out.

```golang
package main

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
)

var storeValue = [][]byte{}

func main() {
	port := 8888

	http.HandleFunc("/", helloWorldHandler)

	log.Printf("Server starting on port %v\n", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%v", port), nil))
}

func helloWorldHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("serving", r.URL)
	num := r.URL.Query().Get("number")
	n, err := strconv.Atoi(num)
	if err != nil {
		n = 5
	}
	for i := 0; i < n; i++ {
		a := []byte("abcdefghijklmnopqrstuvwxyz")
		storeValue = append(storeValue, a)
	}
	log.Printf("Size of data: %v", len(storeValue))
	fmt.Fprint(w, fmt.Sprintf("Added %v memory blocks", n))
}
```

Some resource configuration settings to handle: https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html

```bash
sudo mv ~/golang-app /usr/local/bin/golang-app
sudo vim /etc/systemd/system/golang-app.service

# To check that the settings was set correctly
sudo systemctl daemon-reload
sudo systemctl show golang-app
sudo systemctl restart golang-app
```

The important parts to be added would be:

```
MemoryAccounting=true
MemoryMax=1G
```

The full systemctl file for the golang application is this:

```
[Unit]
Description=Golang Application
Requires=network-online.target
After=network-online.target

[Service]
User=golang-app
Group=golang-app
Restart=on-failure
ExecStart=/usr/local/bin/golang-app
KillSignal=SIGTERM
MemoryAccounting=true
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```

In order to understand this, we can check the status of the application via systemctl calls. Notice the memory field and how there is a "maximum" value there.

```bash
● golang-app.service - Golang Application
   Loaded: loaded (/etc/systemd/system/golang-app.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2021-06-12 19:30:08 UTC; 5min ago
 Main PID: 1124 (golang-app)
    Tasks: 5 (limit: 4665)
   Memory: 4.5M (max: 1.0G)
   CGroup: /system.slice/golang-app.service
           └─1124 /usr/local/bin/golang-app
```

With that, if we run the following curl commands multiple times, we would eventually hit the 1Gb memory max limit. Once this is crossed, essentially, our application would hit a OOM error and will be forced to stop. The application will restart immediately after that (depends on systemd configuration of the app). We can use other utilities such as top to monitor resource utilization on the server

```bash
curl localhost:8888?number=1000000
```

## Using systemd for cron jobs

Let's switch up things once more and show another interesting capability; apparently, systemctl can be used to handle periodic task type of application.

A single shot application to showcase this feature would be simply to print the date and time

```golang
package main

import (
	"log"
	"time"
)

func main() {
	log.Printf("Current Time: %v", time.Now())
}
```

Building the application

```bash
GOOS=linux GOARCH=amd64 go build -o golang-time-printer app.go
```

We would then need to do similar steps as above to copy binary files over as well as to create the 2 systemctl files in order to setup the periodic tasks. Once more, we need to need to copy the binary over, and create the require systemctl files etc.

```bash
scp -i <ssh file> <local file> <remote file location>
sudo mv ~/golang-time-printer /usr/local/bin/golang-time-printer
sudo vim /etc/systemd/system/golang-time-printer.service
sudo systemctl enable golang-time-printer
sudo systemctl start golang-time-printer
sudo systemctl status golang-time-printer
```

Save the following service file in `/etc/systemd/system/golang-time-printer.service`

```
[Unit]
Description=Print the date and time
Wants=golang-time-printer.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/golang-time-printer

[Install]
WantedBy=multi-user.target
```

Save the following timer file `/etc/systemd/system/golang-time-printer.timer`. This would run the application defined by the `golang-time-printer.service` every minute.

```
[Unit]
Description=Print the date and time
Requires=golang-time-printer.service

[Timer]
Unit=golang-time-printer.service
OnCalendar=*-*-* *:*:00

[Install]
WantedBy=timers.target
```

We can check status of timer via the following command

```bash
sudo systemctl enable golang-time-printer.timer
sudo systemctl start golang-time-printer.timer
sudo systemctl status golang-time-printer.timer
sudo systemctl list-timers 
```

This would be an example of output of the timer

```
● golang-time-printer.timer - Print the date and time
   Loaded: loaded (/etc/systemd/system/golang-time-printer.timer; enabled; vendor preset: enabled)
   Active: active (waiting) since Sat 2021-06-12 19:56:56 UTC; 1min 13s ago
  Trigger: Sat 2021-06-12 19:59:00 UTC; 49s left

Jun 12 19:56:56 instance-1 systemd[1]: Started Print the date and time.
```

If we are to list the timers via systemctl command

```
NEXT                         LEFT          LAST                         PASSED    UNIT                         ACTIVATES
Sat 2021-06-12 20:00:00 UTC  50s left      Sat 2021-06-12 19:59:04 UTC  5s ago    golang-time-printer.timer    golang-time-printer
```

We can check the logs via journald

```bash
sudo journalctl -u golang-time-printer -f
```

These are sample of some of the logs

```bash
Jun 12 19:58:02 instance-1 systemd[1]: golang-time-printer.service: Succeeded.
Jun 12 19:58:02 instance-1 systemd[1]: Started Print the date and time.
Jun 12 19:59:04 instance-1 systemd[1]: Starting Print the date and time...
Jun 12 19:59:04 instance-1 golang-time-printer[1717]: 2021/06/12 19:59:04 Current Time: 2021-06-12 19:59:04.16838165 +0000 UTC m=+0.000189497
Jun 12 19:59:04 instance-1 systemd[1]: golang-time-printer.service: Succeeded.
Jun 12 19:59:04 instance-1 systemd[1]: Started Print the date and time.
Jun 12 20:00:01 instance-1 systemd[1]: Starting Print the date and time...
Jun 12 20:00:01 instance-1 golang-time-printer[1738]: 2021/06/12 20:00:01 Current Time: 2021-06-12 20:00:01.763439136 +0000 UTC m=+0.000099331
Jun 12 20:00:01 instance-1 systemd[1]: golang-time-printer.service: Succeeded.
```

As compared to previous ways of managing such periodic tasks such as cron. The nice part that having periodic tasks being managed by systemctl is that all logs is managed by a single interface; there is no need to figure out for each cron task on how logs are managed, how much resources is run, and how frequently the task is run
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

Systemd is a convenient set of tooling that can be used to manage services and applications on a linux server.

It would be good to follow the filesystem when putting the files on the server https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard 

For `[Install]` section, refer to https://unix.stackexchange.com/questions/404667/systemd-service-what-is-multi-user-target

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
sudo useradd golang-app
scp -i <ssh file> <local file> <remote file location>
sudo mv ~/golang-app /usr/local/bin/golang-app
sudo vim /etc/systemd/system/golang-app.service
sudo systemctl enable golang-app
sudo systemctl start golang-app
sudo systemctl status golang-app
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

To test the application on the server, we would need to be in the terminal of the linux server and use `wget` or `curl` to get a http response against the application.

```bash
curl http://localhost:8888
```

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
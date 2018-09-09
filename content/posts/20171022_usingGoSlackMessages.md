+++
title = "Using Go to post messages on Slack"
description = "Posting messages on Slack via Go - a basic sample Go script"
tags = [
    "golang",
]
date = "2017-10-22"
categories = [
    "golang",
]
+++

A sample application to kind of get started with Go.

This application involves pinging a channel on Slack via a webhook. Slack provides a unique URL in order to ping Slack with messages from a script/application.

```go
/*
Example of using Go to ping Slack
This would ping a message by the text message passed via postMessage function

In order to utilize this file, use the command: go run slack_example.go
Else, generate a binary file by running the command: go build slack_example.go
*/
package main

import (
	"fmt"

	"encoding/json"
	"bytes"
	"io/ioutil"

	"net/http"
)

type message struct {
	Text string    `json:"text"`
}

func postMessage(msg string) {
	slackUrl := "https://hooks.slack.com/services/{KEYS}"

	// Create a reader to be used by http.Post
	response := message{Text: msg}
	body, _ := json.Marshal(response)
	byteBody := bytes.NewReader(body)

	res, err := http.Post(slackUrl, "application/json", byteBody)
	if err != nil {
		fmt.Println(err.Error())
		fmt.Println("Try again later.")
	}

	fmt.Println("Status of response:", res.Status)
	fmt.Println("Status code of response:", res.StatusCode)
	content, err := ioutil.ReadAll(res.Body)
	if err != nil {
		fmt.Println(err.Error())
	}
	fmt.Println(string(content))
}

func main() {
	fmt.Println("A test application to fire a message into Slack")
	postMessage("init")
}
```

Some of the concepts introduced here:

- Introduction to a variety of libraries from std package
- Introduction to go tool chain, namely go build, go install
- Some improvements can be made to the above program by allowing it to made into a proper command line tool. This would include accepting of arguments, parsing them and them sending them of to the slack channel. A possible command line library that can be created from this could be the `cobra`. https://github.com/spf13/cobra

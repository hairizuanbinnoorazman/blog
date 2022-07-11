+++
title = "Fake Redis Server built with Golang"
description = "Building Redis Server interface with Golang and interact with it with redis-cli"
tags = [
    "golang",
]
date = "2022-07-20"
categories = [
    "golang",
]
+++

A friend of mine once mentioned about one of the tasks that he had to go through during his programming days was to build out a server which would respond to the redis-cli tool and I started to think - "that's something I've never done before... I wonder how hard it is?" After a day of tinkering around - it's definitely something that's not "intuitive" to immediately get done; there are definitely some concepts that I'm not super clear about but it's definitely something that can be slowly built out while learning various concepts.

There are definitely some good learnings that can be obtained while building out such a server. 

- Generally, common server examples assume that client and servers would be interacting with already established/built protocols such as JSON or GRPC protocols. There are already plenty of practical examples for handling incoming traffic but definitely very few examples of how one can built a server that would interact with the "redis protocol" coming from the redis-cli tool. This is definitely the main reference document when trying to build it: https://redis.io/docs/reference/protocol-spec/
- Finally come across example "algorithm" questions from Computer science classes which throws the most awkward set of arrays and request for one to try to solve it. Some of the algorithm questions I've seen before would be: Given an array where the first item of the array lists the number of items that would be array as well as metadata and data being interweaved in the array - compute a response for it. (Just the vague recall of such computer science questions). In the case of redis, an example of this would be something like this: `["*1", "$4", "ping"]` - where the first item indicates there would be "one" piece of data that would be vital to be processed; the second item in the array indicates the length of the data (i guess it's more for optimization? To ensure that the right sized array is provisioned for the incoming data) while the third piece of item in this array is "ping". The first piece of data generally tends to be the "command" that we would want the server handle - ping is an example, but we could have `get`, `set`, `lpush` etc

With that out of the way, here is some sample code in Golang that codes out a REDIS server that responds to `ping`, `set`, `get`, `lpush` and `lrange`. (Responds but may give the wrong answer at times?)

```golang
package main

import (
	"bufio"
	"fmt"
	"net"
	"strconv"
)

func main() {
	fmt.Println("Start server")
	defer fmt.Println("Stop server")
	ln, _ := net.Listen("tcp", ":6379")

	sstore := map[string]string{}
	store := map[string][]string{}

	for {
		conn, _ := ln.Accept()
		scanner := bufio.NewScanner(conn)
		c := Command{sstore: sstore, store: store, conn: conn}
		inputEntry := 0
		for {
			if ok := scanner.Scan(); !ok {
				break
			}
			rawInput := scanner.Text()
			fmt.Println(rawInput)
			if inputEntry == 2 {
				c.name = rawInput
			}
			if inputEntry == 4 {
				c.listName = rawInput
			}
			if inputEntry == 6 {
				c.itemVal = rawInput
			}
			if inputEntry == 8 {
				c.itemVal2 = rawInput
			}
			c.Run()
			inputEntry = inputEntry + 1
		}
	}
}

type Command struct {
	sstore   map[string]string
	store    map[string][]string
	conn     net.Conn
	name     string
	listName string
	itemVal  string
	itemVal2 string
}

func (c *Command) Run() {
	if c.name == "ping" {
		PrintPong(c.conn)
	}
	if c.name == "set" && c.listName != "" && c.itemVal != "" {
		c.sstore[c.listName] = c.itemVal
		c.conn.Write([]byte("+OK\r\n"))
	}
	if c.name == "get" && c.listName != "" {
		val := c.sstore[c.listName]
		processed := fmt.Sprintf("$%v\r\n%v\r\n", len(val), val)
		c.conn.Write([]byte(processed))
	}
	if c.name == "lpush" && c.listName != "" && c.itemVal != "" {
		c.store[c.listName] = append([]string{c.itemVal}, c.store[c.listName]...)
		c.conn.Write([]byte(fmt.Sprintf(":%v\r\n", len(c.store[c.listName]))))
	}
	if c.name == "lrange" && c.listName != "" && c.itemVal != "" && c.itemVal2 != "" {
		// c.itemVal is "starting value"
		// c.itemVal2 is "ending value" - if more -> it would mean everything
		startIdx, _ := strconv.Atoi(c.itemVal)
		endIdx, _ := strconv.Atoi(c.itemVal2)
		items := c.store[c.listName]
		if startIdx >= len(items) {
			c.conn.Write([]byte("*0\r\n"))
		} else if endIdx < len(items) && endIdx >= 0 {
			items = items[startIdx : endIdx+1]
		} else if endIdx >= len(items) || endIdx < 0 {
			items = items[startIdx:]
		}
		processed := fmt.Sprintf("*%v\r\n", len(items))
		for _, j := range items {
			processed = processed + fmt.Sprintf("$%v\r\n%v\r\n", len(j), j)
		}
		fmt.Println(processed)
		c.conn.Write([]byte(processed))
	}
}

func PrintPong(conn net.Conn) {
	conn.Write([]byte("+PONG\r\n"))
}

```

A few things to note regarding about the above piece of code:

- It does not support interactive mode of redis-cli (just typing `redis-cli` in terminal)
- It supports very few commands (but some may not even give accurate responds)
- It does not validate inputs (e.g. for `lrange` command - we expect 3 inputs; listname, start index and end index to retrieve. Current code above only "hangs" if incomplete inputs provided)

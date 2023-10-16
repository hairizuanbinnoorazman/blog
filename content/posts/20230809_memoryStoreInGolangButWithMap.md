+++
title = "Writing code to store items in memory with Golang but with maps"
description = "Code to store items in slices via Golang but with maps"
tags = [
    "golang",
]
date = "2023-08-09"
categories = [
    "golang",
]
+++

The following blog post is a continuation of the previous blog post on [Writing code to store items in memory with Golang](/writing-code-to-store-items-in-memory-with-golang). The previous blog post was mostly to cover simpler cases where we storing something simple like data in a single array/slice. However, let's say if we were to expand our use case to store in some sort of map instead (I know there is a concurrent hashmap version but let's pretend it doesn't exist here). How shall we build a store which uses hashmap to store key value pairs.

Our memory store would need a way to do the following:

- Store key-value pairs
- Get value of key value pair
- Delete a key value pair

All actual manipulation of the hashmap object would require us to control its access - there should be concurrent access as there might lead to data races leading to inconsistent and unexpected results. That would be mean that the store and delete operations would require a channel that would be handled by a single worker.

```golang
type storeItem struct {
	Key   string
	Value string
}

type MemoryMapStore struct {
	items      map[string]string
	addChan    chan storeItem
	deleteChan chan string
}
```

We need to pass both key and value pairs to the channel - so we'll have the channel take in a custom struct; which is in this case is our `storeItem` struct.

While creating the MemoryMapStore - we should also start the single goroutine that would deal with adding and removing of key value pairs from the items hashmap. This can be done via the following piece of code:

```golang
func NewMemoryMapStore() *MemoryMapStore {
	initMap := map[string]string{}
	aChan := make(chan storeItem)
	dChan := make(chan string)
	m := MemoryMapStore{
		items:      initMap,
		addChan:    aChan,
		deleteChan: dChan,
	}
	go m.runner()
	return &m
}

func (m *MemoryMapStore) runner() {
	for {
		select {
		case x := <-m.addChan:
			m.items[x.Key] = x.Value
		case y := <-m.deleteChan:
			delete(m.items, y)
		}
	}
}
```

With the `NewMemoryMapStore` function, it would start the runner function that will deal and handle the incoming data into the channels.

The next step is to write up our `Store`, `Get` and `Delete` functions.

```golang
func (m *MemoryMapStore) Store(key, value string) {
	m.addChan <- storeItem{key, value}
}

func (m *MemoryMapStore) Get(key string) (value string) {
	return m.items[key]
}
func (m *MemoryMapStore) Delete(key string) {
	m.deleteChan <- key
}
```

We can then simulate on whether the following data store works by running the following in the `main` function.

```golang
func main() {
	a := NewMemoryMapStore()

	for i := 0; i < 10000; i++ {
		val := strconv.Itoa(i)
		go a.Store(val, val)
	}

	time.Sleep(5 * time.Second)
	fmt.Println(len(a.items))

	for i := 0; i < 1000; i++ {
		val := strconv.Itoa(i)
		go a.Delete(val)
	}

	time.Sleep(5 * time.Second)
	fmt.Println(len(a.items))

}
```

It should print `10000` and then subsequently, `9000`. We can increase the number of goroutines and it should still mathematically compute (only thing to take note is the impact on CPU as it's actually utilizing resources on your computer)

This simply an exercise to understand how we can utilzie channels to handle concurrency to store and handle data that was not originally built to deal with data in a concurrent fashion.

The full code would be this:

```golang
package main

import (
	"fmt"
	"strconv"
	"time"
)

func main() {
	a := NewMemoryMapStore()

	for i := 0; i < 10000; i++ {
		val := strconv.Itoa(i)
		go a.Store(val, val)
	}

	time.Sleep(5 * time.Second)
	fmt.Println(len(a.items))

	for i := 0; i < 1000; i++ {
		val := strconv.Itoa(i)
		go a.Delete(val)
	}

	time.Sleep(5 * time.Second)
	fmt.Println(len(a.items))

}

type storeItem struct {
	Key   string
	Value string
}

type MemoryMapStore struct {
	items      map[string]string
	addChan    chan storeItem
	deleteChan chan string
}

func NewMemoryMapStore() *MemoryMapStore {
	initMap := map[string]string{}
	aChan := make(chan storeItem)
	dChan := make(chan string)
	m := MemoryMapStore{
		items:      initMap,
		addChan:    aChan,
		deleteChan: dChan,
	}
	go m.runner()
	return &m
}

func (m *MemoryMapStore) runner() {
	for {
		select {
		case x := <-m.addChan:
			m.items[x.Key] = x.Value
		case y := <-m.deleteChan:
			delete(m.items, y)
		}
	}
}

func (m *MemoryMapStore) Store(key, value string) {
	m.addChan <- storeItem{key, value}
}

func (m *MemoryMapStore) Get(key string) (value string) {
	return m.items[key]
}
func (m *MemoryMapStore) Delete(key string) {
	m.deleteChan <- key
}

```

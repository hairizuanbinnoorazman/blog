+++
title = "Writing code to store items in memory with Golang"
description = "Code to store items in slices via Golang"
tags = [
    "golang",
]
date = "2023-08-02"
categories = [
    "golang",
]
+++

I have a small tiny application that is a http api server that is meant to store data temporarily in memory. There is no need to persist data into any file or even database. The data that is to be stored doesn't need to persist across restarts - hence, making it nonsensical to rely on files or databases.

Technically, I can rely on a tool like Redis but that would mean to rely on another component (for a small piece of data). Redis is somewhat overkill here for this tiny in application - Redis provides a lot of functionality but all I need a "something" where I can push/pull data from it. Also, there will only be 1 instance of the http api server - which means it doesn't make too much sense to setup redis to allow multiple api servers to access the "central" memory store.

If one is to build such a memory store naive in Golang - it will cause some slight issues. Let's see a potential naive implementation.

This would be the interface that would be used within the `main.go`

```golang
type Store interface {
	Store(x int)
	View() []int
}
```

Let's say our memory store implemtation looks like this:

```golang
type MemoryStore struct {
	items []int
}

func NewMemoryStore() *MemoryStore {
	m := MemoryStore{
		items: []int{},
	}
	return &m
}

func (m *MemoryStore) Store(x int) {
    m.items = append(m.items, x)
}

func (m *MemoryStore) View() []int {
	dst := make([]int, len(m.items))
	copy(dst, m.items)
	return dst
}
```

We can test the implementation by having this in our `main.go` file. Note that we would need to check and ensure that our memory store is able to handle concurrent store/view requests and is able to return responses in a consistent fashion. Each iteration/round of tests should always be giving the same response over and over again - if we put in 10 data points into it, it should return 10 data points. To ensure that it would be able to handle concurrent requests to store data - we can use the `go` keyword to start separate goroutines to push data in parallel into the Memory Store.

```golang
func main() {
	z := store.NewMemoryStore()
	hoho(z)
	time.Sleep(15 * time.Second)
	fmt.Println(len(z.View()))
}

func Adder(a store.Store, x int) {
	for i := 0; i < 10; i++ {
		a.Store(x)
		time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
	}
}

func hoho(a store.Store) {
	for i := 0; i < 5; i++ {
		go Adder(a, i)
	}
}
```

On this initial naive implementation - there isn't too much of issue on first glance. The above implemetation should return 50 items. Separate runs should always be returning 50 items. However, if we tried to increase the number of items and number of goroutines...

```golang
func Adder(a store.Store, x int) {
	for i := 0; i < 100; i++ {
		a.Store(x)
		time.Sleep(time.Duration(rand.Intn(100)) * time.Millisecond)
	}
}

func hoho(a store.Store) {
	for i := 0; i < 100; i++ {
		go Adder(a, i)
	}
}
```

We will start to see issues. The number of items that are stored at the end of the entire "store" step - the number of items that would be stored would very 9000-10000 items.

The issue is largely because within the `Store` function, it is mostly interacting with a variable that doesn't exactly support access in parallel. There is a potential for data race happening here (which would occur at a higher frequency when we have a a large number of goroutines attempting to access it). In order to resolve it, we can try to look around and go for a "fan in" approach when attempting to have a variable that may have parallel requests/modifications happening at one time. This would involve having 1 single goroutine that would deal with modifications into the variable - no other goroutine should access/manipulate it. The goroutine could maybe pick up the variables that it would be put into it via channels.

The following modified version of the memory store is a better version of the above:

```golang
func NewMemoryStore() *MemoryStore {
	m := MemoryStore{
		items: []int{},
		zz:    make(chan int),
	}
	go m.start()
	return &m
}

func (m *MemoryStore) start() {
	for {
		select {
		case x := <-m.zz:
			m.items = append(m.items, x)
		}
	}
}

func (m *MemoryStore) Store(x int) {
	m.zz <- x
}

func (m *MemoryStore) View() []int {
	dst := make([]int, len(m.items))
	copy(dst, m.items)
	return dst
}

```

The important bit would be the following subsection of the above code:

```golang
func (m *MemoryStore) start() {
	for {
		select {
		case x := <-m.zz:
			m.items = append(m.items, x)
		}
	}
}
```

The following function is started on a separate golang routine that would be started within the `New` function. The code outside this module shouldn't be able to access the data directly to "protect" it from external influence/parallel modification to it.

Now, if we're to increase the number of goroutines in the `hoho` function to 5000 goroutines - it should be a non-issue -> there is only 1 writer and that would ensure that the data is going it is consistent.

+++
title = "Redis vs Memcached via Golang"
description = "Redis vs Memcached via Golang. Using Golang to test how using memcached and redis differs"
tags = [
    "golang",
    "docker",
]
date = "2023-07-05"
categories = [
    "golang",
    "docker",
]
+++

This is often a question that often comes up during system design interviews. If one were to design a system that requires the use of cache - one common question that comes up would be whether to use memcached or to use redis. On initial thought - both are kind of doing the same thing; both store stuff in memory which gives them pretty fast response times; however, both tools have entirely wildly different implementations and philosophies when it comes to the product - thereby - requiring developers to make tradeoffs when choosing between them.

The common things to ponder when it comes to that question of memcached vs redis would be this:

- Memcached is very simplistic; Redis is very feature reach, can store complex data models
- Memcached doesn't even have cluster mode; Redis allows cluster mode to handle higher throughput. (Means for memcached - "cluster" mode would need to rely on clients - clients would need to implement all that logic)
- Memcached is multi-threaded while redis is "single threaded". Means, if any operation is blocking, no requests can be served till it's done.

The following information is also in [Devops Interview Questions](/devops-interview-questions).

However, now let's look from a more detailed angle - how will this differences reflect when it comes to using it for applications.

## Using Golang to access Memcached

Weirdly enough, there isn't an "official" Golang module out there for supporting calls to Memcached. However, this package kind of comes up quite a bit with a quick search: https://pkg.go.dev/github.com/bradfitz/gomemcache/memcache

A very interesting thing to note would be the following line from the `README.md`.

```golang
mc := memcache.New("10.0.0.1:11211", "10.0.0.2:11211", "10.0.0.3:11212")
```

Apparently, this very line reflects the nature of how Memcached is really a simplistic tool and doesn't have a "clustering" solution. Clustering is a pretty complex feature to implement and it would kind of make sense to not add that feature unnecessarily. Many people already find Memcached useful as it is - so "technically", there isn't a need to add such features.

A simple usage of Golang with memcached can be done as follows:

First, we would need to run a memcached docker image:

```bash
docker run --name my-memcache -p 11211:11211 -d memcached:1.6 memcached -m 64
```

We can then run the following golang code (of course we need to setup the `go.mod` and `go.sum` file)

```golang
package main

import (
	"fmt"
	"time"

	"github.com/bradfitz/gomemcache/memcache"
)

func main() {
	mc := memcache.New("localhost:11211")
	mc.Set(&memcache.Item{Key: "foo", Value: []byte("my value")})
	zz, err := mc.Get("foo")
	if err != nil {
		panic(fmt.Sprintf("didnt expect error from gettting values from memcached %v", err))
	}
	fmt.Printf("Value of foo: %v\n", string(zz.Value))

	addErr := mc.Add(&memcache.Item{Key: "foo", Value: []byte("new value")})
	if addErr != nil {
		fmt.Printf("Add error: %v\n", addErr)
	}

	appendErr := mc.Append(&memcache.Item{Key: "foo", Value: []byte("new value")})
	if addErr != nil {
		fmt.Printf("Add error: %v\n", appendErr)
	}

	pp, _ := mc.Get("foo")
	fmt.Printf("Value of foo: %v\n", string(pp.Value))

	mc.Set(&memcache.Item{Key: "yar", Value: []byte("yar"), Expiration: 10})
	time.Sleep(5 * time.Second)
	yy, err := mc.Get("yar")
	if err != nil {
		panic(fmt.Sprintf("didnt expect error from gettting values from memcached %v\n", err))
	}
	fmt.Printf("Value of yar: %v\n", string(yy.Value))

	time.Sleep(6 * time.Second)
	_, err = mc.Get("yar")
	if err != nil {
		fmt.Printf("Expeccted error: %v\n", err)
	}

}
```

We aren't testing the client side sharding of memcached keys - it is kind of hard to fully demonstrate and test that functionality via simple code. With regards to how the keys are sharded - it is done by hashing the key and then calculating one of the server ids to be used.

## Using Golang to access Redis

When we start to look at the commands available when using Redis - we can clearly see how Redis is extremely feature-rich (and kind of overwhelming for first time users.). Redis comes with a lot of functionality and can be used to cover a pretty large variety of use cases. It even covers the case where redis keys can be used to write to a persistent store so that it can recover rather quickly in the case the server happens to "crash" in a disasterous fashion. (There doesn't seem to be mention if Memcached has such features.)

Let's see a clear example via Golang code of something that is supported in Redis but not supported in Memcached:

To start a redis server via docker:

```bash
docker run --name some-redis -p 6379:6379 -d redis 
```

Then we can use the following code to drive and test out some redis functionality:

```golang
package main

import (
	"context"
	"fmt"
	"time"

	redis "github.com/redis/go-redis/v9"
)

func main() {
	rdb := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "", // no password set
		DB:       0,  // use default DB
	})
	status := rdb.Set(context.TODO(), "foo", "zzz", 20*time.Second)
	if status.Err() != nil {
		panic(fmt.Sprintf("error observed: %v\n", status.Err()))
	}
	fmt.Printf("%+v\n", status)

	val := rdb.Get(context.TODO(), "foo")
	fmt.Printf("Value of foo: %v\n", val.Val())
	fmt.Printf("Value of foo: %v\n", val.String())

	zz := rdb.HSet(context.TODO(), "zzz", map[string]interface{}{"aa": "qcaca", "aqq": 12})
	if zz.Err() != nil {
		panic(fmt.Sprintf("zz error observed: %v\n", zz.Err()))
	}
	yy := rdb.HGet(context.TODO(), "zzz", "aqq")
	fmt.Printf("Value of zzz-aqq: %v\n", yy.Val())
}

```

Note the following functions `HSet` and `HGet`. The following funcgtions allow us to add a hashmap into redis - afterwhich, we can pull specific values out of it -> kind of similar to a "hashmap" in a "hashmap" sort of situation. In order to do something similar in Memcached - we would first to serialize our data structure to some sort of byte format which we can then store into value of the key in Memcached. To get a specific value - we would still need to extract it out, deserialize it and then pull the specific value out.

## Conclusion

Redis and Memcached are clearly 2 different products with completely different aims. Memcached remains to be a "sane" and simple choice while redis provides plenty of flexible options - the usage of which of the caching tool would be useful would all boil down the needs of the application to be built.

Probably in the future, I will try to cover other Redis functions via Golang in more detail.
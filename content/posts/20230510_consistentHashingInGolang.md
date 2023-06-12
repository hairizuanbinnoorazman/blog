+++
title = "Consistent Hashing Implementation in Golang"
description = "Consistent Hashing Implementation in Golang"
tags = [
    "golang",
]
date = "2023-05-10"
categories = [
    "golang",
]
+++

In the real world, we often have to deal with such large traffic loads that it is almost necessary to know that there is possibility that we might need to get data stored in a cluster of machines. In the case if we have applications that barely need to deal and manage data, we can simply on existing products out there that can simply scale out the number of replicas of the application which it can simply serve pretty easily. However, what about applications that rely on database? We need our database server cluster to also scale out accordingly as well (there are limits to scale vertically in most cloud providers after all)

## Initial naive approach to distribute data between server nodes

There are numerous approach to do this. One way would be to store data by leveraging some sort of metatable database to store references or metadata about the data (this will store the "primary key", while the actual data is stored in separate data nodes. This approach allows for efficient management and retrieval of data across the distributed system. The metatable database serves as a central repository that maintains information such as the location and characteristics of the data, while the data nodes store the actual content. This approach is how Hadoop does things - if you were to deploy a Hadoop cluster, you would know that you would need to deploy name servers (which serve to manage the metadata of where each data point is stored) as well as data nodes. However, this design come with massive flaw where if name server ever goes down - the hadoop cluster is essentially rendered "useless" since now, none of the clients would know where each of the data point would be stored.

Another approach when it comes to distributing data across multiple servers is to use a simple hashing algorithm. In this approach, the data to be stored is hashed using a hashing function, and the resulting hash value is used to determine the server to which the data should be assigned. The idea behind this approach is that by evenly distributing the data based on its hash value, the workload can be balanced across the servers. There is no dependency on some central server to determine where each data point is stored which is already a big plus. The initial naive approach would be to just take the hash and run modulus/division operations to get the server to store the piece of data on.

```golang
package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"math/big"
	"strconv"
)

var (
	data           []string = []string{}
	nodeAssignment []int    = []int{}

	initialNodeCount = 3
	dataCount = 1000
)

func hasher(v string) int64 {
	bi := big.NewInt(0)
	h := md5.New()
	h.Write([]byte(v))
	hexstr := hex.EncodeToString(h.Sum(nil))
	bi.SetString(hexstr, 16)

	value := bi.Int64()
	if value < 0 {
		value = value * -1
	}
	return value
}

func main() {
	for i := 0; i < dataCount; i++ {
		data = append(data, "weatherinsingaporehot"+strconv.Itoa(i))
	}

	for _, v := range data {
		value := hasher(v)

		nodeAssign := value % int64(initialNodeCount)
		nodeAssignment = append(nodeAssignment, int(nodeAssign))
	}

	fmt.Println(nodeAssignment)
}

```

For the above code snippet, we generate 1000 datapoints and it gets allocated across 3 servers of sorts. It is possible to change the number of nodes to make it seem like we have a bigger cluster size that we would need to balance our data across. An important thing that we would want to check is to see how balanced our data across our servers. The function to do so is a simple one where we add counts to some sort of hashmap.

```golang
func dataBalancingCounter(assignments []int) map[string]int {
	hoho := map[string]int{}

	for _, v := range assignments {
		hoho["node"+strconv.Itoa(v)] = hoho["node"+strconv.Itoa(v)] + 1
	}
	return hoho
}

```

The full golang code with this function would like this:

```golang
package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"math/big"
	"strconv"
)

var (
	data           []string = []string{}
	nodeAssignment []int    = []int{}

	initialNodeCount = 3
	dataCount = 1000
)

func dataBalancingCounter(assignments []int) map[string]int {
	hoho := map[string]int{}

	for _, v := range assignments {
		hoho["node"+strconv.Itoa(v)] = hoho["node"+strconv.Itoa(v)] + 1
	}
	return hoho
}

func hasher(v string) int64 {
	bi := big.NewInt(0)
	h := md5.New()
	h.Write([]byte(v))
	hexstr := hex.EncodeToString(h.Sum(nil))
	bi.SetString(hexstr, 16)

	value := bi.Int64()
	if value < 0 {
		value = value * -1
	}
	return value
}

func main() {
	for i := 0; i < dataCount; i++ {
		data = append(data, "weatherinsingaporehot"+strconv.Itoa(i))
	}

	for _, v := range data {
		value := hasher(v)

		nodeAssign := value % int64(initialNodeCount)
		nodeAssignment = append(nodeAssignment, int(nodeAssign))
	}

	fmt.Printf("split of data:\n%v\n", dataBalancingCounter(nodeAssignment))
}

```

Output of the following code is this:

```golang
split of data:
map[node0:323 node1:341 node2:336]
```

The split of data across the nodes is actually not too bad considering that we're not exactly storing any metadata to say where each data point is across the entire cluster. Upon receiving any traffic, each node would be able to point the request to another node accordingly that would serve the data point required for the request.

I wish we can simply end things here but the next section is probably the main reason why I'm even writing this post in the first place.

## Adding a new node (now you need to rebalance!)

Let's say we are in an "emergency" and we realize that our data storage nodes are maybe at 60-80% capacity and is somewhat close to dying due to workload put on it. The normal assumption here is that it should be possible to increase the number of data storage nodes to provide some sort of relief to the rest of the nodes and to allow for performance improvements across the entire cluster. The new node should be able to take up the load and should be able to start serving the required data to incoming traffic. However, in order for it to do this, the new storage node should hold on to some of said data from other nodes. How else would it be able to serve the traffic if it doesn't hold the data?

The whole process of having data being transfered between nodes during addition or removal or replacement of nodes is called data rebalancing. Data rebalancing across servers in a distributed system is a complex and challenging task, but it is crucial for maintaining system performance, load distribution, and fault tolerance. As the system evolves and scales, the data distribution among servers may become imbalanced due to various factors such as server failures, additions, or changes in data access patterns. This imbalance can lead to overloaded servers, increased latency, and inefficient resource utilization. Data rebalancing aims to address these issues by redistributing the data across servers in a more equitable and efficient manner. However, achieving seamless data rebalancing is difficult due to the need to minimize disruption to ongoing operations, ensure data consistency, and optimize network and storage resources.

Also, another point to take note is that now, our data no longer maps correctly to the right server based on our hashing function. It wouldn't make sense for us to have our data systems remember previous mappings for database. 

Let's take our previous naive approach and use it to reassign it to a large cluster of nodes. One additional calculation that we will need to do is to check the percentage that needs to be moved around.

```golang
package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"math/big"
	"strconv"
)

var (
	data             []string = []string{}
	nodeAssignment   []int    = []int{}
	nodeReassignment []int    = []int{}

	initialNodeCount = 3
	finalNodeCount   = 4
	dataCount        = 1000
)

func dataBalancingCounter(assignments []int) map[string]int {
	hoho := map[string]int{}

	for _, v := range assignments {
		hoho["node"+strconv.Itoa(v)] = hoho["node"+strconv.Itoa(v)] + 1
	}
	return hoho
}

func hasher(v string) int64 {
	bi := big.NewInt(0)
	h := md5.New()
	h.Write([]byte(v))
	hexstr := hex.EncodeToString(h.Sum(nil))
	bi.SetString(hexstr, 16)

	value := bi.Int64()
	if value < 0 {
		value = value * -1
	}
	return value
}

func main() {
	for i := 0; i < dataCount; i++ {
		data = append(data, "weatherinsingaporehot"+strconv.Itoa(i))
	}

	for _, v := range data {
		value := hasher(v)

		nodeAssign := value % int64(initialNodeCount)
		nodeAssignment = append(nodeAssignment, int(nodeAssign))

		nodeReassign2 := value % int64(finalNodeCount)
		nodeReassignment = append(nodeReassignment, int(nodeReassign2))

	}

	changeRequired := 0
	for i, _ := range nodeAssignment {
		if nodeAssignment[i] != nodeReassignment[i] {
			changeRequired = changeRequired + 1
		}
	}

	fmt.Printf("%v of the data is changed\n", float64(changeRequired)/float64(dataCount)*100)
	fmt.Printf("split of data:\n%v\n", dataBalancingCounter(nodeAssignment))
}

```

The output for the above code:

```bash
76.8 of the data is changed
split of data:
map[node0:240 node1:251 node2:244 node3:265]
```

Observe the pretty large percentage of data that needs to be moved around in order to rebalance our data to our new cluster size - its 76.8% of the data. With that amount of data, that would also mean that it will take a while for data to be rebalanced across the server nodes.

This is definitely an area to be optimized - it would nice to have something that can help optimize this further. (Of course there is, that's kind of the whole point of writing this blog post...)

## Consistent Hashing

Consistent hashing is one of the algorithms that has been thought of to try to tackle the following issue at its head. The algorithm was brought forward by a researcher to mainly solve load balancing issues but I suppose the industry saw that it can also be used similarly in just plenty of distributed systems in general.

The following post is somewhat an attempt to understand how consistent hashing can help with rebalancing of data between distributed data systems. Refer to the following video:

{{< youtube UF9Iqmg94tk >}}

Here are some other reference links that prove useful in trying to understand this need for consistent hashing.

- http://highscalability.com/blog/2023/2/22/consistent-hashing-algorithm.html

The following blog post from toptal https://www.toptal.com/big-data/consistent-hashing actually explains it best (I actually understood it quite a bit from reading the data sections at the middle section of the page) - most explanations for consistent hashing only gives an abstract idea of what it is trying to accomplish but the abstract ideas is still somewhat difficult to translate to some form of implementation.

I'll try to give a slightly tldr version here but it may be clearer to you in code. First step to the whole consistent hashing is to set up the idea of a hashring. Like the toptal blog mentioned, we can imagine some sort of circle where we would vizualize the data and servers to be.

In order to vizualize the data and servers, we would need to run them through our usual hashing function. Since we're working with a representation of circles with our hashring, it might be good to just imagine that we're trying to compute angles where the data would be vizualized at or where our servers would be vizualized at. Let's pretend that we're working with 3 servers here. For data, we can use the hash the primary key that would determine which server to store the data in. In the case for servers, we can probably choose to hash server ids which we can then map onto the hash ring.

![hashring_with_servers](/20230510_consistentHashingInGolang/hashring-with-servers.png)

Once we vizualized our servers onto the hashring, we can then vizualize our data point on the hashring. We would then need to think of methodology of how to assign. The simplest seems to be us going clockwise direction, and if the hashed data point is less that the hashed server, it would be assigned to it.

![hashring_with_servers_and_data](/20230510_consistentHashingInGolang/hashring-with-servers-and-data.png)

As we hash our servers to be mapped onto the hashring, there could be the possibility that the hashed servers could all be clumped in one section of the hashring? That would make it somewhat difficult to kind of ensure that our data points is actually assigned as equally as possibility across the nodes. Seeing this, we can instead just simply increase the number of "server" points on the hashring, - the whole concept of adding more points onto this hashring is called virtual nodes - this terminology is used across the industry. You can do a check for the cassandra database that heavily relies on these set of concepts; for cassandra, they shortened the term of virtual nodes to vnodes.

Rather than us going on and on about how consistent hashing algorithm works, we can simply look at some code to see if how it performs. We shall do the same thing as our previous approach of simply using modulus - we would calculate the balance of the data across our server nodes as well as see the percentage change of data that needs to migrate to other nodes. 

```golang
package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"math/big"
	"sort"
	"strconv"
)

var (
	data                   []string = []string{}
	consistentAssignment   []int    = []int{}
	consistentReassignment []int    = []int{}

	initialNodeCount            = 3
	finalNodeCount              = 4
	dataCount                   = 1000
	virtualNodeMultiplier int64 = 10
)

type logicalServer struct {
	Node  int64
	Name  string
	Angle float64
}

type logicalServers []logicalServer

func (l logicalServers) Len() int           { return len(l) }
func (l logicalServers) Less(i, j int) bool { return l[i].Angle < l[j].Angle }
func (l logicalServers) Swap(i, j int)      { l[i], l[j] = l[j], l[i] }
func (l logicalServers) Sort()              { sort.Sort(l) }

func createLogicalServerList(virtualNodeMultiplier, nodes int64) []logicalServer {
	ls := []logicalServer{}
	for i := 0; i < int(nodes); i++ {
		for j := 0; j < int(virtualNodeMultiplier); j++ {
			nodeName := "node" + strconv.Itoa(i) + "-" + strconv.Itoa(j)
			ls = append(ls, logicalServer{
				Node:  int64(i),
				Name:  nodeName,
				Angle: float64(hasher(nodeName) % 360.0),
			})
		}
	}
	logicalServers(ls).Sort()
	return ls
}

func consistentAssign(ls []logicalServer, v int64) int64 {
	zz := float64(v % 360.0)
	initialAssign := -1
	for _, k := range ls {
		if zz > k.Angle {
			initialAssign = int(k.Node)
			continue
		}
		return k.Node
	}
	return int64(initialAssign)
}

func dataBalancingCounter(assignments []int) map[string]int {
	hoho := map[string]int{}

	for _, v := range assignments {
		hoho["node"+strconv.Itoa(v)] = hoho["node"+strconv.Itoa(v)] + 1
	}
	return hoho
}

func hasher(v string) int64 {
	bi := big.NewInt(0)
	h := md5.New()
	h.Write([]byte(v))
	hexstr := hex.EncodeToString(h.Sum(nil))
	bi.SetString(hexstr, 16)

	value := bi.Int64()
	if value < 0 {
		value = value * -1
	}
	return value
}

func main() {
	for i := 0; i < dataCount; i++ {
		data = append(data, "weatherinsingaporehot"+strconv.Itoa(i))
	}

	initialLogicalServerList := createLogicalServerList(virtualNodeMultiplier, int64(initialNodeCount))
	finalLogicalServerList := createLogicalServerList(virtualNodeMultiplier, int64(finalNodeCount))

	for _, v := range data {
		value := hasher(v)

		nodeAssign5 := consistentAssign(initialLogicalServerList, value)
		consistentAssignment = append(consistentAssignment, int(nodeAssign5))

		nodeAssign6 := consistentAssign(finalLogicalServerList, value)
		consistentReassignment = append(consistentReassignment, int(nodeAssign6))

	}

	consistentChangeRequired := 0
	for i, _ := range consistentAssignment {
		if consistentAssignment[i] != consistentReassignment[i] {
			consistentChangeRequired = consistentChangeRequired + 1
		}
	}

	fmt.Printf("%v of the data is changed\n", float64(consistentChangeRequired)/float64(dataCount)*100)
	fmt.Printf("split of data for consistent:\n%v\n", dataBalancingCounter(consistentReassignment))
}

```

The output of the following code:

```bash
25.2 of the data is changed
split of data for consistent:
map[node0:311 node1:253 node2:184 node3:252]
```

Notice the relatively big drop of percentage in % of changed data points across nodes. This is noticeable drop in a sense all thanks to the different algorithm being here. If we extend it out to 1,000,000 data points - 50% of the data not being moved around (70+% - 20+%) means about 500,000 data points not moved. These percentage affect way more in the larger scale as compared to the smaller scale.

The above consistent hashing implementation is not the most perfect. For our case, we only simply used a linear search to find and assign our data to a specific node on our cluster but this is definitely a case where we can rely on a binary search algorithm instead to quick skip redundant records.

## Conclusion

The above is simply one small segment of the distributed systems world. Distributed systems are generally really hard to build and manage and require a team of experts to do so - so much so that even on Kubernetes, there is a concept of building applications that is designed with the aims to replicate what these experts can do. 

Probably in a future blog post, I will probably build out a cluster of servers (that would represent a cluster of key-value store) that would distribute data and rebalance data across it. However, that would take a long while before I can build it - there are other concepts to understand as well (note: we didn't even talk about leader election which is a usual topic that is usually mentioned often in the distributed systems world)






+++
title = "Heap datastructure with Slices/Arrays in Golang"
description = "Heap datastructure with Slices/Arrays in Golang"
tags = [
    "golang",
]
date = "2023-07-19"
categories = [
    "golang",
]
+++

Part of the software engineer journey is to learn data structures - especially if one were to go for the software interviews. Surprising, data structures knowledge and familiarity with it becomes somewhat important in them - with knowledge with certain data strucutre, certain problems become somewhat easier (also, sometimes, all one can do is simply stare in wonder at the algorithms and data structures that people in the past created)

One relatively important data structure that kind of come up during my study of data strucutres is the heap data structure. It is often mentioned that one can utilize the heap data structures "max" values pretty easily.

The following page would show the heap data structure in better detail with diagrams etc:  
https://www.geeksforgeeks.org/heap-data-structure/

In most cases, the heap data structures - it is often represented or imagined as tress -> which is why, my initial test implementation of it is to somewhat build something close to this - like a tree:  

```golang
type Node struct {
	value int
	left  *Node
	right *Node
}

func Heapify(n *Node) *Node {
	if n.left == nil && n.right == nil {
		return n
	}

	if n.left != nil {
		n.left = Heapify(n.left)
	}

	if n.right != nil {
		n.right = Heapify(n.right)
	}

	if n.left != nil {
		if n.value < n.left.value {
			tempLeft := n.left.left
			tempRight := n.left.right
			currentRight := n.right
			currentLeft := n.left
			currentLeft.right = currentRight
			currentLeft.left = n
			n.left = tempLeft
			n.right = tempRight
			n = currentLeft
		}

	}

	if n.right != nil {
		if n.value < n.right.value {
			tempLeft := n.right.left
			tempRight := n.right.right
			currentRight := n.right
			currentLeft := n.left
			currentRight.right = n
			currentRight.left = currentLeft
			n.left = tempLeft
			n.right = tempRight
			n = currentRight
		}

	}
	return n
}

func Printer(n *Node) {
	if n.left != nil {
		Printer(n.left)
	}
	fmt.Println(n.value)
	if n.right != nil {
		Printer(n.right)
	}
}

```

We have a node data struct, which we would use as nodes in a tree. We can then simply keep calling `heapify` to get the "max" value and bubble it to the top. Unfortunately, the node struct version is way harder to build out within a coding interview session - there is too much code to handle for this.

We can test the above node struct version of a heap by running the following function:  

```
func nodeImplementation() {
	leftz := Node{value: 3}
	leftLeftz := Node{value: 4}
	rightz := Node{value: 2, right: &leftLeftz}
	topz := Node{value: 1, left: &leftz, right: &rightz}
	Printer(&topz)
	aa := Heapify(&topz)
	fmt.Println("after")
	Printer(aa)
	fmt.Println(aa.value)
}
```

Unfortunately, it is a bit harder to implemnent other useful and important functionality for a heap such as adding values to a heap or removing values from a heap. The code for making that is harder than expected.

Interestingly enough, there is a slice/array implementation of heaps. We would simply imagine the array laid out across the tree:

```bash
      0
    /   \
  1       2
 / \     / \
3   4   5   6
```

The above tree representation would show the index numbers of where it would be if it were to be represented in a slice/array.

The below code would be the implementation for the heap data structure used as an array. Important bit would be the formulas:

- Left side node: 2n + 1
- Right side node: 2n + 2
- Current node: n
- Parent node: (n-1)/2

The above formulas are to calculate the index-es of the other "nodes" on the array. Let's demonstrate by giving an example:

For node 1, the left node is 3 and 4. By using the formula for left side node -> 2 x 1 + 1 = 3; it shows that the calculation is right. It would be the side for the right side node as well. For the parent of 1 (which is 0...). We can use the calculation for it as well: (1-1)/2 = 0 -> which is also correct; the parent of "node 1" is 0.

The golang code for building a heap is the following:  

```golang
func ArrHeapify(nums []int, node int) {
	lhsIdx := 2*node + 1
	rhsIdx := 2*node + 2
	largestIdx := node

	if lhsIdx < len(nums) {
		if nums[lhsIdx] > nums[largestIdx] {
			largestIdx = lhsIdx
		}
	}

	if rhsIdx < len(nums) {
		if nums[rhsIdx] > nums[largestIdx] {
			largestIdx = rhsIdx
		}
	}

	if largestIdx != node {
		tempVal := nums[node]
		nums[node] = nums[largestIdx]
		nums[largestIdx] = tempVal
		ArrHeapify(nums, largestIdx)
	}
}
```

We can build the following driver code to test out our implementation:  

```golang
func main() {
	a := []int{1, 3, 5, 3, 6, 13, 10, 9, 8, 15, 17}
	fmt.Println(a)

	for i := (len(a) - 1) / 2; i >= 0; i-- {
		ArrHeapify(a, i)
	}
	fmt.Println(a)

	a = append(a, 90)
	for i := (len(a) - 1) / 2; i >= 0; i-- {
		ArrHeapify(a, i)
	}
	fmt.Println(a)
}
```

Naturally, the following piece of code is not perfect - but then again, for software interviews, it'll be something that we eventually have to be build without even thinking too much about it. Maybe I'll write a future blog post that will cover more details with it.

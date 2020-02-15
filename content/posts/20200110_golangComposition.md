+++
title = "Golang composition"
description = "Understanding golang further: composing interfaces/structs together"
tags = [
    "golang",
]
date = "2020-01-10"
categories = [
    "golang",
]
+++

These are some notes I took while experimenting and playing around with Golang further. This article is mainly exploring embedded structs and interfaces to experiment how they work etc.

Use Golang playground in order to see how it works in action

One can combine golang interfaces together to form large interfaces.

```go
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type ZZZ struct{}

func (z ZZZ) Hahax() {
	fmt.Println("ZZZ Hahax")
}

func (z ZZZ) Miao() {
	fmt.Println("ZZZ Miao")
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}
```

- Interface `CCC` is formed from interface `AAA` and `BBB`
- In order to fulfill requirements of `CCC`, struct `ZZZ` needs to implement both the `Hahax` and `Miao` functions.
- In order to understand where each function is being called from, we would have the function print out which struct it comes from and the name of its function.

The following code outputs the following

```bash
ZZZ Hahax
ZZZ Miao
```

We can take apart struct `ZZZ` and compose it from multiple structs instead

```golang
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type DD1 struct{}

func (z DD1) Hahax() {
	fmt.Println("DD1 Hahax")
}

type DD2 struct{}

func (z DD2) Miao() {
	fmt.Println("DD2 Miao")
}

type ZZZ struct {
	DD1
	DD2
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}

```

- Interface `CCC` is formed from interface `AAA` and `BBB`
- In order to fulfill requirements of `CCC`, struct `ZZZ` needs to implement both the `Hahax` and `Miao` functions.
- Struct `ZZZ` is composed of structs `DD1` and `DD2`. `DD1` implements the `Hahax` method while `DD2` implements the `Miao` method
- Similarly, in order to understand where each function is being called from, we would have the function print out which struct it comes from and the name of its function.

The following code would output the following:

```bash
DD1 Hahax
DD2 Miao
```

However, let's experiment further. What if `ZZZ` which is already composed `DD1` and `DD2` (which fulfills the requirements of `CCC`) also implements the `Hahax` function?

```golang
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type DD1 struct{}

func (z DD1) Hahax() {
	fmt.Println("DD1 Hahax")
}

type DD2 struct{}

func (z DD2) Miao() {
	fmt.Println("DD2 Miao")
}

type ZZZ struct {
	DD1
	DD2
}

func (z ZZZ) Hahax() {
	fmt.Println("ZZZ Hahax")
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}

```

The above code outputs the following instead.

```bash
ZZZ Hahax
DD2 Miao
```

Notice how as compared to previous situation, instead of printing out `DD1 Hahax`, it prints out `ZZZ Hahax` instead. So, there is some sort of level of hierarchy when functions are being called. If the list of function within that level has the `Hahax` function, it would call it; else, it would go down through the structs embedded within it and call it accordingly.

Now, let's experiment further. What if `DD2` does not implement the `Miao` function but instead, it embeds `DD3` which then implements the `Miao` function?

```golang
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type DD1 struct{}

func (z DD1) Hahax() {
	fmt.Println("DD1 Hahax")
}

type DD2 struct {
	DD3
}

type DD3 struct{}

func (z DD3) Miao() {
	fmt.Println("DD3 Miao")
}

type ZZZ struct {
	DD1
	DD2
}

func (z ZZZ) Hahax() {
	fmt.Println("ZZZ Hahax")
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}

```

And as expected, the following code outputs the following:

```bash
ZZZ Hahax
DD3 Miao
```

Apparently, it would recurse down the embedded structs and use the first `Miao` function observed.

If somehow, `DD1` also implements the `Miao` function, that it would it be expected that the `DD3 Miao` would not be printed but `DD1 Miao` would be printed instead.

```golang
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type DD1 struct{}

func (z DD1) Hahax() {
	fmt.Println("DD1 Hahax")
}

func (z DD1) Miao() {
	fmt.Println("DD1 Miao")
}

type DD2 struct {
	DD3
}

type DD3 struct{}

func (z DD3) Miao() {
	fmt.Println("DD3 Miao")
}

type ZZZ struct {
	DD1
	DD2
}

func (z ZZZ) Hahax() {
	fmt.Println("ZZZ Hahax")
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}

```

The following is the output for this piece of code:

```bash
ZZZ Hahax
DD1 Miao

```

Let's remove `DD3` from the latest iteration of the code and also have `DD2` also implement the `Miao` function. That would make it confusing - which `Miao` function should be used when since `DD1` and `DD2` embedded struct appear to be on the same level?

```golang
package main

import (
	"fmt"
)

type AAA interface {
	Hahax()
}

type BBB interface {
	Miao()
}

type CCC interface {
	AAA
	BBB
}

type DD1 struct{}

func (z DD1) Hahax() {
	fmt.Println("DD1 Hahax")
}

func (z DD1) Miao() {
	fmt.Println("DD1 Miao")
}

type DD2 struct {}

func (z DD2) Miao() {
	fmt.Println("DD2 Miao")
}

type ZZZ struct {
	DD1
	DD2
}

func (z ZZZ) Hahax() {
	fmt.Println("ZZZ Hahax")
}

func Printer(c CCC) {
	c.Hahax()
	c.Miao()
}

func main() {
	z := ZZZ{}
	Printer(z)
}

```

We now have the following:

```bash
./prog.go:52:9: ZZZ.Miao is ambiguous
./prog.go:52:9: cannot use z (type ZZZ) as type CCC in argument to Printer:
	ZZZ does not implement CCC (missing Miao method)

```

Even the golang runtime becomes unsure of which one to run and it panics.

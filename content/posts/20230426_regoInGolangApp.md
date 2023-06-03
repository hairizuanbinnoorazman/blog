+++
title = "Writing Rego Policies for authorization in Golang Apps"
description = "Writing Rego Polices for authorization in Golang Apps"
tags = [
    "golang",
]
date = "2023-04-26"
categories = [
    "golang",
]
+++

When building login systems in applications, there are generally two parts to it; authentication and authorization. Authentication is the step to provide and identify who the user that is attempting to use the system. Authorization is the step to decide whether user that is using the system is "allowed" to access or modify a particular resource on a system.

An example of this in the retail sense is where a a cashier is able to utilize machines that is able to create new sales transaction records on the sales database. However, said machines shouldn't have access nor the capability to run a query which will extract past transactions and do analysis and summaries on it. That's a system where the "cashier" user is able to autheticated as a "cashier" on the system and is only authorized to add transactional records but has not authorization to access other forms of data or even modify proces of goods etc.

When it comes to building such authorization systems in Golang applications, we can somewhat build it by coding it out. In the case where we need to set authorization controls on API endpoints, we can code out sections of code that would check if a particular user is allowed to access a particular API endpoint; e.g. admin user for an API system is able to delete off users of the system? However, naive implementations of this would generally couple/embed such authorization tightly with the code. At the same time, it is hard to go through the entire codebase to identify what kind of users would have access to which particular endpoint.

I'm supposing this is part of the reason why things like a whole domain language is created for this. In the open policy agent project, there is a language called `rego` that is a domain specific language that is designed specifically for providing authorization policies for users.

Let's have a sample authorization for our application with the following weird requirements:

- API endpoint is `/salary/<user id>`
- HTTP methods when accessing this endpoint is a "GET"
- API endpoint is only allowed for users who are still "subscribed" - this is denoted by some sort of "expiry_year" field that denotes the ending year for their subscription.

Naturally, at the same, admin should also have access to this resource without any issue.

The authorization policy for this would probably look something like this if written using `rego`. Reference with regards to the `rego` language: https://www.openpolicyagent.org/docs/latest/policy-language/

```rego
package example.authz

import future.keywords.if
import future.keywords.in

default allow := false

allow if {
    input.method == "GET"
    input.path == ["salary", input.subject.user]
    input.expiry_year >= 2020
}

is_admin if input.subject.user == "admin"

allow if is_admin

```

Here is some sample golang code that utilizes the above policy:

```golang
package main

import (
	"context"
	"fmt"

	"github.com/open-policy-agent/opa/rego"
)

func main() {
	ctx := context.TODO()

	query, err := rego.New(
		rego.Query("aa = data.example.authz.allow"),
		rego.Load([]string{"./example.rego"}, nil),
		// rego.Module("example.rego", module),
	).PrepareForEval(ctx)

	if err != nil {
		panic("damn")
	}

    input := map[string]interface{}{
		"method": "GET",
		"path":   []interface{}{"salary", "bob"},
		"subject": map[string]interface{}{
			"user":   "bob",
			"groups": []interface{}{"sales", "marketing"},
		},
		"expiry_year": 2050,
	}

	results, err := query.Eval(ctx, rego.EvalInput(input))
	fmt.Printf("%+v\n", results)
}
```

The output for the above code would like the following:

```bash
[{Expressions:[true] Bindings:map[aa:true]}]
```

If we changed the `expiry_year` to `2000`, we should see the aa value within the bindings map to be false.

Do note of how we set up the `input` variable in Golang code. Initially, I thought that data to be tested and evaluated for can only be written using Golang maps that uses `interface{}`. However, it's possible to use structs as well (in general, this would be preference - map with string as keys and interface as values is not the most pleasant to work with). Important thing to work with structs is that we need to define json struct tags (else, it won't as expected)

```golang
package main

import (
	"context"
	"fmt"

	"github.com/open-policy-agent/opa/rego"
)

func main() {
	ctx := context.TODO()

	query, err := rego.New(
		rego.Query("aa = data.example.authz.allow"),
		rego.Load([]string{"./example.rego"}, nil),
		// rego.Module("example.rego", module),
	).PrepareForEval(ctx)

	if err != nil {
		panic("damn")
	}

	input := map[string]interface{}{
		"method": "GET",
		"path":   []interface{}{"salary", "bob"},
		"subject": map[string]interface{}{
			"user":   "bob",
			"groups": []interface{}{"sales", "marketing"},
		},
		"expiry_year": 2050,
	}

	type hehe struct {
		User   string   `json:"user"`
		Groups []string `json:"groups"`
	}

	type hoho struct {
		Subject hehe `json:"subject"`
	}

	zz := hoho{
		Subject: hehe{
			User:   "admin",
			Groups: []string{"testing"},
		},
	}

	results, err := query.Eval(ctx, rego.EvalInput(input))
	fmt.Printf("%+v\n", results)

	results, err = query.Eval(ctx, rego.EvalInput(zz))
	fmt.Printf("%+v\n", results)
}

```

Probably in some next blog post, I will cover a more indepth example by embeding rego in some Golang HTTP server.
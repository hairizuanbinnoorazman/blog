+++
title = "Using Go in AWS Lambda"
description = "Go in AWS Lambda before AWS official support"
tags = [
    "go",
    "serverless",
]
date = "2018-01-15"
categories = [
    "go",
    "serverless",
]
+++

_Disclaimer: There are definitely better ways of doing this; this is more of a lazy man's way of doing it. This is just to explore the possibility of getting a golang application into AWS Lambda and successfully running it._

Although Golang support is coming to AWS Lambda, (I'm totally excited for this - hopefully it will come out this year!) we can still try a few things on our own end to somehow get lambda to run our Go Applications. One common way would be to just write Golang applications as usual but instead of just running the command:

```bash
go build main.go
```

We would instead use a nice feature that Golang have; cross compilation and build it for the AWS Lambda runtime.

```bash
env GOOS=linux GOARCH=amd64 go build main.go
```

There would generate an executable that can run on the machine that built it but it should on linux machines just fine.

In python, we would just wrap that executable and call it accordingly. To put it simply; since AWS didn't really support Golang runtime then, we could create the binary that was compatible with the AWS OS that is used to host AWS Lambda and then have the python code in the available python runtime run it. Essentially, any language that produces a binary that can be executed on a machine can be put here as long as the right values are being put in.

```python
from __future__ import print_function

import json
import subprocess

def lambda_handler(event, context):
  value = subprocess.check_output("./main", shell=True)
  print(value)

  response = {
    "statusCode": 200,
    "headers": {
      "Content-Type": "*/*"
    }
  }
  return response
```

We would try to run this very simple go code example (The helloworld example)

```go
package main

import "fmt"

function main() {
  fmt.Println("Hello World")
}
```

The deploy.sh file below:

```bash
# Create the distribution folder
rm -rf dist
rm -f dist.zip
mkdir dist

# Build the go application
env GOOS=linux GOARCH=amd64 go build main.go

# Copy lambda files in
cp lambda_function.py ./dist/lambda_function.py
cp main ./dist/main

# Generate the distribution zip
cd dist
zip -r dist.zip .
cd ..
cp dist/dist.zip dist.zip
```

To view the full code for this example:
https://github.com/hairizuanbinnoorazman/demonstration/tree/master/trying_aws_lambda/raw/go_example

I can only think of very few reasons to want to do this; due to the nature of AWS Lambda where code might take a while to start running (e.g. cold start problem), there is no point having extremely efficient code. Unless you are doing extremely heavy compute stuff and python or any other language supported by AWS Lambda that can help resolve the issue, would this go kind of help a little. Other than that, it might be better to just play along with what AWS Lambda provides us.

If you would prefer an explanation and an example of this, you might want to watch this clip.  
{{< youtube lcyNjgEG9H8 >}}

However, with the upcoming support provided by AWS, it is probably uncessary to do all these weird hackaround. We can upload the Go Code straight into AWS Lambda and then have it execute accordingly.

Even with all that simplicity, it would ideal to actually rely on serverless framework to actually help do the administrative portions of the serverless functions. There are many things to consider when writing serverless functions, one of which is to set up the required security roles. If the functions are dependent on queues etc, it would requiring work to administrate all that additional functionality.

Naturally, as programmers, we would have all those work automated away, which could mean writing ansible scripts or even cloud formation scripts (specific AWS). However, one can just rely on the serverless framework to do all that heavy work.

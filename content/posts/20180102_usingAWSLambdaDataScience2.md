+++
title = "Using AWS Lambda for Data Science Projects and Automations 2"
description = "AWS Lambda for Data Science Projects which involves the usage of python and it numerical libraries"
tags = [
    "python",
    "serverless",
]
date = "2018-01-02"
categories = [
    "python",
    "serverless",
]
+++

Following from the previous blog post:
Using AWS Lambda for Data Science Projects and Automations - Part 1

Let's deploy a serverless application!

Problem Statement:  
The application we would be trying out this time will do the following:

> "Read csv files when it is loaded into S3, load via the pandas package, sum the numeric sum and then send the result of that analysis into Slack."

It sounds like quite a mouthful and sounds simple but with all the gotchas surrounding the AWS Lambda platform, we need to tread out steps carefully and try each step before proceeding onward.

Let's break the problem into smaller bits which we can then try out.

- Load up the Requests package
- Load up the Pandas package
- Read event value when AWS S3 is triggered
- Prepare the Slack URL to receive the result of the 'analysis' which is the summing of values of a column

## Load up the Requests Package

**Gotcha: You cannot just install python packages on a AWS Lambda function. You will need to load up the installed libraries together with your codebase**

**Gotcha: If you use the API Gateway, ensure that output is right. In the case here, you would need a dictionary with the Content-Type and StatusCode.**

For the latest codebase to handle this:
https://github.com/hairizuanbinnoorazman/demonstration/tree/master/trying_aws_lambda/raw/requests_example

A copy of the code to this is available here as well, in case the above link becomes unavailable:

This is the minimum codebase to get something started in AWS Lambda.

deploy.sh

```bash
# Create the virtual environment

rm -rf temp
virtualenv temp
source temp/bin/activate
pip install -r requirements.txt

# Create the distribution folder

rm -rf dist
mkdir dist

# Copy lambda files in

cp lambda_function.py ./dist/lambda_function.py
cp -r ./temp/lib/python2.7/site-packages/\* ./dist/

# Generate the distribution zip

cd dist
zip -r dist.zip .
cd ..
cp dist/dist.zip dist.zip

# Deactivate virtual environment

deactivate
```

requirements.txt

```txt
requests
```

lambda_function.py

```python
from **future** import print_function

import json
import requests

def lambda_handler(event, context):
    response = requests.get("https://www.google.com")
    print("Print the status code of this")
    print(response.status_code)

    response = {
        "statusCode": 200,
        "headers": {
        "Content-Type": "_/_"
        }
    }
    return response
```

## Load up the Pandas Package

**Gotcha: The approach above to load the requests package cannot be used to load the pandas package. We need to build the c-bindings behind the pandas library which mean that we kind of need to know the machine that is used to run lambda.**

After running the deploy.sh script in the container, we would need to kind of run a 'hackish' command.

For the latest codebase for this:
https://github.com/hairizuanbinnoorazman/demonstration/tree/master/trying_aws_lambda/raw/pandas_example

FYI: You will need to install docker to run this example.

To run and generate the dist.zip file that we need for the lambda function, we would need the docker_commands.sh shell script first. After which, we should land inside the shell of the docker container.

When we are inside the docker shell, we would just need to run deploy.sh. This would generate the dist.zip but we would still need to export it out of the container. We have a command for it though, so just follow along.

\*\*deploy.sh is similar to the requests example above

requirements.txt

```txt
requests
pandas
```

lambda_function.py

```python
from **future** import print_function

import json
import requests
import pandas as pd

def lambda_handler(event, context):
    # Testing out pandas
    names = ['Bob','Jessica','Mary','John','Mel']
    births = [968, 155, 77, 578, 973]
    BabyDataSet = list(zip(names,births))
    print(BabyDataSet)
    df = pd.DataFrame(data = BabyDataSet, columns=['Names', 'Births'])
    print("Printing out the dataframe")
    print(df)

    response = {
        "statusCode": 200,
        "headers": {
        "Content-Type": "_/_"
        }
    }
return response
```

Dockerfile

```Dockerfile
FROM amazonlinux
RUN yum install -y python27-pip zip
RUN pip install virtualenv
ADD . .
```

docker_commands.sh

```bash
docker build -t lambdafunction .
docker run -it --name awslambda lambdafunction /bin/bash
# docker cp awslambda:/dist.zip .
```

Additional commands not in any of the files:

docker cp awslambda:/dist.zip .
This would copy the dist.zip file out from the container which we can then use to upload for our lambda function.

You will notice that the dist.zip is quite huge as compared to the previous requests example. We would need to do the alternative method which is upload the script into S3. After which, we can then proceed to feed it into AWS S3.

If we keep pretty much everything the same from the previous example, we can just switch out the script and it should still work as expected. (The whole of this is to test out how to get pandas into AWS Lambda after all)

## Read event value when AWS S3 is triggered

**Gotcha: Ensure that the name of the csv file does not contain spaces or other special characters. The event values somehow alter the names of such files which results in issues when the AWS Lambda function is triggered.**

**Gotcha: Don't mess up when creating the S3 trigger.**

**Gotcha: A major issue is setting the permissions right. If you don't set the permissions right, the function will keep complaining that it doesn't have the permissions needed to access the resources it needs to run e.g. S3 or Cloud Logs. One of the worst things that happened while I was experimenting this was that I accidentally disable cloud logging as well as S3 access for a lambda function. The lambda function is rendered useless and there isn't even logs to even indicate that!! So yea, try not to fiddle with permissions to much, but rather get familiar with it and get it right.**

We would changing and prepping up the example such that it would be closer to what we would expect of this. We would have a S3 trigger to ping us the csv files which would then read and run our 'analysis'.

You can get the latest of the code here:
https://github.com/hairizuanbinnoorazman/demonstration/tree/master/trying_aws_lambda/raw/s3_example

The data to test that functionality can be found here:
https://github.com/hairizuanbinnoorazman/demonstration/tree/master/trying_aws_lambda/raw/s3_example_data

Most of the files are roughly the same except for this file:
You can copy most of them from previous sections.

lambda_function.py

```python
from **future** import print_function

import json
import requests
import pandas as pd
import os

# Comes with AWS Lambda

import boto3

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Testing out triggers with AWS S3
    for record in event['Records']:
    key = record['s3']['object']['key']
    bucket = record['s3']['bucket']['name']
    print(key)
    print(bucket)

    download_path = "/tmp/temp.csv"

    s3_client.download_file(bucket, key, download_path)
    print(os.path.isfile("/tmp/lol.csv"))
    print(os.path.isfile(download_path))

    df2 = pd.read_csv("/tmp/temp.csv")
    print(df2)

    print(sum(df2['col1']))

    return "success"
```

On the AWS Lambda creation page, instead of using the API Endpoints trigger, we should just use the S3 triggers. We would need to configure the S3 triggers to activate on any Object Created with a suffix of csv. This would allow the bucket to trigger every time a csv file is added to the bucket.

As mentioned above, there are some sort of issues when doing this, so rather than using an existing bucket, use a fresh new s3 bucket storage for testing this.

## Prepare the Slack URL to receive the result of the 'analysis' which is the summing of values of a column

There is nothing different about this. We would just append a Slack Webhook at the end:

```python
# Append the following code at the bottom

url = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
payload = {"text": "Total for col2 is %s" % (value)}

r = requests.post(url, json=payload)
```

## Summary

If you take a look at all the steps above, it would seems like as though its quite troublesome to have to handle all that just to get a serverless functions up and running. If it was this troublesome just to get one up and running and is it really worth all that effort?

This is where tools and framework really help a lot. One of the tools/framework that we can think of using is the Serverless framework https://serverless.com/.

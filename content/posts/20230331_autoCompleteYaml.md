+++
title = "Yaml linting and auto completion in Visual Studio Code"
description = "Yaml linting and auto completion in Visual Studio Code"
tags = [
    "automation",
]
date = "2023-03-31"
categories = [
    "automation",
]
+++

When dealing with applications - in terms of configuration work or even deploying the application to production, there is high possibility that we would need to deal with plenty of yaml. Yaml is a somewhat popular markup language (as of now) to do configuration work - other types of markup language/tools that are available and also used are ini files, toml files and json files but we won't be focusing on those for this post.

When writing yaml, it could be a pain to ensure that the yaml is a proper structure. We could try to ensure that it's "proper" by writing a quick script to parse and then ensure that the structure is right but that would involve us needed to run the script constantly to ensure that yaml is correct as we edit it (to avoid huge errors that would require to edit huge swaths of yaml code). Fortunately for us, the tech industry came up with a common-ish solution to try to solve this and modern IDEs have taken up the solution that would help developers to do linting as well auto completion of yaml.

In order to have the capability to do linting/auto completion for yaml in visual studio code - we would first need a plugin that is able to do so - https://marketplace.visualstudio.com/items?itemName=redhat.vscode-yaml. You can access it simply by finding plugins that support yaml files in the plugin search tool within Visual Studio Code.

Once we have that in place, we can then begin to craft out the file that would provide rules that would be used to ensure our yaml is in the right structure.

Let's say the yaml file that we intend to do linting on is called `zzz.yaml`. We can ensure that linting is turned on by adding the following file in the `.vscode` folder. This config file serves as settings to tell how visual studio should behave when viewing the code within the tool. In our case, we want to inform Visual Studio code to refer to the following file to do linting on `zzz.yaml`.

Our schema file as `address.schema.json`.

```json
{
    "$id": "https://example.com/example.schema.json",
    "$schema": "http://json-schema.org/draft-07/schema#",
    "title": "Example",
    "description": "An example of how to use snippets for json schema",
    "type": "object",
    "properties": {
      "example-snippet": {
        "defaultSnippets": [
          {
            "label": "foo",
            "body": {"test": "test", "test2": "test2", "test3": {"test3": "acac"}}
          }
        ]
      },
      "object-mapper": {
        "type": "object",
        "patternProperties": {
          "[A-Za-z0-9]": {
            "required": ["test1", "test2"],
            "defaultSnippets": [
              {
                "label": "deploy",
                "body": {"test1": "acac", "test2": "acac"}
              }
            ],
            "properties": {
              "test1": {"type": "string"},
              "test2": {"type": "string"}
            }
          }
        }
      },
      "item-mapper": {
        "minItems": 1,
        "maxItems": 5,
        "type": "array",
        "defaultSnippets": [
          {
            "label": "aaa",
            "body": {"test1": "acac", "test2": "acac"}
          }
        ],
        "items": {
          "required": ["test1", "test2"],
          "properties": {
            "test1": {"type": "string"},
            "test2": {"type": "string"}
          }
        }
      }, 
      "address": {
        "title": "Street Address",
        "description": "Street of your address",
        "type": "string"
      }
    }
  }
```

For our Visual Studio Code settings in `.vscode/settings.json` within the workspace

```json
{
    "yaml.schemas": {
        "address.schema.json": [
            "zzz.yaml"
        ]
    }
}
```

Once we have in this place, we now are able to do a little magic within `zzz.yaml`.

Let's say we want to add a field for `example-snippet`. Maybe it have a bunch of labels and values that we would need to create and it might be a tad troublesome to keep doing it in a sense. However, with the json schema configuration in place, we would see the following:

![example-snippet-before](/20230331_autoCompleteYaml/example-snippet-before.png)

Visual Studio Code would prompt that there is a possibility to auto complete that chunk for the `example-snippet` property. If we would simply press tab, it would immediately fill out the information (as based of the "body" field). It would pop in the values like so:

![example-snippet-after](/20230331_autoCompleteYaml/example-snippet-after.png)

This behaviour is based on just the following portion from the json schema 

```json
    "example-snippet": {
        "defaultSnippets": [
            {
            "label": "foo",
            "body": {"test": "test", "test2": "test2", "test3": {"test3": "acac"}}
            }
        ]
        }
```

We can do even more complex scenarios here. Another example would be to ensure that certain fields exists within our yaml object. Refer to the following section of our json schema.

```json
    "object-mapper": {
        "type": "object",
        "patternProperties": {
          "[A-Za-z0-9]": {
            "required": ["test1", "test2"],
            "defaultSnippets": [
              {
                "label": "deploy",
                "body": {"test1": "acac", "test2": "acac"}
              }
            ],
            "properties": {
              "test1": {"type": "string"},
              "test2": {"type": "string"}
            }
          }
        }
      }
```

In this case, if we have the `object-mapper` field in our yaml, each object within it should have the field `test1` and `test2`. If it doesn't, Visual Studio Code will somewhat complain about the lack of those fields. Let's say if we set our yaml file that uses the json schema as follows:

```yaml
example-snippet:
  test: test
  test2: test2
  test3:
    test3: acac
object-mapper:
  aa:
    test1: acac
    test2: acac
  bb:
    test3: acac
```

The `bb` field under `object-mapper` is unexpected since we expect each object in `object-mapper` to have fields `test1` and `test2`. The error would probably look like the following:

![missing-fields](/20230331_autoCompleteYaml/missing-fields.png)

We will cover more complex scenarios in another blog post. More examples about json schema is available from the following website: https://www.schemastore.org/json/. It seems kind of interesting to see the various complex scenarios that can be covered - it does look like it's possible to write up json schema files where we have certain fields that become required if other fields within the yaml exist.
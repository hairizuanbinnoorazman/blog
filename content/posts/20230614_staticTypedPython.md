+++
title = "Writing static python with mypy"
description = "Writing static python with mypy"
tags = [
    "python",
]
date = "2023-06-14"
categories = [
    "python",
]
+++

Python is a dynamically typed language - which provides a huge developer experience as compared to a statically typed language such as Golang. Python does serve as a nice introductory programming language for new developers but as time goes by, it's pretty easy to see why static programming language is why nicer to work with as compared to dynamically typed language. Due to the nature of such languages, it is easy to be "loosey" about the types of the variables which inadvertably makes the code harder to follow as codebases grow larger and larger. With such large codebases - even type hints on IDE becomes harder to establish (either takes too long or the tooling just deems it impossible to do so)

NOTE: This article is just a single developer's opinion. Feel free to disagree with it since each person's experience with programming languages are wildly different.

Nicely enough, we can control the chaos by slowly introducing some sort of typing into such Python programs. That'll make it easier to understand what type of variable to pass into functions. This is done by using a tool called `mypy`. Refer to the following website: https://mypy.readthedocs.io/. We can install it globally or in each virtual environment set up by each Python project.

Typing introduced in Python is done via type annotations. Here is one example of how we can set a function accept a string variable. The function accepts 1 singular parameter with string type. It will return no output, which is defined by the None type annotation (defined with arrows to none. `-> None`)

```python
def function1(name: str) -> None:
    print("printing {}".format(name))
```

The following function is called as follows:

```python
function1("aac") 
```

Do take note that even if we have all these type annotations in place, we can still run such python code even if it's not conforming to the types - e.g.

```python
function1(123)
```

We can benefit from all these static typing by installing the `mypy` plugin if we use the Visual Studio Code. Reference: https://marketplace.visualstudio.com/items?itemName=matangover.mypy

We can setup the configuration file (`mypy.ini`) as follows:

```ini
[mypy]
disallow_any_unimported = True
disallow_untyped_calls = True
disallow_untyped_defs = True
warn_return_any = True
warn_unreachable = True
```

Once we have it all setup properly, there will be the red squiggly line when the types are no inline based on the types defined by the function.

Let's go with further examples. Let's say we have a function that we want to have a function that accepts an integer but it returns an integer instead of returning nothing.

```python
def function2(lol: int) -> int:
    return lol + 5

function2(12)
```

Let's change things up and instead, we have functions that accept an object instead of basic types such as integer or string etc. `function4` would simply accept `Hoho` object and it does not return anything from the function. `function4a` would accept a simple integer variable but returns a instantiated `Hoho` object.

```python
class Hoho():
    hoho: str
    santa: float

    def __init__(self, santaInit: int) -> None:
        self.hoho = "acaca"
        self.santa = santaInit

    def print_santa(self) -> None:
        print("value of santa {}".format(self.santa))

def function4(za: Hoho) -> None:
    za.print_santa()

def function4a(pp: int) -> Hoho:
    return Hoho(pp)

h = Hoho(123)
function4(h)
a4 = function4a(79)
function4(a4)
```

Alternatively, we can change it up such that we have a function that accepts a list of integers for our function. Here is how we define the type annotation for a list of integer that would be passed as parameter for a function.

```python
def function5(zolo: list[str]) -> int:
    ya = 0
    for x in zolo:
        ya += 1
        print("item: {}".format(x))
    return ya

function5(["acac", "qwec", "kqlmc"])
```

So, we have covered basic types such as strings, integers, etc, user defined objects and list of objects. In the python language, it is possible for a function to accept another that it would be processed further.

```python
from typing import Callable

def function6(qa: str, zzz: Callable[[str, str],bool]) -> None:
    p = zzz("acac", qa)
    if p:
        print("function6 and true") 
    else:
        print("function6 and false")


def function7(ya: str, zzz: str) -> bool:
    print(ya)
    print(zzz)
    if ya == "ya":
        return True
    else:
        return False
```

Let's say we would want to use an external library such as `pandas`. Apparently, when we use such external libraries, apparently the types doesn't come in built together with the actual package. However, if that's the case, then we would not be able to use external libraries easily and ensure that types from such external libraries would flow easily into the python scripts that we write. 

The solution as of now is to install stub libraries - in the case, for pandas, apparently, there is a `pandas-stubs` library. With `pandas-stubs` library, we can use types such as the `DataFrame` type  - which is technically a type that would be provided by pandas and would be an object that some of the function that returns the `DataFrame` object.

```python
import pandas as pd 

df = pd.read_csv("lol.csv")

def function1(data: pd.DataFrame) -> int:
    return len(data)

val = function1(df) 
print(val)
```

Unfortunately, the above set of code snippets are simply small easy code snippets that can demonstrate the possibility of introducing typing for Python scripts. In order to properly test this out, we would need to introducing typing to actual large python codebase - that would give us a bit of "battle testing" to show how it can be useful for developers - since a large point of introducing typing into python programs is to make the developer experiences way smoother.
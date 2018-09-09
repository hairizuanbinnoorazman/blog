+++
title = "Using Decorator Pattern to Remove Code Bloat"
description = "Removing excessive statements not meant for business logic. Put them aside into decorators"
tags = [
    "python",
]
date = "2017-10-26"
categories = [
    "python",
]
+++

I've been learning plenty of Golang nowadays and one of the most common design patterns that I keep hearing about is the decorator pattern. It is often used when handling with web requests; where you would create a function that accepts a struct that implements the handler interface which would then return an struct that also implements the handler interface.

I didn't really think too much about it until I watch the following video on Go-kit:

{{< youtube NX0sHF8ZZgw >}}

Essentially, this patterns allows one to reduce code bloat in a domain function which is usually caused by all the additional software activities; most of which may not be essential for the business logic, but is essential in terms of ensuring the running and correctness of the software/script.

The analogy mention during the video where he describes the software being like an onion where the decorator functions just keep adding on functionality to the function that implements the business logic. It makes the whole software extremely flexible and opens up a lot of new doors.

But enough of theory; let's do something practical!

Let's say you have this function in a python script.

```python
def very_important_function(param1, param2):
    print("The first param is: %s" % param1)
    print("The second param is: %s" % param2)
    result = param1 + param2
    return(result)
```

And you managed to get it out of the door into your production system and you're proud of it.

However, your manager comes along and say:

"Hey! We need logging for this! We need to know what's going on in the function!!"

With that, you adjust the code accordingly:

```python
import logging

def very_important_function(param1, param2):
    logging.info("Parameter 1 is %s" % param1)
    logging.info("Parameter 2 is %s" % param2)
    print("The first param is: %s" % param1)
    print("The second param is: %s" % param2)
    result = param1 + param2
    logging.info("very important function complete")
    return(result)
```

However, now, another developer comes along and says:

"Hey!! We need to get timings for your function! Without it, it would difficult to get optimize our script - we wouldn't know where to start!"

Once again, you will go along and adjust the code accordingly:

```python
import logging

def very_important_function(param1, param2): # Get the start time
    start_time = time.time()

    # Logging to check on what parameters is being pushed in
    logging.info("Parameter 1 is %s" % param1)
    logging.info("Parameter 2 is %s" % param2)

    print("The first param is: %s" % param1)
    print("The second param is: %s" % param2)
    result = param1 + param2

    # Logging to indicate the function has completed running
    logging.info("very important function complete")

    # Get the end time
    end_time = time.time()

    # Logging the timing information out
    logging.info("start time: %s" % start_time)
    logging.info("end time: %s" % end_time)
    logging.info("function duration: %s" % (end_time-start_time))

    return(result)
```

Hmm... The code base is starting to become quite ugly. The amount of code bloat is a bit too much -> In this case, the amount of auxilliary code is larger than the business logic/domain logic code which is actually important to the business.

So seeing this, what can we do to reduce and improve our situation? This is where implementing the decorator pattern would help. (Each language would have its own way of implementing it, will be focusing on python for this)

Let's create the following decorators

This would be the timing logger decorator:

```python
import time
from functools import wraps

def timing_logger(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        end_time = time.time()
        func(*args, **kwargs)

        # Logging the timing information out
        logging.info("start time: %s" % start_time)
        logging.info("end time: %s" % end_time)
        logging.info("function duration: %s" % (end_time-start_time))
    return wrapper
```

The wraps function is necessary in order to expose the function defined in func to be exposed. Without wraps, it makes it slightly harder to use the functionality.

We still have the other logging function that needs to be handled in order to understand what kind of inputs is being fed into the very_important_function function.

```python
from functools import wraps

def input_logger(func):
    """
        Only accepts named arguments
    """
    @wraps(func)
    def wrapper(**kwargs):
        for key in kwargs:
        logging.info("Input %s contains %s" % (key, kwargs[key]))
        func(**kwargs)

    return wrapper
```

With the following decorators in mind, we can remove all the auxilliary software logic out of the main function (very_important_function)

```python
@timing_logger
@input_logger
def very_important_function(param1, param2):
    result = param1 + param2
    return(result)
```

However, if you were to run, it would produce the following output:

```bash
In[1]: value = very_important_function(param1=2, param2=2)
INFO:root:Input param2 contains 2
INFO:root:Input param1 contains 2
INFO:root:start time: 1509003378.33
INFO:root:end time: 1509003378.33
INFO:root:function duration: 1.19209289551e-06
```

Take note that we are using named parameters here. This would allow us to make use of the name of the parameter being passed into the function so that it can be logged out much more easily.

However, the variable value doesn't contain the expected output! What happened here?

If you were to look into each of the decorator, you realize, that the decorators are not returning the output of the func that is being passed in. If we are to alter the function definitions here...

```python
import time
from functools import wraps

def timing_logger(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start_time = time.time()
        end_time = time.time()
        value = func(*args, **kwargs)

        # Logging the timing information out
        logging.info("start time: %s" % start_time)
        logging.info("end time: %s" % end_time)
        logging.info("function duration: %s" % (end_time-start_time))
        return value
    return wrapper
```

```python
from functools import wraps

def input_logger(func):
    """
    Only accepts named arguments
    """
    @wraps(func)
    def wrapper(**kwargs):
        for key in kwargs:
        logging.info("Input %s contains %s" % (key, kwargs[key]))
        value = func(**kwargs)
        return value

    return wrapper
```

With the modified functions above, that would return the values from our important function and with that, we kind of got solved our issue of running our domain function without any of clutter from auxiliary software requirements. :D

Maybe in the future, I might do any post about how we might go crazy with the decorators (e.g. Pinging Slack, Pinging Google Analytics, Logging, Authentication etc - That might be something fun to build)

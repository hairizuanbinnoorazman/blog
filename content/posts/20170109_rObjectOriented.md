+++
title = "R is an object oriented language?"
description = "Utilizing Object Oriented features in R for R packages"
tags = [
    "r",
]
date = "2017-01-09"
categories = [
    "r",
]
+++

Although it is often mentioned in many of the online tutorials and wikis that R is a Object Oriented language, the code examples on the web definitely don't show too many hints of that. Many of the code tutorials and code examples do not showcase such language features but instead mainly using functions to get things done.

This is partly because the main target audience of R users, tend to be the technologically savvy analyst who just need a quick tool to power through their data manipulation and data analysis work. They don't specifically want to handle with all the computer science theories such as classes and objects etc.

Most tasks can actually be done with just functions and loops but after a while you would realize that your code would actually be much better if relevant functions/settings are actually bunched into a single entity or in this case, object.

But let's say if you are curious of this language feature, where can you find examples of how it is applied?

There are actually already hints in some of the common packages. If you used packages such as RGA or bigrquery, the package generates a token object which it uses for authorization with Google Services. The two packages are powered by the httr package.

Look at the source code under the `oauth-token.R file`, you would see the following snippet of code. This code declares the token file that does the heavy lifting for you. For the average user, you wouldn't feel the complexity. You would just see and feel the magic of how easy it is to connect to the various internet services out there.

https://github.com/r-lib/httr/blob/master/R/oauth-token.r

So from this code, we can try to research further on the object oriented feature by exploring the R6Class function from the R6 package. The links below are some of the

An awesome introduction to Object Oriented features in R
https://cran.r-project.org/web/packages/R6/vignettes/Introduction.html

Some things to take note:
https://cran.r-project.org/web/packages/R6/vignettes/Portable.html

But let's not stop there, let's have a working class here!

```R
library(R6)

# Declaring the account class
Account <- R6Class("Account",
    public = list(
    accountNumber = NULL,
    balance = NULL,
    initialize = function(accountNumber = NA, balance = NA) {
        self$accountNumber = accountNumber
        self$balance = balance
    },
    getAccountNumber = function() {
        return(self$accountNumber)
    },
    getBalance = function(){
        return(self$balance)
    },
    setBalance = function(balance){
        self$balance = balance
    },
    credit = function(amount){
        self$balance = self$balance - amount
    },
    debit = function(amount){
        self$balance = self$balance + amount
    },
    print = function(){
        return(paste("Account Number:", self$accountNumber,
        ", Balance:", self$balance))
        }
    )
)

# Instantiating a new Account class
account <- Account$new(1234, 12)

# Get the current balance of the account
# Answer: 12
account$getBalance()

# Get credit out of the account
account$credit(3)

# Get debit into the account
account$debit(4)

# Get the current balance of the account
# Answer: 13
account$getBalance()
```

By looking at the code, you can see how it feels "packaged". Anything that requires the manipulation of the account is handled via the account object. Functions that handle the manipulation as well as the current state is all stored within it.

Although this is a pretty simple example, you can actually easily built on this to create much complex but we'll explore that in another blog post.

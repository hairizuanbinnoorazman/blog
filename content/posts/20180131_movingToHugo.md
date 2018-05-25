+++
title = "Opinion piece - Moving to Hugo"
description = "Experiences from moving a blog from the Wordpress to Hugo"
tags = [
    "static-sites",
]
date = "2018-01-31"
categories = [
    "static-sites",
]
+++

After a long while being on some managed platform for writing blog posts, I decided to move out of that into one which would require myself to manage things on my own.

A few reasons kind of came up which motivated such a decision:

## Blog posts being Code Centric

Blog post being too code-centric and all those managed platforms somehow managed to irritate me when it comes to creating them.

I've tried a couple, e.g. Blogger (I'm guessing it's a Google product but somehow, I'm not feeling that polish there), Wordpress and Medium. Wordpress was nice but it gets pretty complicated when I wish to add more code centric material; it
always requires myself to actually go in and adjust it on my own.

Seeing this, it kind of makes sense to just use markdown for my blogging. I don't need any of those fancy features, styling and they may actually get in the way. As an example, here is an example excerpt of some code snippets that we can actually write here.

It's just markdown, so if you write documentation for code projects or update code snippets in Github issues, this is definitely down your alley...

A Golang snippet

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello World!")
}
```

## Curiosity on this static file ecosystem

There has been somewhat a quiet rise in the number of static website generator applications nowadays. Long time ago, Jekyll was a definite winner, its a solution that is always mentioned on Github whenever it came to the time to build a site to support the code you're writing on Github.

However, nowadays, there is a growing number of tools available. One for which is Hugo which is
the one being used to write this blog right here.

Here are some of the others that I'm kind of looking into and their links:

* Hugo  
  https://gohugo.io/
* Jekyll (For all time's sake I guess?)  
  https://jekyllrb.com/
* Gatsby JS (Was laughing at that name. Kind of reminded me of a hair product brand which has a bunch of funny ads)  
  https://www.gatsbyjs.org/

But you know, if none of them tickle your fancy, you can always refer to this list right here:  
https://www.staticgen.com/

After working with one or two CRM solutions so far, I've found it kind of troubling that all that data in the post is all being stored in some database. If it just happens that the database becomes corrupt, there is no way to retrieve back the data ever but then again, these corruption of data can happen to any system so maybe my logic don't really make sense here. However, I do say one thing is that I prefer that all the posts being file based - it makes it easier to identify and modify them.

## Flexibility to customize

So far, the platforms I've tried so far doesn't allow much customizations in terms of customizing look and feel of the site (not that I myself needed much customizations in terms of look and feel). However, I was a lot more concerned
regarding the capability to add metadata and custom analytics tracking to the site.

I needed the site to be used for experimentation and using platforms don't really allow that level of experimentation.

In Hugo, it is relatively easy to create a code snippet which can be embedded in the every section of the site - It becomes possible to switch between Google Analytics, Google Tag Manager or other analytics tags.

## Additional Remarks

Note to my future self;  
Look at this link for a guide on how to style the blog posts...  
https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet

Also, when attempting to use code snippets, you would need to specify the language being used.
Not specifying would leave the code block as a yellow blob (somehting similar to code snippets in golang documentation site)

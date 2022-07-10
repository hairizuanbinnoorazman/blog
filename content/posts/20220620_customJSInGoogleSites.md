+++
title = "Custom JS Snippets in Google Sites"
description = "Custom JS Snippets in Google Sites"
tags = [
    "elm",
    "google-sites",
]
date = "2022-06-20"
categories = [
    "elm",
    "google-sites",
]
+++

Google sites now allow one to embed Javascript snippets into a site; thereby providing some interesting new capabilities with websites built with Google sites. The post here is a simple example of getting the same functionality provided in the [BMI Calculator](/bmi-calculator) page.

We can copy the generated Javascript from the repository:  
https://github.com/hairizuanbinnoorazman/blog/blob/master/layouts/shortcodes/bmi_calculator.html
https://github.com/hairizuanbinnoorazman/blog/blob/master/static/toolsjs/bmicalculator.min.js

The following Javascript is generated via Elm code into Javascript code snippets. The first link above is the html code that would call the required Javascript functionality. The second link is the actual Javascript that would provided the functionality that was coded out in Elm.

Taking the above pieces of code snippets, we can come out with the following code snippet that could embedded into a Google site page:

```html
<div id="bmi-calculator"></div>
<link rel="stylesheet" href="https://www.hairizuan.com/css/bmi.css">
<script src="https://www.hairizuan.com/toolsjs/bmicalculator.min.js"></script>
<script>
    app = Elm.BMICalculator.init({ node: document.getElementById("bmi-calculator") });
</script>
```

You can embed by creating a Google Sites and then clicking to "embed" a new element on the page of the site 

![embed-custom-js-google-sites](/20220620_customJSInGoogleSites/sites-embed.png)

An interesting point here is that rather than embedding the Javascript code that encapsultates the functionality of the BMI calculator, we can just pull it in via the `<script>` tag and pointing to a potential source that holds the javascript code. (An example would be this website; this website would hold links that have that piece of code snippet)

This opens up a variety of interesting use cases while using Google sites - technically, a non-developer can just embed any form of functionality that requires interacting with a custom API here (making it pretty extensible). This might prove pretty useful for "internal" work blogs (as an example use case)

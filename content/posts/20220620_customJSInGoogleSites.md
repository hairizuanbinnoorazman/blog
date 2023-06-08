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

The following Javascript is generated via Elm code into Javascript code snippets. The first link above is the HTML code that would call the required Javascript functionality. Over here, we skipped out the CSS bit - I personally find beautifying forms a tad unnecessary but to each their own. The second link is the actual Javascript that would provided the functionality that was coded out in Elm.

Taking the above pieces of code snippets, we can come out with the following code snippet that could embedded into a Google site page:

```html
<div id="bmi-calculator"></div>
<link rel="stylesheet" href="https://www.hairizuan.com/css/bmi.css">
<script src="https://www.hairizuan.com/toolsjs/bmicalculator.min.js"></script>
<script>
    app = Elm.BMICalculator.init({ node: document.getElementById("bmi-calculator") });
</script>
```

You can embed the code snippet by doing the following:

First, we would need to create a Google Site. We would  and then clicking to “embed” a new element on the page of the site.

![click-embed-custom-js-google-sites](/20220620_customJSInGoogleSites/click-embed.png)

On the Insert panel use the Embed option Choose the Embed code tab. After which, we can then type or paste our custom HTML and JavaScrip into the code box.

![embedding-code-custom-js-google-sites](/20220620_customJSInGoogleSites/embedding-code.png)

Use the Next button to preview how your code will look

![preview-embedded-custom-js-google-sites](/20220620_customJSInGoogleSites/preview-embedded.png)

Use the Insert button to add the code to the page. If there isn't a preview of the expected html, that would mean that there might be an error in the javascript or html - you probably need to fix it. You can simply use the Edit code button (looks like a pencil) that overlays the middle of the preview and edit the code to correct the code so that it works fine.

![embed-custom-js-google-sites](/20220620_customJSInGoogleSites/sites-embed.png)

An interesting point here is that rather than embedding the Javascript code that encapsulates the functionality of the BMI calculator, we can just pull it in via the `<script>` tag and pointing to a potential source that holds the javascript code. (An example would be this website; this website would hold links that have that piece of code snippet)

Another interesting point is that the embedded code can be interweaved between other content as well. Above the calculator, we can have some paragraph that could explain the details of what the tools is doing, providing context to the reader of what the tool does and how to intepret the outcome of the tool.

Another thing to note is that the following HTML, JS & CSS we embedded here is one that does not require to reach out to other server functionality. It's simply does the calculation using full on javascript. In the future, I could write up a blog post that would showcase an example of how to create some html, js and css that would showcase the capability of some embedded code in Google Sites being able to interact with some external 3rd party API - but that's a story for another time.

This opens up a variety of interesting use cases while using Google sites - technically, a non-developer can just embed any form of functionality that requires interacting with a custom API here (making it pretty extensible). This might prove pretty useful for "internal" work blogs (as an example use case)

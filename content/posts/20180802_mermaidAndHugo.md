+++
title = "Rendering diagrams in Hugo"
description = "Converting text descriptions to diagram via the mermaid.js library on Hugo"
tags = [
    "hugo",
    "mermaid",
]
date = "2018-08-02"
categories = [
    "hugo",
    "mermaid",
]
+++

There is an interesting Javascript project that allows one to use just plain old text and convert those said text into diagrams.

{{<mermaid>}}
graph TD
Start --> Stop
{{</mermaid>}}

Text to that converts to the above diagram:

```bash
graph TD
    Start --> Stop
```

Mermaid Documentation Page  
https://mermaidjs.github.io/

Mermaid js source code  
https://github.com/knsv/mermaid

Let's say we would want to use this diagram conversion tool in conjuction with hugo; how should we do it? Do we somehow need to embed html partial snippets all over the place etc?

Luckily, Hugo has a mechanism to do this via shortcodes. Links to the website is below

Hugo Shortcodes:
https://gohugo.io/content-management/shortcodes/

Essentially, the shortcut somehow injects html into the rendered html page from the markdown file. Since its plain old html, we can inject all kinds of html templates, html templates with javascript. That's essentially how one would be able to embed the youtube video player into blog posts.

```markdown
{{ youtube XXXXXX }}
```

Pretend the XXXXXX is some sort of youtube id (It is the v parameter of the youtube url.)

Hugo supports several shortcodes, including instagram and twitter.

However, let's go back to using Mermaid with Hugo. Hugo does not support Mermaid.js out of the box, one cannot just use shortcode to inject snippets of mermaid js html all over the blog. However, there is a mechanism to build it (also available in the Hugo website). However, if one wants some reference on how to add such functionality, they can look at the following example.

Mermaidjs + Hugo example  
https://github.com/matcornic/hugo-theme-learn

This website relies on Hugo and Mermaidjs which would generate the pages with diagrams svgs on them as ncessary.

There are a few things we need to take note while building the shortcode to support it:

- Do not have the mermaid.js be imported to the site via a CDN. When running locally, the browser will block all external scripts from running locally.
- There are some breaking changes for mermaid.js - take note of them
- Hugo website kind of mentioned that one can put js and css files into the static folder. If one comes from the frontend development work, it becomes easy to assume that the js and css files would be compiled and imported as part of local. This is definitely not true in this case; there is a need to actually have a html snippet that actually does the importing of the required files to the frontend.
- Steps Involved:
  - Add css and js files required for mermaid.js library in the static folder.
  - Have the `mermaid.html` shortcode be put into the shortcode folder of layouts
  - Have a partial HTML snippet in partials to be able to import the html into the final rendered HTML output. The partial HTML snippet should be importing the css and js locally. There is a need to activate for mermaid.js scripts for the script to know when to activate and convert the text to diagram.

The result would appear as below which would allow you to render the graph above.

```html
{&lbrace;<mermaid>&rbrace;}
graph TD
    Start --> Stop
{&lbrace;</mermaid>&rbrace;}
```

Just a little fun experiment to see how far this Hugo framework can take me.

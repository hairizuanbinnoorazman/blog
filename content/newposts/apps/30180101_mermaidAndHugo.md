+++
title = "Rendering diagrams in Hugo"
description = ""
tags = [
    "hugo",
]
date = "3018-03-14"
categories = [
    "hugo",
]
+++

There is an interesting Javascript project that allows one to use just plain old text and convert those said text into diagrams.

{{<mermaid>}}
{{</mermaid>}}

Text to that converts to the above diagram:

```bash

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

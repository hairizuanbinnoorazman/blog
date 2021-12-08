# Blog

Blog posts on hugo

In order to simplify some of the hugo commands, we would use a makefile contains a couple of commands

```bash
make build
```

After running the above command, we can try running a local instance and to see how it looks like before deploying to a public domain.

```bash
make local
```

The online content of this is available on https://www.hairizuan.com

# Weird hacks

Just a sidenote; attempted to add elm elements to the following pages - however, it seems quite troublesome to configure the build environment to run elm commands - no clear documentation on netlify on usage of elm (I guess the language is pretty obscure so I guess this is to be expected).

So, currently taking the lazy way by just generating the `*.min.js` files are dumping it into the static folder

Regarding image optimization - the following blog post is a good guide:  
https://alexlakatos.com/web/2020/07/17/hugo-image-processing/

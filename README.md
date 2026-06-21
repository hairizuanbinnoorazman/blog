# Blog

Hugo blog published at https://www.hairizuan.com.

## Prerequisites

- Git with submodule support
- Hugo Extended 0.159.1 or a compatible newer version supported by the pinned Blowfish theme

Initialize the theme after cloning:

```bash
git submodule update --init --recursive
```

## Development

Build the site:

```bash
make build
```

Run a local server:

```bash
hugo server --buildFuture=false
```

Netlify uses the Hugo version pinned in `netlify.toml`.

## Custom components

The site includes locally maintained shortcodes for Elm tools, advertisements, legacy Mermaid diagrams, and Hugo asset-processed images. Generated Elm JavaScript remains checked into `static/toolsjs` because Elm is not part of the Netlify build.

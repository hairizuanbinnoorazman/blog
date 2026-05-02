+++
title = "Capturing OAuth Flows Inside an Electron App"
description = "Using the $BROWSER environment variable to intercept CLI-initiated browser opens and route OAuth flows into Electron web panels."
tags = [
    "electron",
    "oauth",
]
date = "2026-09-15"
categories = [
    "tooling",
]
+++

CLI tools like `gh auth login`, `gcloud auth login`, and `aws sso login` all share a pattern: they print a URL or open the system browser for OAuth authentication, wait for the callback, and then continue in the terminal. When running these commands inside Worklayer's terminal panels, the browser opens externally and the user has to leave the app to complete the flow.

I wanted OAuth flows to open as adjacent web panels instead, keeping the entire authentication flow inside the workspace.

### The $BROWSER Trick

Most Unix CLI tools respect the `$BROWSER` environment variable. When a tool needs to open a URL, it checks `$BROWSER` before falling back to `xdg-open` or `open`. If `$BROWSER` is set to an executable, that executable gets called with the URL as an argument.

Worklayer's main process runs a local HTTP server (originally for the MCP integration). I added a `/browser-open` endpoint to it. When a terminal panel spawns, its environment includes:

```
BROWSER=<path-to-a-script-that-POSTs-the-URL-to-localhost>
```

The script is minimal. It receives the URL as an argument, POSTs it to the local HTTP server with the auth token, and exits. The main process receives the URL, determines which terminal initiated the request, and sends an IPC message to the renderer to create a web panel adjacent to that terminal.

### Adjacent Panel Placement

When the browser open request arrives, the renderer needs to create the web panel in a logical position. The request includes the terminal's `termId`, which maps to a `panelId` in the workspace. The new web panel is inserted immediately after the originating terminal panel.

This placement is intuitive: you are working in a terminal, a browser window opens, and it appears right next to where you are working. You can watch the OAuth page load, complete authentication, and see the terminal receive the callback, all without scrolling or switching context.

If the terminal ID cannot be resolved (perhaps the terminal was closed between the request being sent and received), the web panel is appended at the end of the workspace as a fallback.

### What This Captures

The interception catches several common workflows:

- **GitHub CLI** (`gh auth login`) — opens GitHub's device authorization page
- **Google Cloud** (`gcloud auth login`) — opens Google's OAuth consent screen
- **AWS SSO** (`aws sso login`) — opens the SSO authorization page
- **Any tool using `xdg-open` or `open`** — they typically check `$BROWSER` first
- **`window.open()` equivalents** — Node.js tools that shell out to open a URL

The web panel shares the same browser session as all other web panels in the profile. If you are already logged into GitHub in another panel, the OAuth page will recognize that session. This often means the authentication completes with a single click rather than requiring full credentials.

### Handling the Callback

OAuth flows typically redirect to `localhost` with a callback. Since the web panel is a standard Chromium webview, it handles the redirect normally. The CLI tool's local server receives the callback and the terminal continues.

The only edge case is tools that open `localhost` URLs directly (not OAuth but local dev servers). These get intercepted too, which is actually desirable since seeing your local development server in a web panel next to the terminal running it is useful behavior.

### Implementation Details

The browser intercept script needs to be fast because some CLI tools wait for it to exit before continuing. The script does a single HTTP POST and exits immediately. It does not wait for the panel to be created or the page to load.

Environment variables are inherited by child processes, so tools spawned from within the terminal (like running a script that internally calls `gh auth login`) also benefit from the interception without any additional configuration.

The token-based authentication on the HTTP endpoint prevents other processes on the machine from creating panels. Each Worklayer session generates a random token that only its spawned terminals know.

+++
title = "Building a Custom MCP Server with Chrome DevTools Protocol"
description = "How I built an MCP server that lets Claude Code control Electron webviews via CDP, replacing the need for Playwright."
tags = [
    "mcp",
    "electron",
    "cdp",
]
date = "2026-06-15"
categories = [
    "tooling",
    "ai",
]
+++

When using Claude Code inside Worklayer's terminal panel, I wanted it to be able to interact with web pages displayed in adjacent web panels. The standard approach would be to use the Playwright MCP server, but that spawns a separate Chromium instance outside the app. The page Playwright controls and the page the user sees are two different browser sessions with no shared state.

I needed the AI to control the same webview the user is looking at. Same session, same cookies, same DOM. So I built a custom MCP server that talks to Electron's webviews via the Chrome DevTools Protocol.

### Architecture

The communication chain looks like this:

```
Claude Code (terminal panel)
    |  stdio JSON-RPC
    v
MCP Server (Node.js process)
    |  HTTP to localhost
    v
Worklayer Main Process
    |  webContents.debugger.sendCommand()
    v
Webview CDP (Chrome DevTools Protocol)
```

The MCP server runs as a standalone Node.js process spawned by Claude Code. It cannot use Electron's IPC directly because it is not part of the Electron app. Instead, it makes HTTP requests to a local server that Worklayer's main process already runs for browser interception.

### Why HTTP Instead of WebSocket or IPC

Worklayer already had a local HTTP server for intercepting browser opens from CLI tools (the `$BROWSER` env var trick). Adding CDP routes to this existing server meant zero new dependencies or ports. Token-based auth was already in place. The MCP server just needs two environment variables: `WORKLAYER_MCP_PORT` and `WORKLAYER_MCP_TOKEN`, which are automatically set in the terminal's environment when it spawns.

### Why webContents.debugger Over --remote-debugging-port

Electron can expose a browser-wide debugging port with `--remote-debugging-port`, which is what you would connect Playwright to. But this exposes all webviews and requires target discovery and filtering. I wanted page-level access to a specific webview.

Electron's `webContents.debugger` API provides exactly this. You call `wc.debugger.attach('1.3')` on a specific webContents and then send CDP commands directly to it. No target discovery, no filtering, no risk of accidentally attaching to the wrong page. The webContents ID is already known because webviews register themselves on `dom-ready`.

### Accessibility Tree Over DOM Selectors

Following the pattern established by the Playwright MCP server, I use `Accessibility.getFullAXTree` to get a structured tree of the page rather than relying on CSS or XPath selectors. Each node gets a sequential UID that maps to a `backendDOMNodeId` for resolving click coordinates.

This works well with LLMs because the accessibility tree maps to how they reason about page structure. A tree node like `[4] textbox "Search" value=""` is more meaningful to the model than a CSS selector like `input.search-bar[data-testid="search"]`. It is also more stable across page updates.

### Mutex for Tool Serialization

CDP commands can interfere if run concurrently. A navigation mid-snapshot would produce garbage. A simple promise-chain mutex ensures only one tool runs at a time:

```javascript
let mutexPromise = Promise.resolve();
function withMutex(fn) {
  const prev = mutexPromise;
  let resolve;
  mutexPromise = new Promise((r) => { resolve = r; });
  return prev.then(fn).finally(resolve);
}
```

Every tool handler wraps its logic in `withMutex`. This is simpler than a full queue system and sufficient for the sequential nature of LLM tool calls.

### Gotchas

A few things that were not obvious from the CDP documentation:

- `webContents.fromId()` can return null if the webview was destroyed between listing panels and executing a command. Always check.
- Navigation history uses entry `id`, not array index. `Page.navigateToHistoryEntry` takes `entryId` from the history entry object.
- `DOM.getBoxModel` returns quads as flat arrays `[x1,y1, x2,y2, x3,y3, x4,y4]`, not point objects. The center for clicking is the average of all four corners.
- `Input.insertText` does not fire keydown/keyup events. For form fields with JS event handlers, you may need individual `Input.dispatchKeyEvent` calls.
- CDP domains must be explicitly enabled before use. Call `Page.enable`, `DOM.enable`, `Accessibility.enable` after attaching the debugger.

### The Result

The MCP server exposes 17 tools: navigate, click, type, screenshot, snapshot, hover, fill, press key, select option, handle dialogs, upload files, resize viewport, network requests, console messages, evaluate JavaScript, and route/unroute for request mocking. Claude Code discovers it automatically via `.mcp.json` in the project root.

The key outcome is that what Claude does is exactly what the user sees. There is no second browser window, no session mismatch, no disconnect between the AI's actions and the visible state. The user watches the web panel update in real time as the AI interacts with it.

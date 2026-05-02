+++
title = "Three Approaches to Embedding Playwright in Electron"
description = "Comparing URL mirroring, full CDP control, and screenshot streaming for showing Playwright-controlled pages inside an Electron app."
tags = [
    "electron",
    "playwright",
    "architecture",
]
date = "2026-08-15"
categories = [
    "tooling",
]
+++

When Claude Code uses the Playwright MCP server, it opens a separate Chromium window. This window floats outside of Worklayer, disconnected from the workspace. I wanted Playwright-controlled pages to appear inside a web panel so the user can watch the AI work without Alt-Tabbing to a different window.

I evaluated three approaches with very different tradeoff profiles.

### Approach 1: URL Mirroring

The simplest idea: intercept Playwright's `browser_navigate` calls via a stdio proxy, extract the URL, and navigate a Worklayer web panel to that same URL.

The proxy sits between Claude Code and the real Playwright MCP server. It parses JSON-RPC messages on stdin/stdout, watches for navigation tool calls, and sends the URL to Worklayer's HTTP API. The web panel loads the URL independently.

The fundamental problem is dual sessions. Playwright runs in its own fresh Chromium profile. The Worklayer web panel runs in `persist:webpanels` with its own cookies and login state. If Playwright logs into a site, fills a form, or mutates the DOM, none of that is visible in the panel. The panel just loads the same URL in a completely separate context.

This makes the approach misleading for any authenticated or stateful page. It shows "where Playwright is navigating" but not "what Playwright is doing."

### Approach 2: Full CDP Control

Replace the Playwright MCP entirely with a custom MCP server that controls a Worklayer webview directly via CDP. The MCP server connects to the webview's Chrome DevTools Protocol target and issues commands against it. What the MCP does is what the panel shows.

This is the approach I ultimately built (described in my previous post about MCP + CDP). The architecture uses Electron's `webContents.debugger` API to get page-level CDP access to a specific webview without exposing a browser-wide debugging port.

The key advantage is session parity. The same cookies, the same login state, the same DOM. The user sees actions happen in real time. But it required building a complete MCP server from scratch with 17 tools that reimplement Playwright's functionality using raw CDP commands: navigate, click, type, screenshot, accessibility snapshots, form fills, file uploads, network interception.

The implementation effort was significant but the result is the most correct solution. There is no disconnect between what the AI controls and what the user sees.

### Approach 3: Screenshot Streaming

Playwright runs fully headless. After each MCP action, a screenshot is taken and displayed in a Worklayer panel as a static image. The panel acts as a viewport showing exactly what Playwright sees, updated after every action.

The proxy intercepts each tool call response, automatically issues `browser_screenshot`, and forwards the base64 image to a panel via HTTP. The panel renders an `<img>` tag that updates on each new screenshot.

This approach has pixel-perfect accuracy since the screenshot is Playwright's actual rendering. It works for any page regardless of authentication or state. The tradeoff is that the panel is entirely non-interactive. The user cannot click, scroll, or inspect elements in the panel. There is also a slight delay since screenshots are captured after actions complete rather than streaming in real time.

### Comparison

| Criteria | URL Mirroring | Full CDP Control | Screenshot Stream |
|---|---|---|---|
| Session parity | No | Yes | N/A (image) |
| Visual accuracy | Low | Perfect | Perfect |
| Interactivity | Full (wrong session) | Full (correct) | None |
| Implementation effort | Low | High | Medium |
| Reuses stock Playwright MCP | Yes | No | Yes |

### What I Chose

I went with Approach 2 (Full CDP Control) because session parity was non-negotiable for my use case. When Claude Code is testing a web application running locally, it needs to share the same login session and see the same state as the user. A disconnected session or a static image would undermine the point of having the AI work alongside you in the same workspace.

The higher implementation cost paid off in daily use. Watching the AI click through a page in real time, in the same panel you can also interact with manually, makes the collaboration feel seamless rather than opaque.

For teams that do not need session parity and just want visual feedback of what the AI is doing, Approach 3 (Screenshot Streaming) offers the best effort-to-value ratio. It requires no custom MCP server and provides accurate visual representation with moderate implementation effort.

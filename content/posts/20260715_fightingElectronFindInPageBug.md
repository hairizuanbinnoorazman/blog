+++
title = "Fighting Electron's findInPage Focus Bug"
description = "A debugging story of five failed approaches before finding the right solution to Electron's findInPage focus-stealing problem."
tags = [
    "electron",
    "debugging",
]
date = "2026-07-15"
categories = [
    "tooling",
]
+++

I wanted find-in-page search for web panels in Worklayer. Electron provides `webview.findInPage()` which highlights matches and handles navigation between them. Simple enough. Except after the first character is typed into the search input, all subsequent keystrokes disappear into the void.

The root cause: `findInPage()` steals focus from the search input to the webview at the Chromium level. This is a known issue (Electron #22880, filed in 2020, never truly fixed for webview tags). What followed was five failed attempts before finding a working solution.

### Attempt 1: Remove the Redundant scheduleSearch Call

The focus-reclaim function was calling `scheduleSearch()` which reset the debounce timer repeatedly, preventing searches from firing for new characters. Removing that call seemed logical.

Result: searches stopped triggering entirely. The `input` event listener never fires because `findInPage` has already stolen focus, so keystrokes go to the webview instead of the search input.

### Attempt 2: Aggressive Blur Handler

Changed the blur handler to always reclaim focus when the search bar is visible, not just during the `findActive` window.

Result: focus-fight loop. `findInPage` steals focus, blur handler reclaims it, `findInPage` steals again. The search gets stuck on the first character forever.

### Attempt 3: before-input-event on the Webview Tag

The webview's `before-input-event` should fire before the webview processes a keystroke, allowing `preventDefault()` to redirect keystrokes to the search input.

Result: does not work. `before-input-event` on the `<webview>` DOM element fires as an informational event only. Calling `preventDefault()` on it does not actually prevent the webview from processing the key. This is different from `webContents.on('before-input-event')` in the main process, which does support prevention.

### Attempt 4: Injected Keydown Listener via Console Back-Channel

Inject a keydown listener inside the webview that captures keystrokes when a flag is true, then send them back to the renderer via `console.log` and the `console-message` event.

Result: does not work reliably. When `findInPage` has focus, it likely operates below the page's DOM event system. The injected keydown listener never fires for those keystrokes because they never reach the page's event loop.

### Attempt 5: CSS Custom Highlight API (Replace findInPage Entirely)

Since `findInPage` is the source of the problem, replace it with a pure DOM search using `TreeWalker` and the CSS Custom Highlight API.

Result: technically works but the UX is significantly worse. Navigation between matches was broken across complex page layouts. Shadow DOM and iframes were not covered. The keystroke capture mechanism blocked all page interaction while search was open. I abandoned this approach.

### The Solution: Main Process before-input-event

The insight was that `webContents.on('before-input-event')` in the main process properly supports `event.preventDefault()`, unlike the DOM-level event on the webview tag. By intercepting keystrokes at the main process level before `findInPage` can consume them, and forwarding them to the renderer via IPC, the search input receives every character.

The implementation adds the webview's webContentsId to a `capturingWebContents` Set when search is active. The main process `before-input-event` listener checks this Set and, for matching webContents, intercepts printable characters, Backspace, Enter, and Escape. These are forwarded via a `search:keystroke` IPC channel to the renderer, which inserts them into the active search input.

`findInPage` continues to handle highlighting and match navigation. It just no longer gets to eat the keystrokes.

### The Second Bug: findNext:false Silently Fails

With keystroke capture working, I discovered a second bug. Calling `findInPage(query, {findNext: false})` — which should start a new search — allocates a request ID but never fires a `found-in-page` event and never updates the visual highlights. This happens for both `webContents.findInPage()` and `webview.findInPage()` in Electron 28.3.3 when targeting webview guest contents.

The workaround is counterintuitive: call `stopFindInPage('clearSelection')` to tear down the current session, then immediately call `findInPage(query, {findNext: true})`. Despite `findNext: true` semantically meaning "continue searching", when there is no active session it starts a fresh search. And this code path actually fires events correctly.

```javascript
findNext(query) {
  const isNew = query !== lastQuery;
  lastQuery = query;
  if (isNew) {
    webview.stopFindInPage('clearSelection');
  }
  webview.findInPage(query, { forward: true, findNext: true });
}
```

### Takeaways

The main lesson is that Electron's webview tag occupies an awkward middle ground. It looks like a DOM element but its internals operate at the Chromium process level. DOM-level interception techniques (event listeners, `preventDefault()` on tag events) do not work against behaviors that happen below the page's event system. The main process is the only place where you can reliably intercept and prevent actions on webview contents.

The secondary lesson is that when a bug exists in the "correct" API path (`findNext: false`), sometimes the workaround is to use the "wrong" API path (`findNext: true` with no active session) that happens to trigger the right behavior through a different code path internally.

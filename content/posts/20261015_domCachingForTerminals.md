+++
title = "DOM Caching to Avoid Terminal Re-initialization in Electron"
description = "How an LRU DOM cache preserves terminal state across workspace switches without destroying and recreating xterm instances."
tags = [
    "electron",
    "performance",
]
date = "2026-10-15"
categories = [
    "tooling",
]
+++

Worklayer has workspaces, and each workspace has multiple panels including terminals. The naive implementation of switching workspaces would be: destroy the current workspace's DOM, render the new workspace's DOM. This works for web panels and file editors which can reload their state from a URL or file path. But terminals are different.

A terminal panel backed by xterm.js maintains state that cannot be trivially reconstructed: the scrollback buffer, the cursor position, the running process, the pty file descriptor. Destroying the DOM element means losing all of that. The user switches to a different workspace for thirty seconds, switches back, and their terminal shows a fresh prompt with no history. Unacceptable.

### The Approach: Detach, Don't Destroy

Instead of destroying workspace DOM containers when switching away, Worklayer detaches them from the document and holds a reference in a Map. When switching back, the cached container is reattached to the DOM. The terminal never knew it was gone.

The core data structure is simple:

```javascript
const groupDOMCache = new Map(); // groupId -> wrapper div
```

When rendering a workspace, the first check is whether a cached container exists. If it does, reattach it and call `fitAddon.fit()` on each terminal to adjust to any size changes. If it does not, build the workspace from scratch.

### LRU Eviction

Holding every workspace in memory indefinitely is not viable. Each cached workspace keeps its terminal processes alive, consuming memory and pty file descriptors. With twenty workspaces open, that could mean twenty shell processes running in the background.

An LRU (least recently used) eviction policy bounds the cache:

```javascript
const lruOrder = []; // index 0 = least recently used

function touchLRU(groupId) {
  const idx = lruOrder.indexOf(groupId);
  if (idx !== -1) lruOrder.splice(idx, 1);
  lruOrder.push(groupId);
}

function evictLRU() {
  while (lruOrder.length > maxCached) {
    const evictId = lruOrder.shift();
    const el = groupDOMCache.get(evictId);
    if (el) el.remove();
    groupDOMCache.delete(evictId);
    killGroupTerminals(evictId);
  }
}
```

The default maximum is 20 cached workspaces. When you switch to workspace 21, the least recently used workspace is evicted: its DOM is removed, its terminal processes are killed, and its pty file descriptors are closed. The next time you switch to that workspace, it will be rebuilt from scratch. In practice, 20 is generous enough that eviction rarely happens during a normal session.

### Fit on Reattach

When a cached workspace is reattached, the terminal dimensions may have changed. The viewport might have been resized, or the sidebar width might have changed. Each terminal panel's `fitAddon.fit()` is called after reattachment:

```javascript
function fitVisibleTerminals(groupId) {
  group.panels.forEach(p => {
    if (p.type === 'terminal' && activeTerminals.has(p.id)) {
      const { fitAddon } = activeTerminals.get(p.id);
      if (fitAddon) fitAddon.fit();
    }
  });
}
```

This sends the updated column and row counts to the pty, so the shell and any running programs (like vim or htop) adjust their output correctly.

### Why Not Save and Restore State?

An alternative approach would be to destroy terminals but serialize their state: save the scrollback buffer, reconnect to the pty process, and reconstruct the xterm instance. This is how some terminal multiplexers work.

I rejected this because:

1. **Process state is hard to serialize.** The pty process is still running. You need to keep it alive regardless, so you might as well keep the DOM alive too.
2. **xterm.js restoration is imperfect.** Writing saved scrollback into a new xterm instance does not perfectly reproduce visual state (colors from escape sequences, cursor position relative to running programs).
3. **Latency.** DOM detach/reattach is instant. Serialization and reconstruction adds visible delay during workspace switches.

The DOM cache trades memory for instant switching. For a desktop app where the user has 8-32GB of RAM, this is the right trade.

### Cache Invalidation

When a workspace is deleted by the user, its cache entry must be explicitly removed:

```javascript
function removeCachedGroup(groupId) {
  const el = groupDOMCache.get(groupId);
  if (el) el.remove();
  groupDOMCache.delete(groupId);
  const idx = lruOrder.indexOf(groupId);
  if (idx !== -1) lruOrder.splice(idx, 1);
}
```

This kills the terminal processes and frees the pty file descriptors immediately rather than waiting for LRU eviction.

### The Result

Workspace switching is perceptually instant. Terminals retain their full scrollback, running processes continue uninterrupted, and the cursor stays exactly where it was. The user can freely jump between tasks without any "loading" or state loss. The LRU bound ensures memory usage stays reasonable even with many workspaces, gracefully degrading the oldest unused workspaces when limits are reached.

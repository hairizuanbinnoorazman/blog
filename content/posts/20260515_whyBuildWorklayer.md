+++
title = "Why I Built a Workspace-Focused Electron App"
description = "Building an Electron app that groups terminals, web panels, and file editors into scrollable workspaces to eliminate context switching."
tags = [
    "electron",
    "productivity",
]
date = "2026-05-15"
categories = [
    "tooling",
]
+++

I spend most of my working day jumping between a terminal, a browser, and an editor. Usually multiple instances of each, spread across different virtual desktops or hidden behind other windows. Every time I switch context between projects, there is a cost. I have to remember which terminal is running which service, which browser tab has the right dashboard, and which editor window has the file I was working on. The state is scattered.

I wanted a single surface where one tab equals one project, and that tab contains everything I need: terminals, web panels, and file editors side by side. So I built Worklayer.

### The Problem with Existing Tools

Window managers solve part of this. Tiling WMs like i3 or Hyprland keep windows organized spatially. But they operate at the OS level and treat every application as an opaque rectangle. They cannot group a terminal, a browser tab, and a file editor into a single switchable unit.

IDE integrated terminals and browsers get closer, but they are locked into the IDE's ecosystem. I wanted something that works with any web app, any shell, and any file, without being tied to VS Code's extension model or IntelliJ's project structure.

### One Tab, Everything Together

Worklayer's core concept is the workspace. A workspace is a named group of panels. Each panel is one of three types:

- **Terminal panels** — persistent shell sessions powered by xterm.js and node-pty. They survive workspace switches without losing scrollback.
- **Web panels** — embedded Chromium webviews with full navigation. Dashboards, documentation, pull request reviews, anything with a URL.
- **File panels** — a file browser plus Monaco editor with syntax highlighting and LSP support.

Switching workspaces switches all panels at once. The mental model is simple: one workspace per unit of work. A debugging session might have a terminal running logs, a web panel showing Grafana, and a file panel open to the relevant source. When I switch to a different task, all three disappear together and the new task's panels appear.

### Scrollable Tiling from Niri

The layout inside a workspace is horizontally scrollable, inspired by Niri, a scrollable tiling Wayland compositor. Instead of forcing panels into a fixed grid that gets cramped as you add more, panels extend horizontally and you scroll to reach them. This means you can have as many panels as you need without any of them shrinking to unusable sizes.

The resize UX took several iterations to get right:

- **Drag handles** between panels let you adjust widths. They are deliberately wider than a typical 1px border so they are easy to grab.
- **requestAnimationFrame throttling** on resize events prevents layout thrashing. Without this, dragging a handle would fire hundreds of resize events per second and the UI would stutter.
- **Double-click to expand** — double-clicking a drag handle expands that panel to 2x its current width. Useful when you need to temporarily focus on one panel.
- **Auto-scroll near edges** — when dragging a handle near the left or right edge of the viewport, the panel strip automatically scrolls in that direction. This makes it possible to resize panels that are partially off-screen.

### Templates and Profiles

Once I had workspaces working well, I found myself recreating the same layouts repeatedly. Every time I started working on a specific microservice, I would create the same three panels with the same working directories and URLs.

Templates solve this. You save a workspace configuration as a template, and next time you can instantiate it in one click. The template preserves panel types, order, working directories, startup commands, and URLs.

Profiles take this further by providing isolation boundaries. Each profile has its own set of workspaces, templates, and URL history. I use separate profiles for different teams or contexts, so work-related URLs and layouts do not leak into personal projects.

### What This Enables

The real payoff is not any single feature but the elimination of the constant low-level question: "where did I put that?" When everything for a task lives in one workspace, returning to that task after an interruption is instant. There is no archaeology of finding the right terminal among fifteen tabs.

It also changes how I interact with AI coding tools. Because Worklayer has a built-in MCP server, Claude Code running in a terminal panel can control an adjacent web panel directly. The AI can navigate, click, and screenshot without leaving the app. But that is a topic for a future post.

The source code is an Electron app with vanilla JavaScript, no React or framework overhead. The main dependencies are xterm.js for terminals, Monaco for the editor, and node-pty for native pseudoterminals. It builds to a macOS DMG targeting Apple Silicon.

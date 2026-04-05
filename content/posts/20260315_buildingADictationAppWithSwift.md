+++
title = "Building a dictation app with Swift"
description = "Building a dictation app with Swift"
tags = [
    "swift",
]
date = "2026-03-15"
categories = [
    "swift",
]
+++

I've been wanting to reduce the amount of typing I do on a daily basis. Between writing messages, emails, and documentation - there's a lot of text to produce. macOS does have a built-in dictation feature but I had concerns about its accuracy - it relies on a model running locally on the Mac, and I figured a cloud-based speech-to-text service would produce better results, especially for technical jargon and longer dictation sessions. On top of that, the built-in dictation doesn't clean up filler words, and I wanted something that I could customize to my own needs. So I decided to build my own dictation app.

## The idea

The concept is simple: press a hotkey to start recording, press it again to stop, and have the transcribed text injected directly into whatever app I'm currently using. No need to switch windows, no copy-pasting - just speak and the text appears where my cursor is.

The app runs as an accessory app (no Dock icon) with a floating overlay at the bottom of the screen that shows a waveform animation while recording and the transcription result when done.

## Tech stack choices

I went with Swift and Swift Package Manager for this. Since this is a macOS-only app that needs deep integration with system-level features like global hotkeys and clipboard access, Swift felt like the natural choice. The app uses:

- **AVFoundation** for microphone capture (mono Int16 PCM audio)
- **CoreGraphics** for global hotkey interception via `CGEventTap`
- **AppKit** for the floating overlay panel with a custom waveform view
- **AWS Transcribe Streaming** for the actual speech-to-text
- **AWS Bedrock (Claude Haiku)** for cleaning up the raw transcription

## The global hotkey problem

One of the trickier parts was setting up the global hotkey. macOS requires `CGEventTapCreate` to intercept keyboard events globally, which means the app needs **Input Monitoring** permission. This is a system-level permission that the user has to grant manually through System Settings.

The hotkey I chose is **Ctrl+Option+K** - uncommon enough to not conflict with other shortcuts. I also had to add debouncing (300ms) because `CGEventTap` can fire multiple times for a single key press, which would cause the app to toggle recording on and off immediately.

## Audio capture and the TCC rabbit hole

Getting the microphone to work was surprisingly frustrating. macOS controls microphone access through TCC (Transparency, Consent, and Control), and the permission state can become stale. I ran into a situation where I had granted microphone permission in System Settings, but `AVAudioEngine` would hang for about 10 seconds and then fail with `kAudioHardwareNotRunningError`.

The fix? Restart the computer. macOS caches TCC permission state and sometimes the change doesn't take effect until after a full reboot. This was not obvious at all and took a while to figure out.

Another thing I learned: for CLI apps built with SPM, the TCC permission is tied to the **terminal application** (e.g. Terminal, iTerm2), not the built binary itself. Embedding an `Info.plist` doesn't help - you need to grant permission to whatever terminal you're running the app from.

## The transcription pipeline

The pipeline has two stages:

1. **AWS Transcribe Streaming** - Takes the raw PCM audio and produces text. The audio is streamed in 16KB chunks via an `AsyncThrowingStream`. This works well because it means we don't need to wait for the entire audio to upload before transcription starts.

2. **AWS Bedrock (Claude Haiku)** - Takes the raw transcription and cleans it up. The raw output from speech-to-text often includes filler words like "umm", "uh", "like", "you know" and has imperfect punctuation. The Bedrock call uses a system prompt that tells it to act as a "dumb text formatter" - only removing fillers and fixing grammar without changing the meaning.

This two-stage approach works quite well. The raw transcription is already decent from AWS Transcribe, and the cleanup pass from Haiku makes it read much more naturally.

## Text injection

Once we have the cleaned text, we need to get it into whatever app the user was typing in. The approach is straightforward: copy the text to the clipboard via `NSPasteboard`, then simulate a **Cmd+V** paste using `CGEvent`. There's a small 50ms delay between the clipboard write and the simulated paste to make sure the clipboard is ready.

This clipboard-based approach is a bit of a hack but it's reliable and works across all applications. The downside is that it overwrites whatever was previously on the clipboard.

## State management

The app uses a simple state machine with four states: **idle**, **starting**, **recording**, and **transcribing**. This prevents issues like trying to start a new recording while one is already in progress, or pressing the hotkey while transcription is happening.

There's also a 30-second safety timeout on the transcription step - if AWS Transcribe or Bedrock hangs for whatever reason, the overlay gets force-hidden and the app returns to idle. This prevents the app from getting stuck in a broken state.

## Learnings

A few things I picked up from this project:

- **macOS permissions are painful for CLI apps** - TCC, Input Monitoring, and Accessibility permissions are all designed around `.app` bundles, not SPM executables run from a terminal. Expect to spend time debugging permission issues.
- **Speech-to-text output benefits from a cleanup pass** - Raw transcription is functional but messy. Running it through an LLM to clean up fillers and punctuation makes a big difference in quality for minimal cost (Haiku is cheap).
- **Global hotkeys need debouncing** - `CGEventTap` can fire multiple events for what feels like a single key press. Without debouncing, the app would toggle on and off immediately.
- **Reboot after granting TCC permissions** - If audio capture fails after granting microphone access, try restarting. The permission cache is real and will waste hours of your time if you don't know about it.

The source code is available on my GitHub if anyone wants to take a look or build something similar.

+++
title = "Designing a Runtime Protocol Across Multikernel Linux Kernels"
description = "How bounded framing, strict messages, authenticated generations, sequence numbers, and replay-safe I/O make cross-kernel runtime operations recoverable."
tags = [
    "linux",
    "containers",
    "networking",
    "multikernel",
]
date = "2026-09-04"
categories = [
    "cloud",
]
+++

The components in my Multikernel container runtime do not share one ordinary process hierarchy. The containerd shim and `mkruntimed` run in the primary Linux system, while `mk-agent` and the workload run under a child kernel. Calls that would normally be local runtime operations therefore become protocol messages.

That creates a less visible part of the project: making a request reliable when connections can be truncated, replies can be lost, peers can restart, and stale clients can retain old sandbox names. The protocol cannot assume that one successful `Write` sent a complete message or that reconnecting means starting the sequence again.

This article describes the protocol choices in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## Two transports, one message discipline

There are two main control paths:

```text
containerd shim
  -> root-owned Unix stream socket
      -> mkruntimed

containerd shim or controller
  -> Unix socket
      -> mkvsock-relay
          -> Multikernel AF_VSOCK
              -> mk-agent in the child
```

The daemon protocol uses a local Unix socket because both peers run in the primary. The agent protocol crosses the kernel boundary over the pinned Multikernel VSOCK transport. Direct Go AF_VSOCK endpoints proved unsafe with that pinned implementation, so the supported path uses a small C relay and lets the Go processes speak over Unix sockets on their respective sides.

Although the transports differ, both use explicit byte limits and strict JSON messages. Their message boundaries are different. A daemon call uses one request per Unix connection: the client writes one bounded JSON object and closes its write side, and the server reads to that boundary before replying. The longer-lived agent session uses explicit length-prefixed frames so it can carry many requests and replies.

## Communication is bidirectional, but not symmetric

Describing this as a primary-to-child control protocol does not mean that information travels only toward the child. The established session carries data in both directions. What differs is which side is normally allowed to initiate an application-level operation.

The child connects through the Multikernel VSOCK relay, but after that connection is established the controller in the primary normally drives the agent conversation. It sends a request and `mk-agent` returns a response with the same sequence identity:

```text
Primary -> child: CreateProcess, StartProcess, SignalProcess, WriteProcess
Child   -> primary: success/error, process state, next stdin offset

Primary -> child: ReadProcessOutput after stdout offset N
Child   -> primary: the next bounded stdout or stderr bytes

Primary -> child: ExchangeNetwork plus an optional inbound IP packet
Child   -> primary: an optional outbound IP packet and updated result
```

Process exit and output therefore travel from child to primary, but version 1 does not give `mk-agent` a separate unsolicited event channel. The primary observes them by issuing bounded state, wait, or offset-based output requests. The network exchange is similarly driven by the primary-side packet pump even though IP packets can flow in either direction.

Storage uses a different cross-kernel protocol. The child Linux NBD client initiates block reads, writes, flushes, and disconnects toward a primary-owned NBD server. Those messages do not pass through the agent process-control envelope described in this article. Additional volume transport is also not implemented yet; the current mediated NBD path supplies the sandbox root.

There is one more child-to-primary signal below the agent API. After the final successful `Shutdown` reply, the child syncs and invokes its Multikernel-specific poweroff path. The child kernel notifies the primary and parks its CPUs, allowing the primary to observe the instance returning to a reclaimable state.

The complete direction map is therefore:

| Path | Initiator | Information returning to the primary |
|---|---|---|
| Agent control session | Usually the primary controller | Replies, process state, exit status, capabilities, and output chunks |
| Network packet exchange | Primary-side packet pump | Outbound packets produced by the child |
| Mediated NBD storage | Child NBD client | Child-issued block operations handled by the primary server |
| Child poweroff | Child kernel | Multikernel shutdown notification and parked CPUs |

This asymmetry is intentional. The primary remains the lifecycle authority, while the child can return results and originate the narrowly defined storage and shutdown operations needed to run and stop itself.

## A stream does not preserve messages

Unix streams and stream-oriented VSOCK connections deliver bytes, not application messages. One write may be split across several reads, and one read may contain parts of multiple writes. EOF is also unsuitable as the normal delimiter when a connection carries several requests.

Each agent protocol frame therefore starts with a four-byte big-endian length followed by exactly that many payload bytes:

```text
+----------------------+-------------------------+
| uint32 payload size  | one JSON object         |
+----------------------+-------------------------+
```

The maximum agent payload is 1 MiB. An oversized length is rejected before allocation, while a truncated payload ends the session. Exactly one JSON object is accepted per frame. The daemon applies the same one-MiB bound to its single-request connection even though it uses the connection's write boundary rather than a length prefix.

Writes need a loop for the same reason. A successful low-level write may report that it accepted only a prefix. The shared framing code continues until every byte is delivered, returns an error on failure, and treats zero progress as an error. Otherwise a wrapped or faulty transport could silently turn a valid request into a truncated frame.

## Strict JSON is part of compatibility

It is tempting to let Go's JSON decoder ignore fields it does not recognize. That is dangerous for a runtime. A newer client might send a security field that an older server silently discards, leaving the client believing that a restriction was applied.

The protocol rejects:

- unknown fields;
- duplicate object keys;
- multiple JSON values in one frame;
- missing version, request, body, or identity fields; and
- a response containing both a result and an error, or neither.

Additive evolution therefore requires an advertised capability and an explicitly optional field. A change that an older peer cannot safely ignore is `UNSUPPORTED`, while a major-version mismatch is always rejected.

This makes compatibility less convenient, but it makes the meaning of a successful reply much stronger.

## Every request is bound to an identity

Daemon requests contain a protocol version, request ID, method, and typed body. Mutations additionally carry a sandbox ID, generation, and idempotency key.

Agent messages add more context:

```text
protocol version
sandbox ID
sandbox generation
endpoint
monotonic sequence number
typed method and body
HMAC-SHA256
```

The HMAC uses a random 256-bit token generated for the sandbox and installed through runtime-owned bootstrap data. It prevents an accidental or stale peer from issuing a valid request for another sandbox generation. Sequence numbers reject replay and reordering.

The authentication claim is intentionally narrow. The token does not protect against a compromised primary or a malicious child kernel capable of reading shared memory. It binds messages within the trusted-node design; it is not a replacement for a hypervisor boundary.

Version 1 authenticates requests but does not add a reply MAC. A reply is bound to the authenticated point-to-point connection and sequence that carried the request. Adding cryptographic reply integrity would be a visible protocol capability or new major version, not a silent wire change.

## Reconnection cannot reset history

An agent transport disconnect does not kill the managed processes. The controller can reconnect using the same sandbox identity and token, then continue with the next sequence number.

Starting again at sequence one is rejected. Without that rule, an old captured request could become valid whenever the relay restarts. The sequence belongs to the authenticated sandbox session, not to the lifetime of one socket.

Reconnection also requires the server to release the old session cleanly. Completed connections unregister their cancellation callbacks and release their waiters. When the agent shuts down, canceling the server closes the listener and any currently accepted connection, including a peer stalled halfway through a frame.

Primary-side services apply a similar bound. Their accept loops admit at most a configured number of handlers—128 by default and never more than 1,024. Connections beyond the budget are closed without creating an unbounded goroutine population, and server shutdown waits for every admitted handler to finish.

## Exactly-once stdin is built above the transport

TCP-like reliability is not enough for application-level retry. Consider this sequence:

```text
shim sends stdin bytes 0..4095
  -> agent writes all bytes to the process
  -> reply is lost
  -> shim reconnects
  -> what should retry do?
```

If the shim repeats a plain write, the process receives duplicate input. If it assumes success, bytes may be lost when the failure occurred earlier.

The `stdin-offset-v1` capability attaches an offset to every chunk. The agent accepts only the exact next offset. It remembers the most recently completed chunk's starting offset, length, and SHA-256 digest, so an exact replay receives the same acknowledgement without another process write.

There is an even narrower failure window: a local pipe write can accept a prefix and return an error. The agent records how much of the chunk reached the pipe. An exact replay resumes with the remaining suffix; a replay with different bytes, length, or offset fails.

The acknowledged offset advances only after the complete chunk has been accepted. This is an example of application semantics that the byte transport cannot provide by itself.

## Output is resumable and bounded

Stdout and stderr move in the opposite direction through independent offset-based reads. The caller asks for a bounded chunk after an offset, stores it, and advances its cursor. Process state and wait results contain only metadata, so output pressure cannot make an otherwise small state reply exceed the frame limit.

Each stream retains at most 4 MiB. When its buffer fills, it briefly applies backpressure. If the reader remains absent, the agent marks the stream truncated and allows the child process to continue. Silent unbounded memory growth and permanent workload blockage are both worse outcomes.

Network exchange is bounded differently: one request transports at most one IP packet in each direction, with a maximum packet size of 65,535 bytes. The endpoint's negotiated MTU is usually smaller, but the wire bound still prevents an arbitrary message from consuming memory.

## Replies and events must survive restart

The daemon echoes the request ID and returns either a typed result or a structured error. If a result cannot be encoded within the one-MiB limit, the server substitutes a bounded `INTERNAL` error that preserves the request ID.

Lifecycle completion events live in the durable journal rather than only in an in-memory channel. `WatchEvents` accepts an exclusive `after_sequence` cursor and a bounded limit. A shim can repeat the call after reconnecting and continue from its last acknowledged event without inventing events or requiring the original daemon process to survive.

The containerd shim uses the same idea for task events and stream state. Its recovery record stores sandbox generation, guest process IDs, exits, output offsets, FIFO identities, terminal state, and network identity. A replacement worker must validate that durable identity before reconnecting to a running task.

## Failure behavior is part of the protocol

A useful protocol test suite must exercise more than valid request and response pairs. The repository tests include:

- short successful writes and zero-progress writes;
- oversized, truncated, malformed, duplicate-field, and multi-value frames;
- wrong sandbox, generation, endpoint, sequence, and HMAC values;
- request cancellation while a peer is blocked before completing a frame;
- reconnect with continuing sequence state;
- exact and altered stdin replays after a lost response;
- partial local stdin writes;
- slow or absent output readers; and
- connection admission limits and shutdown joining.

These tests expose a general lesson from the runtime: a protocol is not only a list of methods. It is the framing, identity, retry, cancellation, memory, and compatibility behavior surrounding those methods. Across two kernels, those surrounding rules are what keep an ordinary socket failure from becoming duplicated input, stale cleanup, or an unbounded resource leak.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Protocol v1 contract](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/contracts/protocol-v1.md)
- [Protocol framing implementation](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/protocol/io.go)
- [Protocol types](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/protocol/types.go)
- [`mk-agent` server](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/server.go)
- [Running OCI Processes Inside a Multikernel Linux Child]({{< ref "20260903_ociProcessesInsideMultikernelLinux.md" >}})

+++
title = "Recovering Multikernel Runtime State After a Crash"
description = "How mkruntimed uses generations, idempotency keys, a durable journal, and reconciliation to avoid leaking or releasing the wrong child-kernel resources."
tags = [
    "linux",
    "containers",
    "containerd",
    "multikernel",
]
date = "2026-09-02"
categories = [
    "cloud",
]
+++

My earlier [walkthrough of a Multikernel container from the primary Linux system]({{< ref "20260901_observingMultikernelContainersFromPrimaryLinux.md" >}}) followed a successful task from containerd through a shim, `mkruntimed`, Kerf, and finally a child kernel. The normal path is only half of a runtime, though. The harder question is what to do when one of those steps succeeds but the caller disappears before learning the result.

Suppose `mkruntimed` asks Kerf to allocate CPUs and memory. Kerf succeeds, but the daemon is killed before replying to the shim. The shim sees a disconnected socket. It cannot tell whether nothing happened, whether the complete child exists, or whether only part of the allocation exists. Blindly retrying might allocate the resources twice. Blindly deleting by container name might destroy a newer sandbox that reused that name.

The runtime handles this uncertainty with four related ideas: a durable state machine, generation-qualified identity, idempotent requests, and reconciliation against observed Kerf state. The implementation is in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## One component owns the global lifecycle

The containerd shim does not invoke Kerf or write to `/sys/fs/multikernel`. It translates Task v2 operations into requests to `mkruntimed`, and `mkruntimed` is the only runtime service allowed to mutate the Multikernel pool and child instances.

That separation gives the system one place to answer ownership questions:

```text
containerd
  -> per-task shim
      -> mkruntimed
          -> lifecycle state and durable journal
          -> Kerf adapter
              -> Multikernel pool and child instance
```

If every shim allocated CPUs independently, two simultaneous creates could select the same CPU. If a cleanup utility guessed ownership directly from Kerf output, it could remove something created by a different runtime generation. `mkruntimed` instead combines a global allocation lock with a per-sandbox transition lock. Allocation decisions are serialized globally, while unrelated sandboxes can retain separate lifecycle identities.

## A sandbox name is not its identity

Container names are reusable. A task called `worker` can be deleted and a different task called `worker` can be created later. The name alone is therefore unsafe for delayed retries or cleanup.

Every successful create adds a random 128-bit generation:

```text
sandbox ID: worker
generation: 1b50de9ce9c0bc9370a0f59b8d1a9c69
```

All later requests identify the pair. If an old shim sends a request for `worker` with the previous generation, the daemon returns `STALE_GENERATION`. It does not reinterpret that stale request as permission to act on the current `worker`.

The same principle appears elsewhere in the runtime. Network endpoints, storage exports, recovery records, and agent sessions are bound to a sandbox generation. Generation-qualified identity turns “delete something with this convenient name” into “delete the exact resource incarnation that I created.”

## Retries also need an operation identity

A generation distinguishes resource incarnations, but a network retry can still repeat an operation. Every mutation therefore includes an idempotency key. The daemon fingerprints the method and its input, then durably stores the result under that key.

There are three important outcomes:

- A retry with the same key and the same fingerprint receives the recorded result.
- Reusing the key with different input returns `IDEMPOTENCY_CONFLICT`.
- A different key represents a different requested operation and must pass the normal state checks.

This matters most when the mutation succeeded but its response was lost. The client can repeat the exact request without creating a second child or advancing the state twice.

Idempotency is not the same as making every operation silently succeed. A new request to delete an absent sandbox returns `NOT_FOUND`; only an exact replay of the previously completed delete gets the old successful result. Otherwise an unbounded collection of names would need to remain reserved forever.

## Journal intent before touching Kerf

The lifecycle uses a write-ahead pattern. Before performing an external mutation, it records an `intent`. After observing the expected outcome, it records `complete` and commits the new sandbox state.

The main state progression is:

```text
ABSENT
  -> ALLOCATING
  -> CREATED
  -> LOADED
  -> RUNNING
  -> STOPPING
  -> STOPPED
  -> RELEASING
  -> ABSENT
```

`ERROR` is metadata on the last known durable state rather than a magical extra state. This distinction matters. An error says that an operation failed or became uncertain; it does not prove that CPUs, memory, an image export, or a child instance can be safely released.

Consider a simplified create:

```text
persist CREATE intent
  -> create or extend the Kerf pool
  -> create the child instance
  -> observe the expected backend identity
  -> persist CREATE completion and CREATED state
```

A crash before the intent means that the runtime has not authorized the mutation. A crash after completion can replay the durable result. A crash between them leaves an incomplete operation that reconciliation must investigate.

## Reconciliation observes instead of guessing

When `mkruntimed` restarts, it loads its journal and asks the backend what actually exists. It compares durable state with Kerf's observed pool and instance state, then either completes a safe transition or records that operator action is required.

For example:

- An incomplete create with the expected child present can be completed forward.
- A stopped child with matching recorded ownership can continue toward deletion.
- A resource with an unknown owner is not deleted merely because it looks stale.
- A mismatch that cannot be resolved safely becomes `OPERATOR_ACTION`.

This is deliberately conservative. Leaking a CPU allocation until an operator investigates is undesirable, but releasing memory or a child belonging to another generation is worse. Cleanup is conditioned on evidence of ownership.

The daemon also exposes completion events from its durable journal. A shim can call `WatchEvents` with an exclusive sequence cursor and resume after a restart. The event stream does not depend on an in-memory subscriber surviving alongside the daemon.

## The awkward create-cancellation case

Create has one especially difficult failure window. The shim may not know whether `CreateSandbox` succeeded, but it still needs to roll back a failed containerd `Create`.

The runtime provides `CancelCreateSandbox` for this exact case. It is not a general delete shortcut. The cancellation must carry the original idempotency key and the complete configuration fingerprint. It is allowed only while durable and observed state remain within the create-only part of the lifecycle: absent, allocating, or created.

If the sandbox has progressed to `LOADED` or `RUNNING`, cancellation fails. That protects a valid running child from a delayed timeout handler. A successful cancellation records an `ABORTED` replay result, so the original create request cannot arrive later and allocate the sandbox again.

## Errors tell the caller what must happen next

The protocol uses stable error codes rather than expecting callers to interpret command output. Some examples are:

| Error | Meaning for the caller |
|---|---|
| `STALE_GENERATION` | Rediscover the current sandbox identity. |
| `IDEMPOTENCY_CONFLICT` | Use a new key only for genuinely new input. |
| `RESOURCE_EXHAUSTED` | Retry after another allocation is released. |
| `BACKEND_TIMEOUT` | Reconcile before assuming success or failure. |
| `ABORTED` | The exact create was canceled and cannot be replayed. |
| `OPERATOR_ACTION` | Automatic ownership or cleanup cannot be proved. |

The difference between a retryable transport error and an uncertain backend mutation is important. Reconnecting to a socket is safe. Reissuing a resource mutation is safe only through the same idempotency and reconciliation contract.

## What I would test

The useful test is not simply restarting `mkruntimed` while nothing is happening. I want a fault point on every side of every external mutation:

```text
before intent
after intent, before Kerf
after Kerf, before observation
after observation, before completion
after completion, before reply
```

For each point, the test should restart the daemon and record:

- the durable journal;
- the observed Kerf pool and instances;
- the response to an exact retry;
- the response to a conflicting retry;
- whether storage and network generations remain correctly bound; and
- the final CPU, memory, child, and filesystem inventory after cleanup.

The repository has local fault injection and recovery tests for many of these boundaries. Full confidence still requires repeating the destructive matrix on a qualified Multikernel host and retaining the raw before-and-after evidence.

The main lesson is that recovery is not a cleanup script. It is a continuation of the runtime's ownership protocol. A child kernel should be released because the journal, generation, requested operation, and observed backend agree—not merely because a process restarted and something looks old.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Sandbox lifecycle and error contract](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/contracts/lifecycle.md)
- [`mkruntimed` lifecycle service](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/internal/lifecycle/service.go)
- [Durable state store](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/internal/state/store.go)
- [Observing a Multikernel Container from the Primary Linux System]({{< ref "20260901_observingMultikernelContainersFromPrimaryLinux.md" >}})

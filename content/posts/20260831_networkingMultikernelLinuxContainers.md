+++
title = "Networking Containers in Multikernel Linux Child Kernels"
description = "Building private TUN links, authenticated packet transport, NAT, outbound DNS and HTTP, and sibling isolation for Multikernel child kernels."
tags = [
    "linux",
    "networking",
    "containers",
    "multikernel",
]
date = "2026-08-31"
categories = [
    "cloud",
]
+++

Giving a Multikernel Linux child network access is not as simple as moving the host's network interface into it. On Google Compute Engine (GCE), the virtual NIC is also the primary kernel's route to SSH, metadata, and the guest agent. Assigning that device or its shared controller to a child would put management access at risk.

The implemented design therefore keeps the GCE NIC under the primary kernel and moves packets, not hardware. Each child receives a private point-to-point TUN link. Packets cross the Multikernel boundary through the authenticated agent connection, while the primary owns forwarding, firewall rules, and NAT.

This path now supports outbound DNS and HTTP for concurrent `ctr` and Docker workloads, while direct traffic from one sandbox to its sibling is rejected. The code and live proof are in my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt).

## The packet path

The implemented topology is deliberately small:

```text
container process in child kernel
  -> child mkn0 TUN, 172.30.x.2/30
  -> mk-agent packet exchange
  -> authenticated Multikernel transport
  -> primary mknX TUN, 172.30.x.1/30
  -> primary routing and iptables MASQUERADE
  -> GCE NIC
  -> internet
```

The primary and child each open a TUN device. A TUN interface carries layer-three IP packets rather than Ethernet frames, which fits this point-to-point design and avoids creating a virtual bridge inside the child.

The shim assigns one static `/30` per allocation slot. The first two tested sandboxes used:

| Sandbox | Primary end | Child end |
|---|---|---|
| `ctr` workload | `172.30.30.1/30` | `172.30.30.2/30` |
| Docker workload | `172.30.31.1/30` | `172.30.31.2/30` |

A `/30` provides exactly the two usable addresses needed by each link. The child installs its primary-side address as the default gateway, configures an MTU of 1400, and writes `nameserver 8.8.8.8` into the private root's `/etc/resolv.conf`.

## Transporting packets through the agent

The pinned Multikernel VSOCK implementation could not reliably sustain a second simultaneous stream, so the runtime multiplexes packet exchange over the existing agent channel. This is a practical compatibility choice, not the intended high-performance endpoint.

Every agent request carries protocol version, sandbox ID, random generation, endpoint number, monotonically increasing sequence, method, and body. It is authenticated with a per-sandbox 256-bit token. The packet exchange therefore uses the same identity checks as process lifecycle operations instead of opening an unauthenticated side channel.

The primary network pump reads at most one 65,535-byte packet from its TUN, sends it in an `ExchangeNetwork` request, and receives at most one packet from the child in the response. The child agent injects the inbound packet into its TUN and briefly polls for an outbound packet. Short waits keep lifecycle calls responsive when there is no traffic.

This request-response pump is enough for the functional proof. It is not a throughput design. Batching, independent streams, bounded queues, explicit backpressure, reconnect behavior, packet counters, and sustained-load testing remain future work.

## NAT stays in the primary

For each sandbox, the shim discovers the primary's default egress interface and installs three narrowly scoped rules:

- a `POSTROUTING` masquerade rule for that sandbox's `/30`;
- a forwarding rule from its TUN to the primary egress interface; and
- a return rule allowing only established or related traffic back to its TUN.

The child never receives the physical or virtual cloud NIC. It only sees `mkn0`, its private TUN endpoint. This preserves the primary kernel's network ownership and lets its normal network stack perform routing, connection tracking, and address translation.

Docker needs one extra detail. The test starts it with `--network none` because this runtime already provides the child link. Allowing Docker to attach its normal bridge veth to the shim process would mix two unrelated networking models and still would not place that veth inside the child kernel.

## Proving outbound connectivity

The GCE test launched one BusyBox container through `ctr` and one through Docker. It then executed the same checks inside both child kernels:

```sh
cat /proc/sys/kernel/random/boot_id
ip -4 address show dev mkn0
wget -T 15 -qO- http://example.com >/dev/null
```

Both HTTP requests succeeded. Because `wget` first had to resolve `example.com`, the same operation also exercised outbound DNS. The reported addresses matched their separate `/30` allocations, and the distinct boot IDs confirmed that the packets came from two different child kernels rather than two processes sharing the primary kernel.

## Why siblings cannot talk directly

The runtime does not install forwarding rules between sandbox TUN devices. Each sandbox has a route only to its own gateway and then outward through the primary's egress interface. The forwarding rules name that sandbox's TUN and the external interface; they do not permit `mkn0` to `mkn1` traffic.

The proof explicitly tried to ping the Docker child's `172.30.31.2` address from the `ctr` child at `172.30.30.2`. The request failed, producing the `CROSS_SANDBOX_ISOLATION_PASS` marker.

That demonstrates isolation for the tested direct path, but it is not yet a complete network-policy security result. Bypass tests, malformed traffic, fragmentation and MTU boundaries, loss and reordering, transport faults, and sustained load still need to be covered.

## Cleanup is part of networking

Creating network state is easy; reliably removing partial state is the harder lifecycle problem. If setup fails after a TUN or rule is created, the shim runs the same cleanup path used for normal teardown. It stops the packet pump, closes both TUN endpoints, deletes the three iptables rules, and removes the primary TUN device.

The shim writes the interface name, subnet, and egress device into its recovery record before the child is started. If the shim is killed, containerd's cleanup invocation can use that record to delete the network state and reclaim the child. A forced-shim-death test ended with no Multikernel instance, TUN link, NAT rule, or forwarding rule left behind.

After normal deletion of both live test containers, the proof also asserted that no `mkn*` links and no matching iptables rules remained. This is important on a long-lived node: stale NAT and forwarding rules are not merely clutter; they can silently weaken isolation for later workloads.

## What remains after the static proof

The test validates the central design decision: transparent IP connectivity is possible without transferring the GCE NIC to a child. The primary can mediate packets for two child kernels, provide DNS and HTTP egress, isolate their point-to-point links, and clean up the host state afterward.

There is no normal CNI `ADD`, `CHECK`, and `DEL` binary yet, no primary-owned pod network namespace, and no Kubernetes integration. The current shim directly creates host TUN devices and iptables rules. Performance and fault behavior also need substantially more testing.

Still, the functional boundary is now clear. Children own virtual interfaces; the primary owns real devices and policy; and an authenticated transport connects the two without pretending that a cloud NIC can safely belong to both kernels.

## References

- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [Mediated networking design](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/plans/05-networking.md)
- [Child network implementation](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/agent/manager.go)
- [Can Multikernel Linux Run on Google Compute Engine?]({{< ref "20260828_multikernelLinuxOnGoogleComputeEngine.md" >}})
- [Turning Container Images into Multikernel Linux Roots]({{< ref "20260831_containerImagesForMultikernelLinux.md" >}})
- [A containerd Runtime v2 Shim for Multikernel Linux]({{< ref "20260831_containerdRuntimeForMultikernelLinux.md" >}})

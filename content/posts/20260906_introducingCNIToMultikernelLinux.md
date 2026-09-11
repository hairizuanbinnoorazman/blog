+++
title = "Introducing CNI to a Multikernel Linux Runtime"
description = "What the Container Network Interface requires, what the caller must prepare, and how mk-cni, mknetd, the primary, and the child divide network ownership."
tags = [
    "linux",
    "containers",
    "cni",
    "multikernel",
]
date = "2026-09-06"
categories = [
    "cloud",
]
+++

My first [Multikernel container networking experiment]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}}) built a static `/30` link for each child. The primary owned a TUN interface, routes, NAT, and firewall rules; `mk-agent` owned another TUN inside the child; and an authenticated packet pump transported IP frames between them.

That proved the packet path, but it did not provide the normal interface used by container orchestrators. Container runtimes do not want a special “configure Multikernel networking” shell procedure. They expect a CNI plugin.

CNI—the Container Network Interface—is a small executable protocol for attaching an existing container network namespace to a network. It does not define Kubernetes services, ingress, or a universal packet data plane. It defines how a caller invokes plugins and how those plugins report the resulting interfaces, addresses, routes, and DNS configuration.

This article explains how I introduced that contract to my [multikernel-linux-expt repository](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt), and where the responsibilities of the caller, primary Linux system, and Multikernel child begin and end.

## CNI is an executable contract

A CNI plugin is an executable found through the caller's configured plugin path. The caller starts it with request parameters in environment variables and sends a JSON network configuration through standard input. The plugin reports a JSON result through standard output and uses its exit status to indicate success or failure.

A minimal Multikernel configuration in the repository is:

```json
{
  "cniVersion": "1.0.0",
  "name": "multikernel",
  "type": "multikernel",
  "socket": "/run/mknetd.sock",
  "cacheDir": "/var/lib/cni/multikernel"
}
```

The `type` selects the `multikernel` plugin executable. The extra socket and cache fields are specific to this implementation: the small `mk-cni` process asks the long-running privileged `mknetd` service to perform the host mutation and remembers the endpoint generation needed by later calls.

The main attachment parameters arrive through the environment:

| Variable | Meaning |
|---|---|
| `CNI_COMMAND` | Operation such as `ADD`, `CHECK`, `DEL`, or `VERSION`. |
| `CNI_CONTAINERID` | Caller-provided identity for this workload attachment. |
| `CNI_NETNS` | Path referring to the network namespace to configure. |
| `CNI_IFNAME` | Interface name requested inside that namespace. |
| `CNI_PATH` | Search path for plugin executables, especially in a chain. |
| `CNI_ARGS` | Optional caller-supplied attachment arguments. |

An attachment is identified primarily by the container ID and interface name. The network name and namespace are also important to the Multikernel implementation because they bind the allocation to the exact caller input.

## What the caller must do first

CNI does not normally ask the plugin to create the container's isolation domain. Before calling `ADD`, the runtime must create the network namespace and provide a reference to it through `CNI_NETNS`. It must choose a container ID and the desired interface name.

The caller is also responsible for:

- selecting the network configuration and its plugin order;
- locating and executing the plugin;
- serializing operations for the same attachment;
- preserving the successful `ADD` result for later `CHECK` and `DEL` behavior;
- calling `DEL` during teardown even when setup or container creation partly failed; and
- eventually removing the network namespace after plugins have undone their work.

For a conventional `runc` container, that namespace contains the workload process. The plugin might create a veth pair, move one end into the namespace, assign an IP address, and connect the host end to a bridge.

The Multikernel case is unusual: the workload does not execute in this primary-kernel namespace. The namespace instead becomes a primary-owned network attachment point that the runtime binds to the child sandbox.

```text
caller creates primary network namespace
  -> calls mk-cni ADD with its path
      -> mknetd builds the primary endpoint
          -> runtime binds endpoint to an exact child generation
              -> shim pumps packets to mk-agent
                  -> child TUN reaches the workload
```

The caller does not need to understand AF_VSOCK, Kerf, child CIDs, or the GCE NIC. Those belong behind the Multikernel runtime boundary.

## `ADD` creates an attachment, not the child kernel

For `ADD`, the CNI caller provides `CNI_CONTAINERID`, `CNI_NETNS`, and `CNI_IFNAME`. `mk-cni` validates the JSON and identifiers, constructs an endpoint request, and sends it over the root-owned `mknetd` Unix socket.

`mknetd` allocates a free private `/30`, assigns a random endpoint generation, and first persists the endpoint as `ALLOCATING`. Its Linux backend then creates the primary-side topology:

```text
primary root namespace
  mkv<generation> host veth
       |
       | veth transit /30
       |
caller-provided network namespace
  mkhost0
  requested interface, for example eth0, as a TUN
       |
       | packet descriptor later attached to shim
       |
Multikernel transport
       |
child mkn0 with the workload IP
```

The namespace enables IP forwarding between its TUN and veth. The primary installs a route to the child's `/30`, a generation-specific firewall chain, return-traffic handling, and source NAT through the configured external interface. Cross-sandbox egress through another Multikernel veth is dropped. Access to the GCE metadata address is limited to the DNS behavior required by this configuration rather than exposing the general metadata service.

After every operation succeeds, `mknetd` changes the durable endpoint state to `READY`. The CNI result contains the requested interface, the child address, gateway, and DNS policy. `mk-cni` verifies that the response exactly matches the request and that the `/30`, gateway, MTU, generation, ownership, and state are valid before returning it to the caller.

The child kernel does not boot during CNI `ADD`. Network allocation and sandbox lifecycle have separate owners. When the runtime later starts the task, it binds the ready CNI endpoint to the exact sandbox ID and sandbox generation, obtains the already-open TUN descriptor, and starts the authenticated packet pump.

This indirection also creates a conformance question that should not be hidden. In the current topology, the interface inside `CNI_NETNS` carries the primary-side gateway address, while the `ADD` result describes the child-side workload address. A conventional CNI caller expects the result to describe the interface it asked the plugin to configure in that namespace. Treating the namespace as a proxy for an interface in another kernel is the core Multikernel adaptation, but it still needs an explicit integration contract and end-to-end tests against the caller. Implementing the command names alone is not proof of complete CNI conformance.

## The TUN interface is a doorway for IP packets

A normal network interface connects the Linux network stack to some mechanism that can transmit packets. A physical interface such as the GCE NIC sends them through virtual hardware. One end of a veth pair sends Ethernet frames directly to its peer inside the same Linux kernel. A TUN interface is different: it sends layer-three IP packets to a userspace program through a file descriptor.

The direction of reads and writes can initially feel reversed:

```text
Linux routes a packet out through a TUN
  -> userspace reads that complete IP packet from the TUN descriptor

userspace writes a complete IP packet to the TUN descriptor
  -> Linux receives it as a packet arriving on the TUN interface
```

There is no Ethernet header and no emulated Ethernet cable on this boundary. TAP devices carry layer-two Ethernet frames; TUN devices carry layer-three IP packets. The runtime uses TUN because its packet pump needs complete IP packets and the link is point-to-point rather than a shared Ethernet segment.

The current CNI topology uses both a veth and a TUN because they solve different problems:

- The veth pair connects the primary root network namespace to the CNI-provided namespace. Both ends are managed by the primary kernel.
- The TUN connects that namespace to the shim's userspace packet pump.
- The packet pump carries the IP packet over the authenticated Multikernel transport.
- `mk-agent` writes the packet into a second TUN owned by the child kernel.

For an example child allocation of `172.30.30.2/30`, the namespace-side TUN is configured with gateway address `172.30.30.1/30`. The child-side TUN uses `172.30.30.2/30` and treats `.1` as its gateway. The two TUN devices are not one shared kernel object. They are endpoints in different kernels connected by the packet pump.

The MTU controls the largest IP packet Linux should send through the interface without fragmentation. This runtime records one negotiated MTU and applies it to the host veth, namespace veth, namespace TUN, and child TUN. A conservative value such as 1400 leaves room for transport overhead. Inconsistent MTUs would produce failures that look application-specific: small HTTP requests might work while larger transfers stall or fragment.

On the primary, an operator can inspect the pieces with commands like:

```sh
ip link show mkv0123456789a
ip netns list
ip -n mk-0123456789ab link show
ip -n mk-0123456789ab address show
```

The exact names are generation-derived. `mknetd` verifies that the interfaces are present, up, and configured with the recorded MTU rather than assuming that a durable state file proves the Linux objects still exist.

## Routes tell each Linux stack where the next hop is

An IP address identifies an endpoint; it does not by itself tell Linux how to reach every other address. Linux consults its routing table for each packet, chooses the most specific matching destination prefix, and sends the packet through the selected interface toward an optional next-hop gateway.

This design crosses three separate routing domains:

```text
child kernel routing table
  default via 172.30.30.1 dev mkn0

CNI namespace routing table in the primary kernel
  172.30.30.0/30 is attached to the TUN
  default via 100.64.30.1 dev mkhost0

primary root-namespace routing table
  172.30.30.0/30 via 100.64.30.2 dev mkv<generation>
  existing default route via the GCE NIC
```

The `100.64.30.1/30` and `100.64.30.2/30` pair is a transit network for the veth. It is not the address exposed to the child workload. Its purpose is to give the primary root namespace and the CNI namespace an explicit next-hop relationship.

Consider an outbound packet from `172.30.30.2` to `93.184.216.34`:

1. The child has no more specific route, so it selects its default route through `mkn0` and gateway `172.30.30.1`.
2. `mk-agent` and the shim carry the packet to the namespace TUN.
3. The namespace receives the packet on the TUN. Its default route sends the packet through `mkhost0` to transit peer `100.64.30.1`.
4. The veth delivers it to `mkv<generation>` in the primary root namespace.
5. The primary's normal default route sends it through the GCE NIC.

The return path needs the explicit route installed in the primary root namespace. After the destination server replies, the primary sees a packet for `172.30.30.2`. The route for `172.30.30.0/30` sends it through the generation's veth to `100.64.30.2`. The CNI namespace then directs it to the TUN, where the shim reads it and transports it into the child.

Without one of these routes, the packet is not automatically discovered elsewhere. It is normally dropped or follows an unrelated default route. Useful inspection commands are:

```sh
ip route show 172.30.30.0/30
ip -n mk-0123456789ab route show
```

`CHECK` verifies both the child-network route in the root namespace and the default route in the CNI namespace. This detects configuration drift such as an operator deleting a route while leaving all interfaces up.

## NAT gives private child addresses an external identity

The child address comes from a private range. An internet server does not have a route back to `172.30.30.2`, and GCE's surrounding network expects traffic from the VM's configured address rather than an unknown child subnet.

On Linux, the kernel's packet-filtering and address-translation framework is called Netfilter. `iptables` is the command-line tool used by this runtime to install rules into that framework. The vocabulary has several layers:

| Term | Meaning |
|---|---|
| Table | A collection of chains for one broad purpose. The `filter` table controls permission; the `nat` table changes addresses. |
| Chain | An ordered list of rules examined at one packet-processing stage. |
| Rule | A set of matches followed by an action. |
| Match | A condition such as source address, incoming interface, outgoing interface, or connection state. |
| Target | The action selected with `-j`, such as `ACCEPT`, `DROP`, `REJECT`, or `MASQUERADE`. |

Built-in chains are named for where they occur in the packet's journey. A simplified traversal is:

```text
packet arriving for the primary itself
  -> PREROUTING -> routing decision -> INPUT

packet passing through the primary
  -> PREROUTING -> routing decision -> FORWARD -> POSTROUTING

packet created by a primary process
  -> OUTPUT -> routing decision -> POSTROUTING
```

`PREROUTING` is reached before Linux decides where an arriving packet should go. `INPUT` handles a packet whose destination is the primary machine itself. `FORWARD` handles a packet being routed through the primary between interfaces. `OUTPUT` handles packets created locally. `POSTROUTING` is reached after Linux has selected the outgoing route and interface, immediately before the packet leaves that networking domain.

The child packet is forwarded traffic: it enters through the generation's veth, crosses the primary, and leaves through the GCE interface. It therefore encounters the `FORWARD` chain for permission and the `POSTROUTING` chain for final source-address translation.

Network Address Translation changes the packet as it leaves the primary. The runtime installs a `POSTROUTING` `MASQUERADE` rule for the exact child source address and the configured egress interface:

```text
before NAT
  source 172.30.30.2:49152
  destination 93.184.216.34:80

after NAT on the GCE NIC
  source <primary-VM-address>:<translated-port>
  destination 93.184.216.34:80
```

The corresponding command has this shape when the primary egress interface is `ens4`:

```sh
iptables -t nat -A POSTROUTING \
  -s 172.30.30.2/32 -o ens4 -j MASQUERADE
```

Each argument describes one part of the rule:

- `-t nat` selects the address-translation table. Without `-t`, iptables operates on the `filter` table by default.
- `-A POSTROUTING` appends the rule to the end of the `POSTROUTING` chain.
- `-s 172.30.30.2/32` matches only the exact child source address. A `/32` represents one IPv4 address.
- `-o ens4` matches packets whose selected output interface is the primary's external interface.
- `-j MASQUERADE` jumps to the action that replaces the private source with the current address of `ens4`.

`MASQUERADE` is a form of source NAT, commonly shortened to SNAT. Source NAT changes the sender address. Destination NAT, or DNAT, changes the destination and is commonly used for port forwarding. This runtime needs outbound SNAT; it does not publish an inbound child service with DNAT.

Using the interface's current address is convenient for a cloud VM whose address is part of host configuration rather than a value the runtime should duplicate. It also explains why this rule belongs in `POSTROUTING`: Linux must first choose `ens4` before `MASQUERADE` can use that interface's address.

Linux connection tracking, often called conntrack, remembers flows that pass through Netfilter. For TCP and UDP, a flow is distinguished using protocol plus source and destination addresses and ports. When NAT changes `172.30.30.2:49152` into the primary address and a translated port, conntrack records both forms. When the reply returns, the primary can reverse the mapping and restore destination `172.30.30.2:49152`. The route described above then carries the packet back toward the child.

This state is why the reply does not need a second manually configured reverse-NAT rule for every connection. The first packet establishes the translation; later packets belonging to that flow reuse it.

NAT solves address reachability; it does not decide whether traffic is allowed. Routing can select the GCE NIC and NAT can translate the source, but the firewall can still reject forwarding. These are separate Linux subsystems even though they participate in the same packet path.

The active translation rule can be inspected with:

```sh
iptables -t nat -S POSTROUTING
```

Deletion removes the exact generation's NAT rule. Leaving it behind could cause a later workload reusing the address to inherit stale behavior, which is why the rule is part of endpoint ownership rather than general host setup.

## Firewall rules define which routed traffic is permitted

Enabling IP forwarding allows Linux to route packets between interfaces, but it does not express the isolation policy. `mknetd` adds a dedicated iptables chain for every endpoint generation and jumps to it when traffic enters the root namespace from that endpoint's host veth.

These firewall rules use the default `filter` table. Its built-in `FORWARD` chain is specifically for traffic routed through the machine. It is different from `INPUT`, which protects services running on the primary itself, and `OUTPUT`, which handles traffic created by a primary process.

Rules in a chain are evaluated from top to bottom until a terminating target decides the packet's fate. The important targets here are:

- `ACCEPT`: allow the packet to continue;
- `DROP`: silently discard it;
- `REJECT`: discard it and normally return an error response; and
- a custom chain name: jump into that chain and evaluate its more specific rules.

`mknetd` inserts a rule near the beginning of `FORWARD` with this general shape:

```sh
iptables -I FORWARD 1 \
  -i mkv0123456789a -j MK-0123456789ab
```

Here, `-I FORWARD 1` inserts at position one instead of appending, `-i` matches the interface on which the packet entered the root namespace, and `-j` sends the packet into the endpoint's private chain. The interface and chain names are derived from the endpoint generation, preventing two live endpoints from sharing policy objects accidentally.

The chain applies its rules in order:

1. Drop packets whose source is not the exact allocated child address. This is an anti-spoofing check: the child cannot claim to be a sibling or some arbitrary primary-network address.
2. Permit DNS over UDP or TCP to `169.254.169.254` when that address supplies the configured resolver behavior.
3. Reject other traffic to `169.254.169.254`, preventing general access to the GCE metadata service through the DNS exception.
4. Drop traffic whose output interface matches another Multikernel veth. This prevents direct routing from one sandbox to a sibling.
5. Accept traffic leaving through the configured external interface.
6. Drop everything else as the chain's final fallback.

There is a separate return rule. It uses `-i` for the external incoming interface, `-o` for the endpoint's outgoing veth, and the conntrack match `--ctstate RELATED,ESTABLISHED`.

`ESTABLISHED` means the packet belongs to a flow already seen in both directions, or to the continuing tracked conversation created by the child's outbound packet. `RELATED` means it belongs to a separate flow that conntrack can associate with an existing one, such as certain protocol error or helper-generated traffic. `NEW` would describe the beginning of an unrelated connection and is deliberately absent from this return rule.

Packets arriving from the external interface may therefore go back to the endpoint veth only when connection tracking associates them with permitted existing traffic. An arbitrary new inbound connection is not accepted merely because outbound NAT exists.

```text
child starts outbound connection
  -> endpoint chain validates source and egress
  -> connection tracking records the flow
  -> NAT translates it

reply arrives
  -> connection tracking recognizes ESTABLISHED traffic
  -> return rule permits it toward the endpoint

unrelated inbound packet
  -> no matching established flow
  -> not permitted by the endpoint return rule
```

An operator can inspect the generation-specific policy with:

```sh
iptables -S FORWARD
iptables -S MK-0123456789ab
```

The generation in the chain name ties the rules to one endpoint incarnation. During `DEL`, `mknetd` removes the jump rules, flushes and deletes the private chain, and removes the NAT rule. During `CHECK`, it verifies each expected rule individually. A chain existing under the right name is insufficient if its anti-spoofing or final-drop rule has disappeared.

The distinction between `DROP` and `REJECT` is intentional in the metadata rules. `REJECT` gives an immediate failure for prohibited metadata access instead of making the workload wait for a timeout. The final catch-all uses `DROP`, ensuring that traffic not explicitly described by the endpoint policy does not escape through an unexpected interface.

These rules provide the current narrow policy: an exact child source may initiate traffic through the primary's external interface, receive replies to tracked connections, and use the allowed DNS path, but it may not route directly to another Multikernel endpoint. They are not a general Kubernetes NetworkPolicy implementation.

## Two generations solve two different reuse problems

The endpoint has its own generation, while the child sandbox has a sandbox generation:

```text
CNI attachment identity
  network + container ID + interface
  endpoint generation

Multikernel sandbox identity
  sandbox ID
  sandbox generation
```

`ADD` creates the first identity. Runtime `BIND` joins it to the second. A stale CNI cache cannot delete a newly allocated endpoint, and a stale shim cannot attach an endpoint belonging to a different child incarnation.

`mk-cni` stores the endpoint generation and network-namespace path in a private cache entry keyed by a digest of network name, container ID, and interface name. The cache directory and file operations reject symlinks, replacement races, permissive ownership, and changed generations.

This cache is not the authoritative network database. `mknetd` owns the durable endpoint record and the host resources. The CNI cache gives the short-lived plugin enough exact identity to issue a safe later `CHECK` or `DEL`.

## `CHECK` must inspect the real network

`CHECK` is not “does my cache file exist?” The caller supplies the same attachment identity and network namespace used for `ADD`. `mk-cni` retrieves the endpoint generation, asks `mknetd` to inspect it, and validates the returned identity.

The backend checks the actual primary state, including:

- host and namespace interfaces are present, up, and use the recorded MTU;
- the TUN has the expected gateway address;
- namespace IP forwarding remains enabled;
- the transit and child routes still match;
- generation-specific firewall rules exist;
- return traffic is allowed only in the expected direction; and
- the recorded NAT rule still applies to the child's address.

A durable `READY` record with a missing route is not healthy. `CHECK` returns an error so the caller can treat the attachment as misconfigured.

The first implementation intentionally supports CNI version `1.0.0` and the core `VERSION`, `ADD`, `CHECK`, and `DEL` surface. The current upstream CNI specification also defines newer operations such as `GC` and `STATUS`; those are not implemented by this plugin yet and should remain explicit future work. The caller-side `prevResult` behavior used by standard `CHECK` and chained-plugin execution also needs to be validated as part of the eventual integration rather than inferred from the private generation cache.

## `DEL` must work after the namespace disappears

Cleanup is where networking integrations frequently leak resources. The CNI specification makes `DEL` repeatable and best effort. `CNI_NETNS` may be empty because the caller can lose or remove the namespace before retrying teardown.

`mk-cni` therefore uses its cached generation and asks `mknetd` to delete the exact endpoint. A live endpoint still bound to a sandbox generation cannot be deleted; the runtime must first stop the packet pump and unbind it.

`mknetd` persists `DELETING` before removing external state. It then removes NAT and firewall rules, the route, veth, any runtime-owned namespace, and finally the durable record. Repeating `DEL` after the endpoint is gone succeeds. If the service crashes halfway through, startup reconciliation sees `DELETING` and continues cleanup instead of presenting the partial endpoint as ready.

An `ADD` failure follows the reverse rule. If some interfaces were created but the final state could not be recorded, `mknetd` runs bounded rollback. If `mk-cni` receives a response that fails validation or cannot safely publish its generation cache, it sends a generation-qualified `DEL` before returning the error.

## Who owns which part

The cleanest way to understand the design is to assign every object one owner:

| Layer | Responsibilities |
|---|---|
| CNI caller | Create the primary network namespace, select configuration, invoke plugins, preserve results, order lifecycle calls, and eventually remove the namespace. |
| `mk-cni` | Implement the CNI executable protocol, validate inputs/results, translate `ADD`/`CHECK`/`DEL`, and cache only the exact endpoint generation. |
| `mknetd` | Allocate addresses, journal endpoint state, create/check/delete primary interfaces, routes, forwarding, firewall and NAT, and transfer the TUN descriptor. |
| Runtime shim | Bind the endpoint to the sandbox generation, pump bounded packets, report counters, reconnect safely, and release the binding during task teardown. |
| `mk-agent` | Configure the child TUN, address, route, MTU, and DNS; exchange packets with the shim; close the child endpoint during shutdown. |
| Primary kernel | Continue owning the physical NIC, external route, network namespaces, firewall, and NAT. |
| Child kernel | Own only its virtual network interface and workload-side network stack. |

The most important boundary is that CNI prepares the primary-side attachment, while the Multikernel runtime transports that attachment into another kernel. The CNI caller should not move the physical NIC, program the child directly, or know how inter-kernel packets are carried. The child should not manipulate primary namespaces, firewall rules, or GCE routing.

## What still needs to be proved

The static packet path has already passed outbound DNS and HTTP tests with two isolated children. The CNI implementation adds the normal executable contract and extensive local tests, but the complete gate requires current-revision live evidence on a disposable qualified host.

That live matrix should include:

- CNI `ADD`, immediate `CHECK`, workload traffic, `DEL`, and repeated `DEL`;
- two attachments with overlapping internal interface names but distinct identities;
- failures after every interface, route, firewall, cache, bind, and descriptor-transfer boundary;
- service, shim, relay, and child restart or disconnect;
- MTU boundaries, sustained traffic, backpressure, and counter monotonicity;
- rejection of cross-sandbox routes and source spoofing; and
- a final inventory proving no namespace, link, route, rule, descriptor, or address allocation leaked.

CNI does not remove the unusual part of Multikernel networking. It gives that unusual data plane the beginning of a conventional lifecycle boundary. The caller asks for an attachment using a standard protocol; the primary builds and owns the external network; and the runtime carries only bounded IP packets into a generation-bound virtual interface in the child. The remaining work is to prove that this cross-kernel indirection satisfies the result, namespace, chaining, and cleanup expectations of a real CNI caller.

## References

- [Container Network Interface specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- [Multikernel Linux experiment and runtime](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt)
- [`mk-cni` implementation](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/cmd/mk-cni/main.go)
- [`mknetd` network service](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/internal/network/service.go)
- [Primary Linux network backend](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/runtime/internal/network/backend_linux.go)
- [Mediated networking plan](https://github.com/hairizuanbinnoorazman/multikernel-linux-expt/blob/main/docs/runtime/plans/05-networking.md)
- [Networking Containers in Multikernel Linux Child Kernels]({{< ref "20260831_networkingMultikernelLinuxContainers.md" >}})

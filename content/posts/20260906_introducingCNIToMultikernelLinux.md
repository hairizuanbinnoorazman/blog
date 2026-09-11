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

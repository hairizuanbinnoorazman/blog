+++
title = "Serving Gemma Across Two Nodes with vLLM and LeaderWorkerSet, on CPU"
description = "Splitting a Gemma 3 model across two Graviton (arm64) nodes on EKS with vLLM pipeline parallelism and LeaderWorkerSet: the minimum instance types, the exact settings, the four things that broke, a chat UI on the same load balancer, monitoring, and proof that one request really uses both nodes."
tags = [
    "vllm",
    "kubernetes",
    "llm",
    "gemma",
    "leaderworkerset",
    "arm64",
    "observability",
    "aws",
    "eks",
    "graviton",
]
date = "2026-10-28"
categories = [
    "ai",
]
+++

I wanted to try two things at once: Kubernetes' `LeaderWorkerSet` (LWS), the API for running a group of pods as one unit, and vLLM's multi-node serving. The cheapest way to exercise both is not a GPU cluster. It is two small CPU nodes, one small model, and a deliberate decision to split that model across the nodes even though it fits on one.

That last part deserves saying plainly: **splitting a 1B-parameter model across two machines makes it slower, not faster.** Nothing about this setup is a serving design. It is a way to learn how the pieces behave: how the group is scheduled, how the ranks find each other, what happens when one pod dies, and what you can observe. If you want to serve a model too big for one node, the same mechanics apply, and now you know where the sharp edges are.

This post covers the whole thing: the layout, every vLLM setting and why it is there, the four failures that cost me most of the time, a small chat UI on the same load balancer, monitoring, and a measurement that proves a request really crosses both nodes.

## The Shape of It

```text
                         internal ALB (Application Load Balancer)
  browser / curl ──────────────┬───────────────────────────────┐
                               │ /chat                          │ /  (model API, needs key)
                               ▼                                ▼
                       ┌──────────────┐               ┌─────────────────┐
                       │ chat-app pod │  cluster IP   │ vllm-leader svc │
                       │ password +   │ ────────────► │ (leader only)   │
                       │ adds the key │               └────────┬────────┘
                       └──────────────┘                        │
                                              ┌────────────────┴───────────────┐
                                              ▼                                ▼
                                  ┌──────────────────────┐        ┌──────────────────────┐
                                  │ leader pod, node A   │ gloo   │ worker pod, node B   │
                                  │ API server :8000     │◄──────►│ headless, no HTTP    │
                                  │ pipeline stage 1     │        │ pipeline stage 2     │
                                  └──────────────────────┘        └──────────────────────┘
                                         one LeaderWorkerSet group (size 2)
```

- Two `m7g.2xlarge` nodes (Graviton3, arm64, 8 vCPU and 32 GiB each) in the same Availability Zone, in an Amazon EKS 1.36 cluster.
- One LWS replica = one group = a **leader** pod and a **worker** pod on different nodes.
- vLLM runs as one logical engine across both pods using **pipeline parallelism**: the first half of the model's layers on the leader, the second half on the worker.
- Only the leader serves HTTP. The worker is `--headless`.
- One internal Application Load Balancer, created by the AWS Load Balancer Controller from a single Ingress, with two paths: the model API at `/` and a chat UI at `/chat`.

## What Hardware You Need, at Minimum

vLLM's CPU backend is picky about instruction sets, and "any CPU instance" will not do. What the vLLM CPU docs say:

- **x86:** `avx512f` is recommended; with only AVX2 you get a limited feature set. AMD needs Zen 4 or newer to have AVX-512 at all.
- **arm64:** NEON is required, and **bf16 needs ARMv8.6-A or newer**, which the docs illustrate with Graviton3/4.
- **Data types:** FP32, FP16 and BF16 on both. The docs recommend setting `--dtype=bfloat16` explicitly because FP16 is unstable in torch on CPU.
- **Quantization:** AWQ and GPTQ are listed for x86 (not arm64), and INT8 W8A8 for x86 only. On arm64 you should plan on plain bf16.

My mapping of that onto EC2 instance families (the mapping is mine; check the CPU flags with `lscpu` on your own instance):

| Instance family | CPU | Meets the minimum? |
|---|---|---|
| `m7g` / `c7g` / `r7g` | Graviton3 | **Yes, this is what I used.** The vLLM docs name Graviton3/4 as bf16-capable |
| `m8g` / `c8g` / `r8g` | Graviton4 | Yes. More memory bandwidth should help decode, which is bandwidth-bound; I did not measure it |
| `m6g` / `c6g` | Graviton2 (ARMv8.2-A) | No bf16 |
| `m7i` / `c7i` / `r7i` | Intel Sapphire Rapids (AVX-512, bf16, AMX) | Yes, x86 equivalent. Use the `x86_64` image tag |
| `m7a` / `c7a` | AMD Zen 4 | Yes for AVX-512 |
| `m5a` / `m6a` and other pre-Zen 4 AMD | no AVX-512 | No |

On sizing, the honest answer is that I only tested one shape:

- **Tested: `m7g.2xlarge`** (8 vCPU, 32 GiB), two nodes. Each pod requested 6 vCPU and 20 GiB (requests equal to limits) and actually used about **10–11 GiB** of memory and 0.5–0.8 vCPU on average. That left room for the node-level DaemonSets.
- **Untested but plausible:** a 16 GiB node (`m7g.xlarge`) looks tight on memory with an 11 GiB working set plus the OS and agents, and the 6 vCPU request would not fit on 4 vCPU. You would lower the requests and the KV cache budget. I did not try it.
- **Decode speed is memory-bandwidth-bound**, so a bigger instance in the same family does not generate tokens faster by itself. More vCPUs help prefill.
- Use **two nodes in one Availability Zone**: the pipeline hop is on the critical path of every token, and you avoid cross-AZ data transfer charges.
- Use **On-Demand**. A Spot interruption restarts the whole LWS group, which makes failure experiments hard to read.
- Give each node a generous root volume (I used 100 GiB). The CPU image is several GB and the weights are cached in the pod.

## The Cluster on EKS

`kubectl` cannot create a cluster, and you do not need `eksctl`. Plain `aws eks` calls are enough. IDs below are placeholders:

```bash
aws eks create-cluster --name vllm-research --kubernetes-version 1.36 \
  --role-arn <cluster-role-arn> \
  --resources-vpc-config <your network settings>,endpointPublicAccess=false,endpointPrivateAccess=true \
  --access-config authenticationMode=API,bootstrapClusterCreatorAdminPermissions=true
aws eks wait cluster-active --name vllm-research

aws eks create-nodegroup --cluster-name vllm-research --nodegroup-name llm-arm \
  --node-role <node-role-arn> --subnets <one subnet, so both nodes share a zone> \
  --ami-type AL2023_ARM_64_STANDARD --instance-types m7g.2xlarge \
  --capacity-type ON_DEMAND --disk-size 100 \
  --scaling-config minSize=2,maxSize=2,desiredSize=2
aws eks wait nodegroup-active --cluster-name vllm-research --nodegroup-name llm-arm

for a in eks-pod-identity-agent metrics-server; do
  aws eks create-addon --cluster-name vllm-research --addon-name $a --resolve-conflicts OVERWRITE
done
aws eks update-kubeconfig --name vllm-research --alias vllm-research
```

Notes from doing this:

- I kept the API endpoint private-only (`endpointPublicAccess=false`), so `kubectl` has to run from somewhere that can reach the private endpoint.
- **Match your client:** my `kubectl` was 1.33 against a 1.36 server, outside the supported one-minor-version skew. Upgrade it.
- `create-cluster` installs vpc-cni, CoreDNS and kube-proxy by default; I only added the two managed add-ons that need nodes.
- The managed node group is single-AZ on purpose, so both nodes share a zone.
- **Pod Identity, not IRSA**, for the load balancer controller: `aws eks create-pod-identity-association --service-account aws-load-balancer-controller --role-arn <controller-role-arn>`. The role's trust policy trusted `pods.eks.amazonaws.com` with no cluster condition, so an existing role could be reused.
- **Tags on a managed node group do not propagate to the EC2 instances** unless they come from a launch template. I tagged the instances, their volumes and ENIs directly with `ec2 create-tags` (and wrote the script to do it).
- The nodes pull images anonymously from public registries (Docker Hub, quay.io, registry.k8s.io); the cluster add-ons come from Amazon's ECR. Anonymous Docker Hub pulls are rate-limited per source IP address, which is worth knowing if many nodes share one. A restart reuses the node's cached image (`IfNotPresent`).
- The model weights are downloaded from Hugging Face on every start (an `emptyDir` cache), so restarts also depend on that outbound path.

## Why Gemma 3 1B, and Why Pipeline Parallelism

The model's `config.json` makes the choice for you:

```text
architectures:        Gemma3ForCausalLM
num_hidden_layers:    26
num_attention_heads:  4
num_key_value_heads:  1
torch_dtype:          bfloat16
```

Twenty-six layers split cleanly into 13 + 13. Four attention heads and a **single KV head** make tensor parallelism awkward: with one KV head there is nothing to shard, so each tensor-parallel rank would replicate it. Pipeline parallelism splits by whole layers, has no such constraint, and also happens to be what vLLM recommends *across* nodes (tensor parallelism is for devices joined by a fast interconnect, inside a node).

A quick refresher on the options:

| Type | What is split | Good for | Cost |
|---|---|---|---|
| Tensor parallel | each layer's matrices | lower latency, pooled memory | needs a fast interconnect; syncs every layer |
| Pipeline parallel | groups of whole layers | models too big for one node | one request is not faster; stages run in sequence |
| Data parallel | nothing; full copy per replica | throughput and availability | memory for a full copy each |

For this experiment I used pipeline parallelism with a pipeline size of 2 and tensor parallelism of 1.

## What LeaderWorkerSet Gives You

A plain `Deployment` treats pods as interchangeable. A multi-node inference engine is the opposite: the pods are *roles* in one engine, and a lone survivor is useless. LWS models exactly that:

- A **group** is one leader and N−1 workers, created, scaled and updated together.
- It injects `LWS_LEADER_ADDRESS`, `LWS_GROUP_SIZE` and `LWS_WORKER_INDEX` into every pod, so the same container args work for both roles.
- `restartPolicy: RecreateGroupOnPodRestart` recreates the **entire group** if any pod dies.
- The leader gets a stable DNS name, which is what vLLM's distributed process group connects to.

Installing it is one Helm command, with no cert-manager requirement:

```bash
helm install lws oci://registry.k8s.io/lws/charts/lws \
  --version 1.0.0 -n lws-system --create-namespace --wait
```

## The vLLM Settings, One by One

Here is the full manifest, then the reasoning. The image is vLLM's CPU build for arm64, **pinned** (more on why below):

```yaml
apiVersion: leaderworkerset.x-k8s.io/v1
kind: LeaderWorkerSet
metadata:
  name: vllm-gemma
  namespace: vllm
spec:
  replicas: 1
  leaderWorkerTemplate:
    size: 2
    restartPolicy: RecreateGroupOnPodRestart
    leaderTemplate:
      metadata:
        labels: { app: vllm-gemma, role: leader }
      spec:
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - topologyKey: kubernetes.io/hostname
                labelSelector: { matchLabels: { app: vllm-gemma } }
        containers:
          - name: vllm
            image: vllm/vllm-openai-cpu:v0.31.0-arm64
            args:
              - google/gemma-3-1b-it
              - --dtype=bfloat16
              - --max-model-len=4096
              - --pipeline-parallel-size=2
              - --tensor-parallel-size=1
              - -cc.mode=2
              - -cc.backend=eager
              - --no-async-scheduling
              - --nnodes=2
              - --node-rank=0
              - --master-addr=$(LWS_LEADER_ADDRESS)
              - --port=8000
            env:
              - { name: HF_TOKEN, valueFrom: { secretKeyRef: { name: hf-token, key: token } } }
              - { name: VLLM_API_KEY, valueFrom: { secretKeyRef: { name: vllm-api-key, key: key } } }
              - { name: VLLM_CPU_KVCACHE_SPACE, value: "4" }
              - { name: VLLM_HOST_IP, valueFrom: { fieldRef: { fieldPath: status.podIP } } }
            ports: [{ name: http, containerPort: 8000 }]
            resources:
              requests: { cpu: "6", memory: 20Gi }
              limits:   { cpu: "6", memory: 20Gi }
            securityContext: { capabilities: { add: [SYS_NICE] } }
            volumeMounts: [{ name: shm, mountPath: /dev/shm }]
            startupProbe:
              httpGet: { path: /health, port: http }
              periodSeconds: 10
              failureThreshold: 90
            readinessProbe:
              httpGet: { path: /health, port: http }
        volumes: [{ name: shm, emptyDir: { medium: Memory, sizeLimit: 4Gi } }]
    workerTemplate:
      # identical image, env (minus the API key), resources, affinity and volumes, except:
      #   --node-rank=$(LWS_WORKER_INDEX)   instead of 0
      #   --headless                        instead of --port=8000
      #   no ports, no probes
      metadata:
        labels: { app: vllm-gemma, role: worker }
```

### The flags

| Setting | Why |
|---|---|
| `google/gemma-3-1b-it` | The container entrypoint is already `vllm serve`, so the first arg is the model. The model is gated: you need a token from an account that accepted the licence. |
| `--dtype=bfloat16` | The CPU build's docs recommend setting it explicitly, because float16 is unstable in torch on CPU. Needs a CPU with bf16 support (see the hardware section). |
| `--max-model-len=4096` | Caps the KV cache budget per sequence. |
| `--pipeline-parallel-size=2` `--tensor-parallel-size=1` | Two pipeline stages, no tensor sharding (see above). |
| `--nnodes=2` | Total nodes in the process group. |
| `--node-rank` | `0` on the leader, `$(LWS_WORKER_INDEX)` (which is `1`) on the worker. |
| `--master-addr=$(LWS_LEADER_ADDRESS)` | The leader's stable DNS name. The ranks rendezvous on it over `gloo` on port 29501. |
| `--headless` | Worker only: run the engine but no API server. |
| `-cc.mode=2 -cc.backend=eager` | **The setting that took longest to find.** Dynamo traces the model once and runs it eagerly, with no Inductor-generated C++. See the failures section. |
| `--no-async-scheduling` | Kept while debugging. I never proved it is required; it did not fix anything by itself. |

### The environment and pod settings

| Setting | Why |
|---|---|
| `VLLM_CPU_KVCACHE_SPACE=4` | KV cache size in GiB. With 4 GiB the engine reported room for **291,777 tokens**. |
| `VLLM_HOST_IP` from `status.podIP` | Makes each rank advertise its pod IP for the distributed group. A wrong interface here is the classic multi-node hang. |
| `/dev/shm` as a 4Gi memory `emptyDir` | The default container shared memory is far too small for the engine's IPC. |
| capability `SYS_NICE` | vLLM's CPU backend does NUMA-related work and warns without it. |
| 6 vCPU and 20 Gi, requests equal to limits | Guaranteed QoS, and it leaves about 2 vCPU on an 8-vCPU node for kubelet, the CNI and monitoring agents. Actual use was about 10 GiB per pod. |
| required pod anti-affinity on hostname | **This is what makes the split real.** Without it the scheduler can put both pods on one node. |
| `startupProbe` allowing 15 minutes | First start downloads the weights and warms up. Readiness on `/health` takes about 100 seconds in practice. |
| `HF_TOKEN`, `VLLM_API_KEY` from Secrets | Never in the manifest. `--api-key` protects `/v1/*`; `/health` and `/metrics` stay open. |

One more setting that is *not* in the manifest: the NUMA rule. vLLM's CPU backend binds each local pipeline or tensor rank to its own NUMA node. An `m7g.2xlarge` has exactly one, so you cannot run two pipeline ranks in one pod. One rank per node, which is exactly the multi-node layout, is the only configuration that works on these machines.

## Four Things That Broke

I spent most of the effort here. In order:

### 1. A newer image was broken for this use

I started on the newest CPU image. The model loaded, the server reported healthy, and the **first request** crashed the engine with an assertion in a CPU shim for a Triton kernel (`compute_slot_mapping`). It happened with or without pipeline parallelism. Pinning the previous release fixed it.

Lesson: pin the tag, and run one real request before you trust a version. A healthy `/health` proves nothing about the forward pass.

### 2. The compiler crashed

With the working image, the Gemma pods died during warm-up with a **gcc internal compiler error** ("during GIMPLE pass"). vLLM's CPU path uses `torch.compile` with Inductor, which generates C++ and compiles it. For Gemma's graph on arm64, that compiler crashed. The obvious workaround is `--enforce-eager`.

### 3. The obvious workaround broke the pipeline

With `--enforce-eager`, both ranks started, the weights loaded, health was green, and the first request killed the engine on the leader:

```text
KeyError: 'chatcmpl-...'
  in scheduler.update_from_output: model_runner_output.req_id_to_index[req_id]
```

The leader had received a model output that did not contain the request it had just scheduled. That error was identical on two vLLM versions and with async scheduling off, which is why I stopped guessing and had another reviewer read the vLLM source.

The real cause was on the **worker**, and I had never looked at its logs, because LWS recreates the whole group after a failure and erases them:

- On the CPU backend, `--enforce-eager` means the model's warm-up pass is skipped.
- The warm-up (really a dummy forward pass) is the **only place** the second pipeline rank allocates its `intermediate_tensors` buffer.
- So rank 1's first real forward pass hit an assertion, the failed future was never checked, and the leader read an empty output, which surfaced as the `KeyError`.

The fix is to keep the warm-up but avoid Inductor: `-cc.mode=2 -cc.backend=eager`. After that, the first request returned a correct answer.

Lesson: when a distributed engine fails on one rank, the error you see is usually on a different rank. Make sure the *other* pod's logs survive the restart.

### 4. The model is gated

The download returned a 403 `GatedRepo` ("you are not in the authorized list"). The token was valid; the licence had never been accepted on that account. A human has to click that. After it was accepted, the same token worked.

## Proving That One Request Uses Both Nodes

"Both pods are Running" is not proof that a request crosses nodes. So I measured. A small script reads each pod's cgroup CPU counter and its `eth0` byte counters with `kubectl exec`, over a 20-second idle window and then across one request:

```bash
snap() {  # pod -> "cpu_usec rx_bytes tx_bytes"
  kubectl -n vllm exec "$1" -c vllm -- bash -c \
    'u=$(awk "/^usage_usec/{print \$2}" /sys/fs/cgroup/cpu.stat); r=$(awk "/eth0:/{print \$2, \$10}" /proc/net/dev); echo "$u $r"'
}
```

Result for one request of 146 completion tokens that took 12 seconds:

| Pod | Idle 20 s: CPU | Idle: network in / out | During the request: CPU | Network in | Network out |
|---|---|---|---|---|---|
| leader (node A) | 85 ms | 4 KB / 60 KB | **24.8 s** | 296 KB | **1,371 KB** |
| worker (node B) | 66 ms | **0 / 0** | **27.1 s** | **1,311 KB** | 293 KB |

- The worker does nothing and sends nothing when idle, then does about 27 CPU-seconds of work during one request. It is not a standby copy.
- The traffic matches in both directions: the leader sent about 1.37 MB and the worker received about 1.31 MB; the worker sent about 0.29 MB and the leader received about 0.30 MB.
- The two pods are on different nodes with different pod IPs, so that traffic crossed the network between machines.

This is evidence of pod-to-pod traffic, not a packet trace of individual tensors. The failures above are further indirect proof: the worker's failure was what broke the request.

## Exposing It: One Load Balancer, Two Paths

The model API goes behind a `Service` that selects **only the leader** (`role: leader`), then an Ingress that the AWS Load Balancer Controller turns into an internal Application Load Balancer. I then wanted a chat UI on the same ALB, at `/chat`. Four details mattered:

1. **Rules are ordered.** `/chat` has to come before the catch-all `/`, or `/` swallows everything.
2. **The balancer does not rewrite paths.** A request for `/chat/` reaches the app as `/chat/`. The app has to serve under its own prefix and use **relative** URLs in the page (`fetch('api/chat')`, not `fetch('/api/chat')`).
3. **Health checks are per backend.** The Ingress-wide check was `/health`, which the chat app does not have. A per-Service annotation overrides it for that target group, and the chat app answers `/healthz` without authentication.
4. **Raise the ALB idle timeout.** The default is 60 seconds. CPU prefill on a long prompt can be slower than that, which would end the request with a 504. I set 300 seconds. Streaming responses start immediately regardless.

The Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vllm-gemma
  namespace: vllm
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip              # straight to the leader pod IP
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          # order matters: the specific rule first, the catch-all second
          - { path: /chat, pathType: Prefix, backend: { service: { name: chat-app,    port: { number: 8080 } } } }
          - { path: /,     pathType: Prefix, backend: { service: { name: vllm-leader, port: { number: 8000 } } } }
```

The chat Service then carries its own `alb.ingress.kubernetes.io/healthcheck-path: /healthz` annotation, which overrides the `/health` check for that target group only.

## The Chat App

It is one Python file using only the standard library. It serves a small page and proxies `/api/chat` to the vLLM API, relaying the server-sent events as they arrive:

```python
with urllib.request.urlopen(upstream_request("/v1/chat/completions", payload),
                            timeout=UPSTREAM_TIMEOUT_S) as resp:
    self.send_response(200)
    self.send_header("Content-Type", "text/event-stream")
    self.send_header("Cache-Control", "no-cache")
    self.end_headers()
    for line in resp:               # SSE lines, relayed as they arrive
        self.wfile.write(line)
        self.wfile.flush()
```

Because the app attaches the API key on the server side, **it is a way to use the model without the key**. Anyone who can reach `/chat` effectively bypasses the key. So it has its own shared password (HTTP Basic, any username, constant-time comparison), with only the health check exempt:

```python
def password_ok(header: str) -> bool:
    expected = SETTINGS["password"]
    if not expected:
        return True
    if not header.startswith("Basic "):
        return False
    supplied = base64.b64decode(header[6:]).decode().partition(":")[2]
    return hmac.compare_digest(supplied.encode(), expected.encode())
```

### Getting the code into the cluster without building an image

I did not want an image build and a registry for one file. The source goes in as a ConfigMap and is mounted into a stock `python:3.12-slim` container:

```bash
kubectl -n vllm create configmap chat-app-src --from-file=chat_app.py --dry-run=client -o yaml | kubectl apply -f -
# the Deployment mounts it at /app and runs: python -I /app/chat_app.py
```

This is fine for a single stdlib-only file (ConfigMaps are capped at about 1 MiB, and there are no dependencies to install). Anything larger deserves a real image. The pod does not notice ConfigMap edits on its own, so the deploy script does a rollout restart.

### A bug I shipped

The first version was unreadable in dark mode: light text on light bubbles. The cause was CSS order. I had put the `prefers-color-scheme: dark` overrides *above* the base bubble rules, and at equal specificity the later rule wins. Moving the dark block to the end fixed it. I checked it properly by emulating dark mode in a browser and reading the computed colours, rather than trusting my reading of the stylesheet a second time.

## Monitoring

I ran Prometheus (via the Prometheus Operator), Grafana, and a log shipper in the same cluster.

- A `PodMonitor` selects `role: leader` and scrapes `/metrics` every 15 seconds. **The worker has no `/metrics`**: it has no API server. Its health is only visible through pod-level CPU, memory and network metrics, and its logs.
- The vLLM metrics I put on the dashboard (Prometheus appends `_total` to counters):

| Panel | Metric |
|---|---|
| Requests running / waiting | `vllm:num_requests_running`, `vllm:num_requests_waiting` |
| KV cache usage | `vllm:kv_cache_usage_perc` |
| Tokens per second | `rate(vllm:prompt_tokens_total)`, `rate(vllm:generation_tokens_total)` |
| Time to first token, inter-token latency, end-to-end | `histogram_quantile` over `vllm:time_to_first_token_seconds`, `vllm:inter_token_latency_seconds`, `vllm:e2e_request_latency_seconds` |
| Prefix cache hit rate | `vllm:prefix_cache_hits_total` / `vllm:prefix_cache_queries_total` |
| CPU, throttling, memory per pod | `container_cpu_usage_seconds_total`, `container_cpu_cfs_throttled_periods_total`, `container_memory_working_set_bytes` |
| Node-to-node traffic | `node_network_transmit_bytes_total` |

- One panel was blank until I checked: I had assumed the network interface was named `eth0`. On these instances it is `ens5` (and a second `ens6` appears with the CNI). Match with a regex (`ens.*|eth.*`) rather than a literal name.
- Ship the logs somewhere central. This is not optional with LWS: the group restart erases the failed pod's logs, and the worker's log was exactly the evidence I needed in failure 3.
- If your log shipper uses the River/Alloy syntax, remember that block attributes must each be on their own line. My one-line `rule { ... }` blocks crashed the pod until I reformatted them.

## What LWS Did

- **Bring-up:** two pods created together, on different nodes, with the three environment variables injected and a stable DNS name for the leader.
- **All-or-nothing restart:** I deleted **only the worker**. LWS recreated the **leader** as well (its pod UID changed), and the endpoint was answering again **113 seconds** later. A `Deployment` would have left the leader running with a dead peer.
- **Template edits roll the whole group.** With one group and no spare capacity, every manifest change is an outage. Rolling updates with a surge need spare nodes.

## The Numbers

Indicative, one group, light load:

| Metric | Value |
|---|---|
| Single streamed request | 86 tokens in 6.9 s, about **12 tokens/s** |
| Chat UI | time to first token 0.2 s, about 12.8 chunks/s |
| Three concurrent requests | time to first token p95 about 2.0 s, inter-token latency p50 about 87 ms |
| Start to ready | about 100 s (the weights download took about 8 s) |
| KV cache | 291,777 tokens with a 4 GiB budget |
| Footprint | about 10–11 GiB per pod; 0.5–0.8 vCPU average; CPU throttling 2–3% |

About 12 tokens/s is in the range I expected for a 1B model on this class of CPU. It says nothing about larger models, and the split costs speed rather than adding it: a single replica would likely be at least as fast.

## What I Would Do Differently

- **Capture the worker logs first.** Ship them centrally *before* the first failure.
- **Run one real request in CI for every image bump.** Two of my four failures were "healthy but broken on the first request".
- **Use TLS.** I used plain HTTP on a private network; the key and the chat password cross it in clear text.
- **Scale with data parallelism, not splitting.** If the goal were throughput, an LWS with `size: 1` and `replicas: 2` is simpler and faster for a model this small. I wrote that as a fallback manifest and did not need it.
- **Tag the instances properly.** Use a launch template with tag specifications so nodes that get replaced keep their tags.
- **Try the rest of the LWS behaviour.** I did not run rolling updates with a surge, scaling the number of groups, autoscaling on queue depth, or compare the split against a single replica.

## Summary of the Settings That Matter

If you only take away a few lines:

```text
nodes:      2 x m7g.2xlarge (Graviton3+, bf16), same AZ, On-Demand   # x86: Sapphire Rapids m7i/c7i, x86_64 image
image:      vllm/vllm-openai-cpu:v<pinned>-arm64        # pin it; test one real request
parallel:   --pipeline-parallel-size=2 --tensor-parallel-size=1   # one rank per node
distrib:    --nnodes=2 --node-rank=<0|1> --master-addr=$(LWS_LEADER_ADDRESS) [--headless on the worker]
compile:    -cc.mode=2 -cc.backend=eager                # NOT --enforce-eager (breaks pipeline ranks)
memory:     VLLM_CPU_KVCACHE_SPACE=4, /dev/shm as a memory emptyDir, requests == limits
network:    VLLM_HOST_IP=<pod IP>, required anti-affinity so the pods land on different nodes
LWS:        size: 2, restartPolicy: RecreateGroupOnPodRestart
```

It works, it is observable, and now the failure modes are known. Next time I will point the same recipe at a model that does not fit on one node.

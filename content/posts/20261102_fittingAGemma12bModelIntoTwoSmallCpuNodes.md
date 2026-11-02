+++
title = "Fitting a 12B Model into Two Small CPU Nodes: Gemma 4 on Graviton with vLLM"
description = "A real large model on small hardware: Gemma 4 12B split across two 32 GB Graviton nodes with vLLM pipeline parallelism. Why it cannot fit on one node, where the memory really goes, the vLLM memory check that refuses to start, why the context ends up at 2,048 tokens, how fast it runs (about 4 tokens per second), and why my own speed estimate was off by almost 3x."
tags = [
    "vllm",
    "kubernetes",
    "llm",
    "gemma",
    "memory",
    "performance",
    "arm64",
    "graviton",
    "eks",
    "leaderworkerset",
]
date = "2026-11-02"
categories = [
    "ai",
]
+++

In the [last post]({{< ref "20261101_dontSplitASmallModelOnePodVersusTwoOnCpu.md" >}}) I argued that you should not split a model that fits on one machine: the 1B model I benchmarked was faster, steadier and cheaper in a single pod. The flip side of that argument is the case where splitting is not a choice. When the weights do not fit, pipeline parallelism is how you run the model at all.

So I tried it with a model that actually needs it: **Gemma 4 12B**, on the same two small Graviton nodes from [the first post]({{< ref "20261028_servingGemmaAcrossTwoNodesWithVllmAndLeaderWorkerSet.md" >}}). It works. It also taught me several things the 1B never could, mostly about memory, and it corrected a performance estimate I had given with more confidence than it deserved.

## The Short Version

| | Gemma 4 12B on 2 × `m7g.2xlarge` |
|---|---|
| Checkpoint size | 23.9 GB (22.3 GiB) in bf16 |
| Why it needs two nodes | one node has 29.8 GiB usable and the pod needs about 30 GiB |
| Streaming speed, one user | **about 4.0 tokens/s** (241 ms between tokens) |
| Time to first token (short prompt) | about 2.1 s |
| Context window | **2,048 tokens** (the result of the memory squeeze, not a model limit) |
| Real memory per pod | about 20 GiB of a 26 GiB limit |
| Time from pod start to serving | about 6 minutes |

The model is clever enough to be fun and slow enough to notice, and the setup is held together by one explicit memory setting that took a failed start to find.

## Does It Fit? The Arithmetic

The nodes are `m7g.2xlarge`: 8 vCPU and 32 GB, of which Kubernetes lets pods have 29.8 GiB after system reservations. The model's weights are 22.3 GiB.

On a single node that looks like it should just fit, with 7 GiB to spare. It does not, because the weights are only part of what a vLLM pod uses. From the 1B model I knew a pod carries several GiB of runtime overhead on top of the weights and the KV cache. At 12B that overhead turned out to be even larger (below). So one node is out: 22.3 GiB of weights plus roughly 8 GiB of overhead exceeds what the node can give.

Split in two, each pod holds about 11 GiB of weights. That is the point of pipeline parallelism: each node keeps half the layers, 24 of the model's 48.

I should be clear about what I did and did not verify. The even split of the weights is my arithmetic; I did not measure how many bytes each pod holds. The real total memory per pod I did measure, and that is where it gets interesting.

## What Makes This Model Different from the 1B

The 12B is a different kind of model from the 1B in ways that mattered to the deployment:

- **It is multimodal.** The architecture is `Gemma4UnifiedForConditionalGeneration`, with vision and audio parts alongside the text model. The 1B was text-only. vLLM v0.31.0 does register this class, but registered is not the same as proven on Arm CPU. I wanted text only, so I turned the other inputs off (`--limit-mm-per-prompt` set to zero for image, audio and video), which should keep vLLM from profiling or loading those parts. I did not measure how much memory that saved.
- **Its attention layout is cheap on memory.** Of its 48 layers, roughly five in six use a sliding window of 1,024 tokens, and the rest use full attention with a very narrow cache (a single KV head). That is why its KV cache per token is small, which turns out to be the only reason the 2,048-token context is possible at all.
- **It is gated.** The Hugging Face licence has to be accepted on the account whose token you use. I had accepted it only for the 1B, so I checked this repo's access before deploying instead of finding out partway through a 24 GB download.

## The Setup

It is the same `LeaderWorkerSet` as before: one group of two pods, a leader that serves the API and a headless worker, forced onto different nodes, with vLLM's `--pipeline-parallel-size=2`. I started from the working 1B manifest and changed what the bigger model demanded:

```text
model:      google/gemma-4-12B-it
memory:     26 GiB per pod, requests = limits         (was 20 GiB)
startup:    probe allows 30 minutes                   (was 15; the checkpoint is 24 GB)
inputs:     --limit-mm-per-prompt={"image":0,"audio":0,"video":0}
KV cache:   --kv-cache-memory-bytes=400000000         (was VLLM_CPU_KVCACHE_SPACE=4)
context:    --max-model-len=2048                      (was 4096)
unchanged:  --pipeline-parallel-size=2 --nnodes=2 --node-rank=<0|1> --master-addr=<leader>
            -cc.mode=2 -cc.backend=eager --no-async-scheduling --dtype=bfloat16
            image pinned to v0.31.0 (the previous post explains why)
```

The last two changes in that list, the explicit KV cache and the shorter context, are the interesting part of the story.

## The Memory Check That Refused to Start

The first start looked healthy. Both ranks joined, the weights downloaded in 162 seconds and loaded in about 90, with no out-of-memory kill. Then the leader died with:

```text
ValueError: Available memory on node 0 (0.58/26.0 GiB) on kv cache allocation
is less than requested memory for kv (4.0 GiB).
```

Only 0.58 GiB of a 26 GiB pod was "available" after loading roughly 11 GiB of weights. The worker said 0.97 GiB. That did not add up, so I read vLLM's CPU worker.

The function that reports available memory takes the smaller of two numbers: the host's free memory plus file cache, and the pod's memory limit minus the pod's current usage. The pod's current usage includes **page cache**: the 22 GiB checkpoint had just been written to disk during the download and read back during the load, and every one of those pages is charged to the pod. The log had even hinted at it earlier: "Available RAM: 0.00 GiB" while loading a 22.28 GiB checkpoint.

That cache is reclaimable. The kernel would hand it back the instant a process needed the memory. But vLLM's guard does not know that, and it refuses to proceed before the kernel gets the chance. So the limit it enforces is not "how much memory is free", it is "how much is free *counting the file cache as taken*".

The only way through is to ask for a KV cache small enough to fit in what the guard sees. I replaced the 4 GiB setting with an explicit 400 MB budget (`--kv-cache-memory-bytes`). That cleared the check, and the next failure appeared immediately:

```text
ValueError: To serve at least one request with the model's max seq len (4096),
0.68 GiB KV cache is needed, which is larger than the available KV cache memory
(0.37 GiB). ... the estimated maximum model length is 2048.
```

vLLM tells you what will fit. A 4,096-token context needs 0.68 GiB per pod and I could only give it 0.37, so the context became **2,048 tokens**. With that, the log reports a cache of 2,186 tokens and a maximum concurrency of 1.07 at 2,048 tokens per request. In practice: one conversation at a time, about two thousand tokens in total including the reply.

**Lesson:** a model's context limit is not only a property of the model. On this backend it is also a consequence of how much memory the guard believes is left, and the file cache from loading a big checkpoint eats into that.

### The log trap, again

The first failed attempt cost me a second attempt, for the same reason as in the first post: `LeaderWorkerSet` recreates the whole group when a pod fails, and the failed pod's logs go with it. I saw "Engine core initialization failed" and nothing else. Before the next attempt I streamed both pods' logs to files, and the actual `ValueError` was waiting there. If you run anything on a group controller, ship or stream the logs first.

## Where the Memory Actually Goes

After it started, I measured each pod from inside, splitting what the pod is charged for into real process memory and file cache:

| | Leader | Worker |
|---|---|---|
| Charged to the pod (limit 26.0 GiB) | 25.1 GiB | 25.3 GiB |
| File cache (reclaimable) | 4.7 GiB | 5.7 GiB |
| **Real process memory** | **20.2 GiB** | **19.5 GiB** |

So the pod is not as close to its limit as 25 of 26 GiB suggests. The real figure is about 20 GiB, and the rest is cache the kernel will give back. That leaves about 5.8 GiB of real headroom inside the pod, so it is not about to be killed. It is still tight enough to dictate everything else in this post: the small KV cache and the short context. And on the busiest node, 94 percent of the allocatable memory was already committed in requests, so there is little room for anything else to be scheduled beside it.

The 20 GiB breaks down roughly as 11 GiB of weights, 0.4 GiB of KV cache, and **8 to 8.7 GiB of everything else**. A look at the processes shows part of it: on the leader the API server holds 1.9 GiB and the engine process 1.2 GiB, and the worker process itself is 17.6 to 18.6 GiB resident. The remainder, five or six GiB inside the worker process beyond the weights (activation buffers, runtime allocator arenas and similar), I did not trace further.

The important property is what **splitting does not divide**. Splitting halves the weights. It does not halve the per-pod runtime overhead; each pod pays it in full. On the 1B model that overhead was about 5.7 GiB per pod; on the 12B it is 8 to 8.7 GiB, so it grows with the model, too. This is the quiet reason splitting a model that barely fits gives diminishing returns: the fixed tax per pod stays while you add pods.

## How Fast Is It?

I measured three streamed replies of exactly 100 tokens, from a client through the load balancer:

| Run | Time to first token | Decode speed | Median gap between tokens |
|---|---|---|---|
| 1 | 2.08 s | 4.03 tokens/s | 241 ms |
| 2 | 2.28 s | 4.04 tokens/s | 240 ms |
| 3 | 2.06 s | 4.00 tokens/s | 243 ms |

About 4 tokens per second, and very steady. Each pod used about 3.2 of its 6 CPU cores while decoding, which is the signature of a memory-bound workload: the cores are waiting on memory, not computing.

For scale: the same experiment on the 1B model gave 21 tokens per second in a single pod. The 12B has 12 times the weights and is about 5 times slower, not 12 times.

### My estimate was wrong, and why

Before running it I told myself the 12B would manage about 1.5 tokens per second. It does 4.0. The mistake is instructive. I had taken the 1B's measured rate, worked out an effective memory bandwidth of about 40 GB/s, and scaled up. But the 1B is small enough that **software overhead**, not memory speed, limited it (that is why a single 1B pod only reached 21 tokens/s). It was never actually streaming its weights at full speed.

The 12B is big enough to be genuinely memory-bound, and its numbers imply a much better bandwidth: each token reads the whole model (about 24 GB) in two serial halves, in 241 ms, which works out to very roughly **100 GB/s per node**. That is my back-of-envelope derivation, not a measured bandwidth, and it ignores the small cost of the hop between the pods. But it is directionally enough to say the 40 GB/s I extrapolated from was far too pessimistic, and so were the larger-model figures I gave from it. A 31B on four such nodes should land nearer 1.5 tokens per second than 0.6. That one I have not run.

**Lesson:** do not extrapolate memory-bound speed from a model small enough to be overhead-bound. Measure the biggest one you actually intend to use.

## What Happens When the Infrastructure Moves Under It

The account the cluster lives in runs a scheduled cleanup job that stops instances which have no declared end date. It stopped both nodes overnight, Auto Scaling replaced them with fresh machines, and the pods were rescheduled onto them. When I looked in the morning, the model was serving again, with no restarts on the pods and nothing for me to do.

That is `LeaderWorkerSet` earning its keep: the group came back as a unit. It also shows the price of a 12B model: **every restart is a full reload**. The weights download again into the container's disk (162 seconds each time, from the model hub), then load (about 90 seconds), then warm up (about 50). So any disruption, a node replacement, a template change or a crash, means about six minutes without an answer. For something you want to use, that is the real operational cost of a big model on cheap hardware: not the speed, the cold start.

## The Chat Page Had Its Own Bug

One thing worth admitting because it looked like a model problem. A reply in my little chat page ended mid-sentence, always at exactly 256 chunks, and the page said nothing. The model was fine. My page hard-coded a limit of 256 tokens per reply and ignored the server's `finish_reason: "length"` that says a reply was cut off. The fix was a reply-limit dropdown, a visible "cut off" note, and a New chat button, since a 2,048-token window fills quickly. If a model stops talking at a suspiciously round number, check the client before the model.

## What I Would Do Next

- **Bigger nodes.** `m7g.4xlarge` (64 GB) would give the file cache room to exist without starving the check, and should lift the 2,048-token cap. I expect it, but I have not tried it.
- **Trim the overhead.** Lowering the number of tokens and sequences vLLM sizes its buffers for might claw back some of the 8 GiB per pod. Untested.
- **Three nodes would not help** the context cap. The checkpoint's cache fills whatever limit the pod has, so more splitting gives more real headroom but the guard would still see an almost full pod.
- **Quantization is not an easy way out on this hardware.** vLLM's CPU documentation lists the common 4-bit formats for x86, not for Arm. Check before you plan around it.
- **A mixture-of-experts model** with a similar total size reads far fewer parameters per token, so it should decode noticeably faster. CPU support for it is unproven, and it is the experiment I most want to try.

## Caveats

- **One model, one user.** I measured one user streaming, a few requests, and the memory. I did not benchmark concurrency, long prompts or the prefix cache on the 12B; the 1B results do not transfer automatically.
- **The weight split is arithmetic.** Eleven GiB per pod is half the checkpoint, not a measurement. The embeddings and output head make the two stages uneven by about a GiB either way.
- **The overhead is only partly explained.** I identified roughly 3 GiB of it as helper processes. The rest, I did not trace.
- **The 2,048-token context is a deployment result, not a model limit,** and a different node size or a different amount of overhead would change it.
- **Run counts are small.** The three speed runs agree to within 1%, but they are three runs.

## The Settings That Matter

```text
nodes:     2 x m7g.2xlarge (Graviton3, 29.8 GiB usable each), same AZ, On-Demand
fit:       22.3 GiB of weights + ~8 GiB per-pod overhead does not fit one node; split in two
pods:      LWS size 2, 6 vCPU and 26 GiB each (requests = limits), required anti-affinity
parallel:  --pipeline-parallel-size=2 --tensor-parallel-size=1   (one rank per node)
memory:    --kv-cache-memory-bytes=400000000 --max-model-len=2048
           (vLLM counts the checkpoint's page cache as used; 4 GiB of KV is refused)
inputs:    --limit-mm-per-prompt={"image":0,"audio":0,"video":0}
compile:   -cc.mode=2 -cc.backend=eager                          # NOT --enforce-eager
startup:   probe allows 30 minutes; the weights download on every start
logs:      stream them somewhere before the first failure
```

It runs at about four tokens per second, a conversation at a time, in two thousand tokens of context. That is nowhere near production, and it was never the goal. The goal was to see what a genuinely large model does to a small cluster, and the answer is that it spends your memory in places you do not expect, and it makes you earn every token of context.

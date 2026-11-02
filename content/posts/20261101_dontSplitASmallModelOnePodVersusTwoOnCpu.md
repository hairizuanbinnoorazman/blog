+++
title = "Don't Split a Model That Fits: One Pod vs Two for Gemma on CPU"
description = "I served the same Gemma 3 1B model two ways on Graviton nodes with vLLM: split across two pods with pipeline parallelism, and whole in a single pod. The single pod was faster for one user, steadier under load, cheaper per token and used half the nodes. The numbers, the odd bimodal behaviour of the split, and what splitting is actually for."
tags = [
    "vllm",
    "kubernetes",
    "llm",
    "gemma",
    "performance",
    "benchmarking",
    "arm64",
    "graviton",
    "eks",
    "leaderworkerset",
]
date = "2026-11-01"
categories = [
    "ai",
]
+++

In the [last post]({{< ref "20261028_servingGemmaAcrossTwoNodesWithVllmAndLeaderWorkerSet.md" >}}) I split a 1B-parameter Gemma model across two CPU nodes on purpose, to learn how `LeaderWorkerSet` and vLLM's multi-node mode behave. I said then that splitting a model that fits on one machine makes it slower, and I listed "compare the split against a single replica" among the things I had not done.

This post does that comparison, properly, with a benchmark that runs the same tests against both setups. The result is not subtle:

**If the model fits on one machine, don't split it.** Splitting is a way to fit a model into hardware that is too small for it. It is not a way to make anything faster, and across ordinary network links it makes things slower.

## The Short Version

Same model, same image, same flags, same per-pod resources. Only the layer placement differs.

| | Single pod | Split across 2 pods |
|---|---|---|
| One user streaming a reply | **21.1 tokens/s** | 17.5 tokens/s |
| Gap between tokens, one user | **46 ms** | 55 ms |
| 8 users at once, total output | **92 tokens/s** | 84 tokens/s |
| Time to first token, 3,500-token prompt | 5.97 s | **5.62 s** |
| Another user's stream freezes when a long prompt arrives | **3.4 s** | 5.7 s |
| CPU spent per 1,000 output tokens | **162 s** | 221 s |
| Nodes used | **1** | 2 |

The single pod wins almost everywhere. The split wins in exactly one place, processing a long prompt, by about 6 to 10 percent. And under load the split behaves in a way I could measure but not explain, which is the part of this I find most interesting.

## What I Compared

Both setups ran the same model, `google/gemma-3-1b-it` in bf16, on the same two Graviton3 (`m7g.2xlarge`, 8 vCPU, 32 GB) nodes in a throwaway EKS cluster, using the same CPU image of vLLM (v0.31.0) and the same flags:

```text
split:   --pipeline-parallel-size=2 --tensor-parallel-size=1
         --nnodes=2 --node-rank=<0|1> --master-addr=<leader>      (+ --headless on the worker)
single:  none of those
both:    --dtype=bfloat16 --max-model-len=4096
         -cc.mode=2 -cc.backend=eager --no-async-scheduling
resources per pod: 6 vCPU, 20 GiB, requests = limits, VLLM_CPU_KVCACHE_SPACE=4
```

In the split, a `LeaderWorkerSet` runs two pods on two different nodes and vLLM divides the model's layers into two stages, one per pod. In the single setup, one pod holds all 26 layers.

### How I measured

A few choices matter, because benchmarks lie easily:

- **The client runs inside the cluster**, on a node that does not host the leader, so the VPN and the load balancer are not in the measurement.
- **Every prompt starts with a random nonce**, so vLLM's prefix cache cannot help unless a test is specifically about the cache.
- **Output length is fixed** (`min_tokens` equals `max_tokens` with `ignore_eos`), so runs are comparable and a short answer cannot flatter a result.
- **Per-pod counters.** Around every test I read each pod's CPU counter and network counters from inside the pod. That is where the cost numbers below come from.
- **Each test flags itself as disturbed** if a vLLM pod was recreated or restarted while it ran. None of the reported tests was disturbed.
- The two setups ran **one after the other** on the same pair of nodes, because each pod asks for most of a node's CPU. The suite ran once per setup, and I repeated the concurrency sweep twice more per setup after it threw up something strange (see below).

The tests: one user streaming 200 tokens (8 runs), time to first token against prompt length, a concurrency sweep, a long prompt arriving while someone else is mid-reply, and a follow-up turn that should hit the prefix cache.

## One User: The Single Pod Is 21 Percent Faster

| | Single pod | Split |
|---|---|---|
| Tokens/s, mean of 8 runs | **21.1** (21.04 to 21.15) | 17.5 (17.19 to 17.71) |
| Gap between tokens, median | **46 ms** | 55 ms |
| Gap between tokens, 95th percentile | **51 ms** | 64 ms |

The runs are tight enough that the ranges do not even overlap, so this is not noise. The extra ~9 ms per token is the price of the split.

Why does it cost anything at all? For a single request, the two stages run **in sequence**: the leader runs its layers, ships the intermediate result to the worker, the worker runs the rest, and the sampled token comes back. Only one stage is ever working at a time, so you pay for two network hops and the coordination on every token and get nothing to offset it.

It is not bandwidth. I measured about 4.5 KB of traffic per prompt token and roughly 10 KB per generated token between the pods. That is nothing for a VPC. The cost is round-trip latency and software overhead, paid once per generated token.

## Long Prompts: The One Place the Split Wins

Time to first token against prompt length (unique prompts, three runs each):

| Prompt tokens | Single pod | Split | Split's prefill speed vs single |
|---|---|---|---|
| ~290 | 0.63 s | **0.58 s** | +10% |
| ~1,050 | 1.87 s | **1.75 s** | +7% |
| ~2,080 | 3.53 s | **3.30 s** | +7% |
| ~3,530 | 5.97 s | **5.62 s** | +6% |

Both process around 600 prompt tokens per second, so a 3,500-token prompt takes about six seconds either way. The split is a few percent faster. My guess is that vLLM breaks a long prompt into chunks and the two stages can work on different chunks at the same time, which is real pipelining. I did not verify that, so treat it as a hypothesis.

A few percent faster prefill is not a reason to run twice the hardware.

## Several Users: The Split Is Erratic

Here is the part I did not expect. Total output tokens per second as I added concurrent users, from two repeated sweeps per setup (the two numbers in each cell are the two runs):

| Concurrent users | Single pod | Split |
|---|---|---|
| 2 | 31.6 / 31.7 | 27.4 / 27.4 |
| 3 | 45.3 / 45.4 | **17.8 / 40.0** |
| 4 | 57.4 / 57.3 | **23.4 / 51.2** |
| 5 | 67.8 / 67.7 | 61.5 / 61.1 |
| 6 | 78.1 / 78.0 | **33.8 / 33.5** |
| 8 | 91.9 / 91.8 | 83.8 / 84.0 |

The single pod is boring in the best way. Throughput rises smoothly with every added user, and the two runs agree to within 0.2 tokens per second.

The split is not smooth. At the same number of users it can land in one of two modes: a **fast mode** with about 65 ms between tokens, and a **slow mode** with about 160 ms, which is 2.5 times slower. At 3 and 4 users one run was fast and the next was slow. At 6 users both runs were slow. When it is slow, the split delivers about 40 percent of what the single pod does.

I do not know why. I observed it, repeated it to be sure it was real, and left the cause undiagnosed. What I can say is that it is a property of the pipelined setup and not of the load, since the single pod under the same load was steady. The practical consequence is worse than a lower average: with the split, how fast your users' replies stream depends on a hidden state you cannot see in the request rate.

At 8 users, both setups are in the fast mode and the single pod is still ahead, 92 against 84 tokens per second in total, with each user seeing 15.4 against 13.5 tokens per second. Splitting did not buy any extra throughput under load either. I had half expected the pipeline to keep both nodes busy and win there. It did not.

## What a Long Prompt Does to Everyone Else

A realistic worry on any shared server: one user pastes a huge prompt, and everyone else's reply stalls. I measured it by streaming a 256-token reply and, four seconds in, sending a 3,500-token prompt.

| | Single pod | Split |
|---|---|---|
| Longest pause in the other user's stream | **3.4 s** | 5.7 s |
| Time to first token of the long prompt itself | 6.0 s | 5.7 s |

On the split, the other user's stream freezes for the whole time the long prompt is processed. On the single pod it freezes for about 3.4 s of the 6 s, so the scheduler is interleaving some decoding between the prompt's chunks. Both are bad. A 3,500-token prompt landing on a small CPU server will freeze everyone else for seconds regardless of how you deploy it, and neither setup protects the other users. The results were almost identical across three repeats (5.66 to 5.68 s against 3.41 to 3.42 s), so this is deterministic behaviour and not a fluke.

## Things That Were the Same

The **prefix cache** behaves identically in both. A follow-up turn that repeats a ~2,800-token history reuses 2,816 of 2,847 prompt tokens, and the response starts in about 0.2 seconds instead of 4.5 to 4.9. The control (a different prompt of the same length) pays full price on both, so the speedup is the cache and not chance. In a chat, every turn after the first is fast, split or not.

## What It Costs

| | Single pod | Split |
|---|---|---|
| CPU-seconds per 1,000 output tokens | **162** | 221 |
| Network between the pods, per 1,000 output tokens | 0 | about 14 MB |
| Nodes | **1** | 2 |

The split burns 37 percent more CPU for every token it produces, because each pod spends part of its time waiting on the other. While streaming one reply the single pod keeps about 5.9 of its 6 cores busy; the two split pods together average under 5, about 2.4 each. You pay for twice the machines and use them less.

## So What Is Splitting For?

Memory. That is the whole reason, and this experiment shows why it is not about speed.

A model's weights have to live somewhere. In bf16 the weights alone take about two bytes per parameter. A 1B model is about 2 GB, which fits on a 32 GB node many times over, so there is nothing to gain by cutting it in half and a latency hop to lose. A rough sketch of where the line sits (my arithmetic, not a measurement, and the KV cache and runtime take their own share on top):

| Model | bf16 weights | Fits on one 32 GB node? |
|---|---|---|
| 1B | ~2 GB | easily |
| 4B | ~8 GB | yes |
| 12B | ~24 GB | tight once the KV cache and runtime are counted |
| 31B | ~62 GB | no; needs the model spread across machines |

When the weights do not fit, pipeline parallelism across nodes is how you run the model at all. In that case it is the capacity tool, not the speed tool: you accept the per-token hop because the alternative is not running. Even then, on a CPU server, decoding is limited by how fast it can read the weights from memory, so a very large model will be slow however you place it.

If your model fits, here is what I would do first, in this order:

1. **Don't split.** Run it whole in one pod.
2. **Need more users served? Run more copies**, not a bigger split. Two independent pods behind one Service should roughly double capacity and survive one failing. I did not measure this, so it is an expectation and not a result. The catch is the prefix cache: it is per copy, so a conversation that bounces between copies loses its fast follow-up turns unless requests from one conversation are routed to the same copy.
3. **Model too big for one node?** Only then reach for pipeline parallelism across nodes. Keep tensor parallelism inside a node where the interconnect is fast.
4. **Need it faster?** Splitting will not do it on commodity networking. A smaller or quantized model, or different hardware, will. Check what your CPU backend supports before counting on quantization: vLLM's CPU documentation lists the common 4-bit formats for x86 but not for Arm.

## Things That Bit Me Along the Way

A few of these will cost you time if you try something similar:

- **You cannot bisect with single-node pipeline parallelism on these machines.** vLLM's CPU backend assigns each pipeline rank to its own NUMA node. These instances have one, so asking for two ranks in one pod fails at startup with "Not enough allowed NUMA nodes". One rank per node it is.
- **A Helm chart default almost broke scheduling.** The `LeaderWorkerSet` controller's chart requests a full vCPU by default. After a node replacement it landed beside the monitoring pods and left 5.9 vCPU free, 100 millicores short of the 6 each vLLM pod asks for, and the worker sat `Pending`. Asking for 6 of 7.9 vCPUs is brittle once system pods count; I lowered the controller's request to 100m.
- **Account housekeeping can rewrite your benchmark.** A scheduled cleanup job in the AWS account stopped both nodes twice in a day because, as far as I can tell, I had not declared an end date on the instances. Auto Scaling replaced them with untagged ones. My first benchmark run was cut off partway, and because the harness only wrote results at the end, I lost the early tests. The harness now saves after every test and marks any test during which a vLLM pod restarted, so an interrupted run can be told apart from a clean one.
- **Look at the benchmark's own numbers for oddities.** I would have reported the 4-user dip as noise if I had run the sweep once. Repeating it is what showed the split's two modes.

## Caveats

- **One model.** This is Gemma 3 1B. Nothing here says how a model too large for one node behaves; that is the case where splitting is needed and where this comparison does not apply.
- **Run counts differ by test.** Single-stream speed has 8 runs per setup, the prompt-length and long-prompt tests 3, the main concurrency sweep one pass, plus two repeats of a finer sweep. Treat differences of a few percent as unproven. The big ones above all repeated.
- **Sequential, not simultaneous.** The two setups ran on the same two nodes one after the other. Two instances of the same type can differ a little; the gaps above are much larger than that.
- **Eager backend for both.** The default compile path crashed on this image (the previous post has the full story), so both setups ran vLLM's eager backend. Absolute speeds would change with a working compiler; the comparison holds the setting equal.
- **In-cluster client.** The numbers leave out the load balancer and the VPN. The ~12 tokens/s in the previous post came from a single request measured end to end through the load balancer from my laptop, on earlier instances. These in-cluster numbers are higher, and I did not isolate how much of that is the path and how much is the instances.
- **The split's slow mode is unexplained**, and so is its slightly faster long-prompt prefill beyond my chunking guess.

## What I Would Take From It

The experiment cost a couple of hours and a small cluster, and it settled a question that is easy to get wrong by intuition. "More machines" feels like "faster", and for inference of a model that fits on one, it is the opposite:

- **Splitting trades speed for capacity.** You get to run a model that would not otherwise fit, and you pay for it in latency on every token.
- **Prefer replicas to splits** when the model fits and you need more throughput.
- **Measure the unglamorous things:** the repeat run, the idle baseline, the CPU spent per token. They are where the surprises were.
- **A distributed engine's failure shows up on a different rank than the one that broke.** Keep the other pod's logs.

The next experiment I want to run is the obvious one: two independent copies on two nodes behind one Service, and a look at what the prefix cache does when a conversation can land on either.

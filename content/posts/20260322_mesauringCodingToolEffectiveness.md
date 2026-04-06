+++
title = "Measuring Coding Tool Effectiveness"
description = "How to measure information related to use coding tools more effectively by combining DORA metrics and attributed token usage."
tags = [
    "metrics",
    "dora",
]
date = "2026-03-22"
categories = [
    "devops",
    "ai",
]
+++

Most online content regarding AI coding tools focuses heavily on input and output token counts. While these metrics are useful for understanding the raw volume of data processed, they often fail to address the actual effectiveness of those tokens in solving real-world engineering problems. Measuring the true impact of these tools on development workflows remains a challenge because volume does not equate to value.

### Understanding DORA Metrics

To measure engineering effectiveness, many organizations turn to **DORA metrics** (DevOps Research and Assessment). These are four key indicators that have become the industry standard for measuring software development and delivery performance:

1.  **Deployment Frequency:** How often your organization successfully releases to production.
2.  **Lead Time for Changes:** The time it takes for a commit to reach production.
3.  **Change Failure Rate:** The percentage of deployments causing a failure in production.
4.  **Failed Service Recovery Time:** How long it takes to restore service when a production failure occurs.

While DORA metrics provide a high-level view of team performance and stability, they don't explicitly account for the cost or efficiency of the tools used to achieve those results.

### Moving Beyond Raw Tokens: Attributed Usage

One potential approach to bridge this gap is to combine DORA metrics with a new measure: **attributed token usage** linked directly to issue trackers. 

Currently, we know how many tokens we use globally, but we rarely know *what* they were used for. By attributing token consumption to specific Jira tasks, GitHub issues, or pull requests, we can begin to see the "cost of completion" for different types of work.

For example, we could track how many tokens (and their associated cost) are consumed to resolve a specific bug or implement a feature. If a particular bug costs $6-$8 in tokens to solve, that provides a tangible data point. This isn't just about the financial cost; it's about the "cognitive load" the AI is carrying to understand and solve that specific problem.

### Cost as a Signal for Investigation

On a higher level, this attribution allows teams to identify if certain types of issues or specific parts of the codebase are incurring disproportionately high costs. 

*   **Complex Legacy Code:** If a relatively simple bug in a legacy module requires $20 of tokens to "explain" the context to the AI, it's a strong signal that the code is too complex and might be a candidate for refactoring.
*   **Poorly Defined Requirements:** A high token-to-resolution ratio on new features might indicate that the requirements are ambiguous, leading the AI (and the developer) to iterate through many failed attempts.
*   **Tool Inefficiency:** It helps us evaluate whether a specific AI tool or model is actually effective for our specific tech stack compared to its cost.

While this won't be a perfectly accurate measure of complexity—AI costs fluctuate and models evolve—it serves as a valuable **signal**. If an issue's token cost spikes, it's a prompt for a human lead to investigate whether the tool is struggling with that specific context or if the problem itself is fundamentally flawed. By layering these cost insights over DORA's velocity and stability metrics, we get a much clearer picture of our true engineering efficiency.

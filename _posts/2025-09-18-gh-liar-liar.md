---
layout: post
title: GH! Liar liar
author: akgunberk
date: 2025-09-18 14:13 +0300
categories: [daily, code]
tags: [git]
---

# When GitHub PR Diffs Scare Reviewers More Than They Should

TL;DR

When reviewing PRs, diffs get inflated by noise from files like package-lock.json, .d.ts, or giant auto-generated JSONs. To keep your sanity (and your reviewers happy), filter them out with:

```bash
git diff --stat main...feature-branch \
  -- ':(exclude)*.lock' ':(exclude)*.json' ':(exclude)*.d.ts'
```

This gives you real stats on what actually matters in a PR, not just a wall of machine-generated chaos.

# The Problem: PR Diff Horror Stories

Every engineer knows the feeling: you click open a PR on GitHub, scroll down, and are greeted with a scrollbar that shrinks to the size of a pixel. It’s not the thoughtful logic changes you need to review—it’s a 5,000-line package-lock.json update, a handful of auto-generated .d.ts files, and maybe even some data dumps masquerading as JSON configs.

The result? Reviewers either: 1. Get scared away and defer the review (aka PR limbo). 2. Skim too quickly and risk missing the important parts. 3. Or worse: approve without actually looking, because “surely CI has it covered.”

These files matter for reproducibility and tooling, but they don’t need human eyes in every diff.

⸻

The Fix: Filter the Noise

Git has your back. With git diff --stat and some exclusions, you can strip away the distractions and surface the real code changes:

```bash
git diff --stat main...feature-branch \
  -- ':(exclude)*.lock' ':(exclude)*.json' ':(exclude)*.d.ts'
```

Suddenly, what looked like a monstrous 8,000-line PR boils down to:
• 12 files changed
• 250 insertions
• 80 deletions

Now that’s something you can review without losing your weekend.

# Why This Matters

PR size perception directly affects how (and whether) reviewers engage:
• Bigger diffs look scarier → reviewers hesitate.
• Cleaner stats build confidence → reviewers focus on meaningful changes.
• Teams move faster → less time wasted on review ping-pong.

It’s not about hiding changes—it’s about framing them in a way that invites thoughtful review.

⸻

# Git: The Frenemy We Love to Hate

Using Git well is like learning a martial art. At first you flail around, breaking things and occasionally yourself. Eventually, you learn the graceful moves—like diff exclusions—that make you feel powerful.

So yes, Git can be arcane, but every new trick adds to your reviewer toolkit. And your teammates will thank you when they don’t have to dig through the next Great Wall of Lockfiles.

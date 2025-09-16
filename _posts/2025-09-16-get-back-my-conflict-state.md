---
layout: post
title: Get back my conflict state!
date: 2025-09-16 09:20 +0300
author: akgunberk
categories: [daily, code]
tags: [git]
---

# How to Bring Back Your Merge Conflict State

I love using [`tig`](https://jonas.github.io/tig/) to simplify my Git workflow — browsing status, un/staging files, and juggling branches feels much smoother.

But every now and then, after resolving a merge conflict, I catch myself wondering: _Did I actually fix this the right way?_

That’s when Git reminds me it’s a universe of hidden tricks, always ready to teach me something new.

**Today I Learned (TIL):**  
If you want to get your merge conflict markers back to its original state, just run:

```bash
git checkout --merge <filepath>
```

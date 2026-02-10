---
layout: post
title: Nestjs and Authorization Deep Dive Part II
date: 2026-02-09 12:41 +0300
math: true
---

Now, we can jump into to the real implementation after we set up our project in
[Part I.]({% post_url 2026-02-04-nestjs-and-authorization-deep-dive-part-i %})

[Passport](https://github.com/jaredhanson/passport) will be our tool to integrate JWT into our system.
Let's add dependencies and `auth` module to implement our auth controller and the guard.

```bash
pnpm add @nestjs/passport @nestjs/jwt passport-jwt;
pnpm add -D @types/passport-jwt;

nest g module auth;
nest g service auth --no-spec;
nest g guard auth/guard/jwt --no-spec;
touch src/auth/guard/jwt/jwt-strategy.ts;
```

The first thing to do is fill in the strategy extending `PassportStrategy` from `@nestjs/passport`

```typescript
import { ExtractJwt, Strategy } from "passport-jwt";
import { PassportStrategy } from "@nestjs/passport";
import { Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { User } from "generated/prisma/client";
import { Request } from "express";
import { UsersService } from "../../users/users.service";

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        (req: Request) => req.cookies?.access_token,
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>("JWT_SECRET")!,
    });
  }

  async validate(
    payload: Pick<User, "email" | "role"> & {
      sub: string;
      jti: string;
      iat: number;
      exp: number;
    },
  ): Promise<User> {
    // Verify user still exists and is active
    const user = await this.usersService.findUser({ id: payload.sub });

    if (!user || !user.isActive) {
      throw new UnauthorizedException("User not found or inactive");
    }

    // Verify token wasn't issued before password change
    if (user.passwordChangedAt) {
      const tokenIssuedAt = new Date(payload.iat * 1000);
      if (tokenIssuedAt < user.passwordChangedAt) {
        throw new UnauthorizedException("Token invalidated by password change");
      }
    }

    return user;
  }
}
```

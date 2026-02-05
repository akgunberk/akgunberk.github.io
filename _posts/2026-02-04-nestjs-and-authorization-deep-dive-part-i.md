---
author: akgunberk
layout: post
title: Nestjs and Authorization Deep Dive Part I
date: 2026-02-04 11:25 +0300
---

No BS. Setting up Nestjs backend application with secure authentication and authorization.
But first, we need to add every bits and pieces needed for a backend application.

Start with `pnpm dlx nest new nest-auth` or install nest-cli globally `pnpm install -g @nestjs/cli`

Use `pnpm` (or whatever floats your boat)

```bash
cd nest-auth
```

## Configuration

Add configuration, we will ofc need a system to import our environment variables.

```bash
pnpm add @nestjs/config
```

and then update your app.module.ts to include config module globally,
cause it will be used most of the places of your app. If not, we can change this later on.

```typescript
// app.modules.ts

// validate your env before starting your app
const validateEnv = (config: Record<string, any>) => { return config };

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      // If a variable is found in multiple files, the first one takes precedence.
      // envFilePath: ['.env.development.local', '.env.development'],
      envFilePath: '.env',
      validate: validateEnv,
    })
  ]
})
```

## Database

You'll need a database for you app, so let's set that up. I'll use **postgres** as DB and **prisma** to define my schema.

### Postgres

We'll use docker to setup our database cause it is easier and will be ready for deployment when it is done.
If you don't want to use docker for some reason. Just use `brew`.
But I suggest to use docker which is an essential skill to learn for a developer.

You can run postgres@18 with brew using these commands:

```bash
brew install postgresql@18
brew services start postgres@18
brew services info postgresql@18
```

Let's define our environment variables first for both docker-compose and prisma.

```dot
// .env
# for docker-compose
DB_USER=db_user
DB_PASSWORD=db_password
DB_NAME=db_name
# for prisma connection (make sure values are same with the ones above)
DATABASE_URL="postgresql://db_user:db_password@localhost:5432/db_name?schema=public"
```

Here is a base **docker-compose.yml** to set your docker for postgres on alpine.

```yaml
services:
  # PostgreSQL database service
  postgres:
    image: postgres:17-alpine
    container_name: postgres
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    ports:
      - "5432:5432"
    volumes:
      # Named volume persists data across container restarts
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "${DB_USER}", "-d", "${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - network

volumes:
  postgres_data:

networks:
  network:
    driver: bridge
```

It was pretty easy, huh? You can get your DB up and running with this command:

And then check on Docker Desktop if all good.

```bash
docker-compose -f docker-compose.yml up -d
```

### Prisma

Let's add it as dev-dependency and init.

```bash
pnpm add -D prisma
pnpm prisma init
```

Now, let's define our schema for 'User'.

```typescript
// schema.prisma
// make sure you make it commonjs in module format as seen
// and postgres for db provider

generator client {
  provider     = "prisma-client"
  output       = "../generated/prisma"
  moduleFormat = "cjs"
}

datasource db {
  provider = "postgresql"
}

// For role based authroization
enum Role {
  BUYER
  SELLER
  ADMIN
}

model User {
  // Authentication fields
  id                    String    @id @default(uuid())
  email                 String    @unique
  passwordHash          String    @map("password_hash")
  refreshTokenHash      String?   @map("refresh_token_hash")
  refreshTokenExpiresAt DateTime? @map("refresh_token_expires_at")
  passwordChangedAt     DateTime? @map("password_changed_at")
  isActive              Boolean   @default(true) @map("is_active")

  // Account lockout fields
  loginAttempts         Int       @default(0) @map("login_attempts")
  lockoutUntil          DateTime? @map("lockout_until")
  lastFailedLoginAt     DateTime? @map("last_failed_login_at")
  lastSuccessfulLoginAt DateTime? @map("last_successful_login_at")

  // Session tracking fields
  activeSessions       Session[]

  // Authorization fields
  role                  Role      @default(BUYER)

  @@index([refreshTokenHash])
  @@index([email])
}
```

Then, let's make our first migration so prisma generates types and other stuff needed for our DB.

```bash
# This should generate related files in `prisma/migrations`
pnpm prisma migrate dev --name init
```

DB is generated but we also need prisma client for prisma model definitions and CRUD operations in nestjs.

```bash
pnpm add @prisma/client @prisma/adapter-pg
# This should generate related files in `.generated/prisma`.
pnpm prisma generate
# This will generate our service scaffold
pnpm dlx nest g service prisma
```

Here is what our prisma service looks like, just a simple connection with the postgres adapter.

```typescript
import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { PrismaClient } from "generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import { ConfigService } from "@nestjs/config";

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  private readonly logger = new Logger(PrismaService.name);

  constructor(configService: ConfigService) {
    const adapter = new PrismaPg({
      connectionString: configService.get("DATABASE_URL"),
    });

    super({ adapter });
  }

  async onModuleInit() {
    try {
      await this.$connect();
      this.logger.log("Database connected successfully");
    } catch (error) {
      this.logger.error("Failed to connect to database", error.stack);
      throw error;
    }
  }
}
```

### Docker Compose

Since we already generated migrations and initialized our DB, lets remove the standalone postgres.
Our goal is, in docker-compose, we'll get both postgress and nestjs app together which will be ready to deploy.

```bash
docker-compose -f docker-compose.yml down --remove-orphans
```

Now, let's add Dockerfile for nestjs app and integrate that into docker-compose.yml.
After that, I will extend docker-compose.yml with docker-compose.dev.yml to implement HMR.
HMR will help us reflecting changes done in our local nestjs to the container in development.

```Dockerfile
# STAGE 1: Builder
FROM node:22-alpine AS builder
WORKDIR /app
# Copy dependency files first (leverages Docker layer caching)
COPY package.json pnpm-lock.yaml tsconfig.json tsconfig.build.json ./
# pnpm install --frozen-lockfile ensures reproducible builds
RUN npm install -g pnpm && pnpm install --frozen-lockfile
# Copy source code
COPY . .
# Generate Prisma client (must happen before TypeScript build)
RUN pnpm prisma generate
# Compile TypeScript to dist/ folder
RUN pnpm run build

# STAGE 2: Runtime
FROM node:22-alpine
WORKDIR /app
# Install dumb-init to handle signals properly
# Also install postgresql-client for pg_isready used in entrypoint
RUN apk add --no-cache dumb-init curl postgresql-client
# Install pnpm for development commands
RUN npm install -g pnpm
# Copy compiled code from builder
COPY --from=builder /app/dist ./dist
# Copy generated Prisma client (platform-specific, must be from builder)
COPY --from=builder /app/generated ./generated
# Copy all node_modules (including prisma CLI for migrations)
# Trade-off: larger image (~50MB more) but simpler and reliable migrations
COPY --from=builder /app/node_modules ./node_modules

# Copy package.json for reference (not strictly needed, but good practice)
COPY package.json ./
# Copy TypeScript configuration (needed for `pnpm start:dev` in development)
COPY tsconfig.json tsconfig.build.json ./
# Copy Prisma schema and migrations (needed for `prisma migrate deploy`)
COPY prisma ./prisma
# Copy prisma.config.ts (needed for Prisma 7)
COPY prisma.config.ts ./

# Create a non-root user for security (prevents running as root)
# If container is compromised, attacker has limited privileges
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nestjs -u 1001
# Change ownership of app directory to nestjs user
RUN chown -R nestjs:nodejs /app
USER nestjs

# Expose port (documentation only, doesn't actually publish)
EXPOSE 3000
# Health check: Docker will run this every 10 seconds
# If 3 consecutive checks fail, container is marked unhealthy
HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Use dumb-init to properly handle signals
# Node.js running as PID 1 doesn't handle SIGTERM correctly by default
ENTRYPOINT ["dumb-init", "--", "sh", "-c", "node node_modules/prisma/build/index.js migrate deploy || true && exec node dist/src/main"]
```

This will handle getting nestjs service up and running for us.
Now let's add that into **docker.compose.yml** to work with our postgress service.

```yaml
# docker.compose.yml

# PostgreSQL database service
postgres:
  image: postgres:17-alpine
# ...rest

# ADD THIS BELOW 'postgres' SERVICE
# NestJS application service
app:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: app
  ports:
    - "3000:3000"
  environment:
    # Database connection
    DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}?schema=public
    # Set your env
    NODE_ENV: development
  depends_on:
    postgres:
      condition: service_healthy
  networks:
    - network
```

### HealthCheck

Let's test everything but for testing, we should add healtcheck module which we'll eventually need
in our backend app. So let's get started, it is easy as pie.

```bash
pnpm add -D @nestjs/terminus
pnpm dlx nest g module health
pnpm dlx nest g controller health
```

Let's create health module with proper dependency injection.
Be aware of TerminusModule import and PrismaService in providers, to hit prisma healthcheck.

```typescript
// health.module.ts
import { Module } from "@nestjs/common";
import { TerminusModule } from "@nestjs/terminus";
import { HealthController } from "./health.controller";
import { PrismaService } from "src/prisma/prisma.service";

@Module({
  imports: [TerminusModule],
  controllers: [HealthController],
  providers: [PrismaService],
})
export class HealthModule {}
```

Now the controller to generate `/health` endpoint.

```typescript
// health.controller.ts
import { Controller, Get, Logger } from "@nestjs/common";
import {
  HealthCheckService,
  HealthCheck,
  PrismaHealthIndicator,
} from "@nestjs/terminus";
import { PrismaService } from "src/prisma/prisma.service";

@Controller("health")
export class HealthController {
  private readonly logger = new Logger(HealthController.name);

  constructor(
    private health: HealthCheckService,
    private prismaHealth: PrismaHealthIndicator,
    private prisma: PrismaService,
  ) {}

  @Get()
  @HealthCheck()
  async check() {
    try {
      this.logger.debug("Health check requested");
      const result = await this.health.check([
        async () => this.prismaHealth.pingCheck("prisma", this.prisma),
      ]);

      this.logger.log("Health check passed");
      return result;
    } catch (error) {
      this.logger.error("Health check failed", error.stack);
      throw error;
    }
  }
}
```

Aaaand the testing, I am using `httpie` but you can use `curl` if you'd like.

```bash
# get container up and running
docker-compose -f docker-compose.yml up -d
# install some tools to hit /health endpoint in terminal
brew install httpie jq
# hit the road jack
http :3000/health | jq .status # response => "ok"
```

### HMR

For HMR, I will create another docker-compose file named **docker-compose.dev.yml**

```Dockerfile
# Development compose file with Docker watch for HMR
# Usage: docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
#
# Overrides the base docker-compose.yml with:
# - Volume mounts for live code syncing
# - Docker watch rules to trigger HMR on file changes
# - pnpm start:dev command for TypeScript recompilation

services:
  app:
    working_dir: /app
    # Override command to run in development mode with TypeScript watcher
    entrypoint:
      [
        'dumb-init',
        '--',
        'sh',
        '-c',
        'pnpm prisma migrate dev && pnpm start:dev',
      ]

    volumes:
      # Bind mount current directory to /app for live code syncing
      - .:/app
      # Anonymous volumes prevent syncing of large directories
      - /app/node_modules
      - /app/generated

    # Ensure app waits for postgres to be healthy before starting
    depends_on:
      postgres:
        condition: service_healthy

    # Connect to same network as postgres
    networks:
      - network

    develop:
      watch:
        # Watch TypeScript source files
        - action: sync
          path: src
          target: /app/src

        # Watch Prisma schema and migrations
        - action: sync
          path: prisma
          target: /app/prisma

        # Watch config files at root
        - action: sync
          path: package.json
          target: /app/package.json

        - action: sync
          path: pnpm-lock.yaml
          target: /app/pnpm-lock.yaml

        - action: sync
          path: tsconfig.json
          target: /app/tsconfig.json

        - action: sync
          path: nest-cli.json
          target: /app/nest-cli.json

        - action: sync
          path: eslint.config.mjs
          target: /app/eslint.config.mjs

        - action: sync
          path: .prettierrc
          target: /app/.prettierrc

networks:
  network:
    driver: bridge
```

Let's test it if it works.

```bash
docker-compose -f docker-compose.yml down -v --remove-orphans;
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
# If you're seeing this, then it works!
# Starting compilation in watch mode...
```

You can add/remove a controller and then check the nest output of mapping controllers.

### Bonus / Makefile

It is overwhelming to write all those commands right? Let's create a Makefile with the help of AI.

[Here](https://gist.github.com/akgunberk/cbe25f7cb1441756426cb1be77cb6de9) is my version but you can ofc update it acc. to your needs.

Make sure you update DB_USER and DB_NAME in the Makefile.

```bash
# see all commands
make help
# get up dev
make dev # make dev-stop
```

### Summary

What we've done so far is:

- Setting our required modules such as **config** and **healthcheck** module.
- Creating our Database and Prisma client for interaction with DB.
- Containerizing our app so it will be ready to share and deploy.
- Implementing HMR for easier development.

What is next:

- Adding JWT authentication guard
- Adding RBAC, Role Based Access Control
- Adding CSRF protection
- Adding Session
- And other bunch of things we'll face on the road.

Hope it helps, until next time!

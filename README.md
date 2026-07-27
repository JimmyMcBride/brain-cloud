# Brain Cloud

Brain Cloud is the hosted and self-hostable cloud platform for Brain: an extensible context and memory platform for people, teams, and AI agents.

Brain supports three equal operating modes:

- **Local:** core context and memory stay on the user's machine; no account or server is required.
- **Cloud:** cloud-native projects store context, memory, search, conversations, collaboration, and optional module data without requiring a local repository.
- **Hybrid:** local Brain projects link to cloud projects and synchronize only user-selected durable content.

The official hosted service and self-hosted installations use the same public HTTP protocol. Compatible clients select a server by base URL; the hosted service has no privileged protocol.

## Product boundary

Brain Core owns capabilities every deployment and module needs: project identity, durable context and memory, retrieval, compilation, provenance, sessions, security boundaries, events, audit, and module lifecycle contracts.

This repository owns the Brain Cloud server, HTTP API, cloud-native projects, hosted retrieval, revision history, sync coordination, Hive Mind, identity and collaboration, module management and execution, workers, auditability, deployment support, and eventually one unified web application.

The primary repository family is:

```text
brain
brain-cloud
brain-cloud-sdk-go
```

Future TypeScript and Python SDKs may follow. The server implements the protocol and never depends on an SDK. Local `.brain/` behavior and Brain CLI implementation remain in `brain`.

Planning is not a separate cloud platform. It is the first major optional official Brain module. The existing standalone `plan` repository remains useful during migration, but this repository must not implement Plan Cloud, a separate Plan frontend, identity system, SDK, or agent gateway.

## Extensibility

Official and community modules adapt Brain to different workflows without making every workflow part of Brain Core. Modules use formal capabilities and permissions; official modules receive no private bypass into unrelated internals.

The staged direction is:

1. Supervised official OTP applications validate stable interfaces inside Brain Cloud.
2. Community modules later run as isolated external processes through a language-neutral protocol.
3. Cloud module services, jobs, APIs, agent tools, and constrained web surfaces follow after the contracts and security model mature.

Planning must be optional. Brain works without Planning, with the official Planning module, with external planning-context modules, or with Planning connected to an external execution system. GitHub planning remains transitional coordination, not the permanent data foundation. No official Linear integration is planned.

## Status

Phase 0 foundation only. The repository currently provides a Phoenix/LiveView web shell, structured logging, OTP supervision, PostgreSQL-backed readiness, compatibility and empty module discovery, tests, CI, and development deployment scaffolding. Projects, memory persistence, authentication, search, sync, Hive Mind, module execution, and Planning remain roadmap work.

## Local development

Requirements: Elixir 1.20.2 and Erlang/OTP 29.0.3. PostgreSQL 18 and Docker are optional for local development.

```bash
docker compose up -d postgres
make setup
make check
make run
```

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `4000` | Phoenix HTTP port |
| `DATABASE_URL` | local development config | PostgreSQL connection URL |
| `SECRET_KEY_BASE` | development-only value | cookie and LiveView signing secret |
| `PHX_HOST` | `localhost` | externally visible host |
| `PHX_SERVER` | unset locally | start the endpoint in an OTP release |
| `POOL_SIZE` | `10` | PostgreSQL connection pool size |

```bash
docker compose up --build
curl http://localhost:4000/
curl http://localhost:4000/healthz
curl http://localhost:4000/readyz
curl http://localhost:4000/v1/system/info
```

The Compose file starts the Phoenix release and PostgreSQL. `/readyz` returns `503` until PostgreSQL accepts a query; Phase 1 product persistence is not implemented yet.

## Project documents

- [Product vision](docs/product-vision.md)
- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Security direction](docs/security.md)
- [Self-hosting direction](docs/self-hosting.md)
- [Architecture decisions](docs/adr/)

## Branches

`develop` is the active integration/default branch, `release/vX.Y.Z` stabilizes releases, and `main` is the release branch. Recommended protections for `develop` and `main`: require pull requests, passing CI, resolved review conversations, and no force pushes or deletion.

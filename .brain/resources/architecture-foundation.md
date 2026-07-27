---
title: Brain Cloud architecture foundation
updated: "2026-07-27T21:22:34Z"
---
## Repository boundary

Brain Cloud is the one hosted and self-hostable platform for Brain Core and optional modules. The primary repository family is `brain`, `brain-cloud`, and `brain-cloud-sdk-go`. The server implements the public `/v1` protocol and never imports an SDK.

Planning is the first major optional official Brain module. The standalone `plan` repository remains during migration, but Plan Cloud, a separate Plan frontend/SDK/identity system/agent gateway, and official Linear integration are removed directions. GitHub planning is transitional coordination, not permanent product storage.

## Core and module rules

Brain Core owns project identity, context, memory, retrieval, compilation, provenance, sessions, security boundaries, permissions, configuration, events, audit, module lifecycle, and capability registration. Hive Mind remains Core.

Official modules begin as compiled packages implementing formal lifecycle, capability, permission, configuration, event, migration, discovery, and audit contracts. They receive no private exceptions. Community modules later use an external process protocol; transport is undecided. Do not add Go native plugins or unrestricted in-process third-party loading.

Planning must be optional, capability-discovered, tracker-independent, and permission-separated from context and memory. Detailed Planning domain/storage/CLI/migration design is deferred to a dedicated contract.

## Entrypoints and packages

- `cmd/api/main.go`: API composition root, structured JSON logging, signal handling, graceful HTTP shutdown.
- `cmd/worker/main.go`: lifecycle-ready worker composition root; no queue or jobs exist in Phase 0.
- `internal/config`: environment configuration and validation.
- `internal/server`: HTTP routes, compatibility response, request logging, and handler tests.

## Protocol and deployment

Implemented routes are `GET /healthz`, `GET /readyz`, and `GET /v1/system/info`. Discovery advertises server/protocol capabilities and `modules: []`; no module runtime exists. `openapi/brain-cloud-v1.yaml` reserves module and Planning areas without speculative schemas.

`Dockerfile` builds the non-root API image; `compose.yaml` provides development API plus currently unused PostgreSQL; `.github/workflows/ci.yml` verifies formatting, tests, vet, and builds.

## Roadmap boundary

Phase 1 remains next: one persistent cloud project, durable memory, retrieval, and search. Core module framework is Phase 10. Official Planning integration is Phase 11 under a separate migration contract.

---
title: Brain Cloud architecture foundation
updated: "2026-07-28T05:25:43Z"
---
## Repository boundary

Brain Cloud is the one hosted and self-hostable platform for Brain Core and optional modules. The primary repository family is `brain`, `brain-cloud`, and `brain-cloud-sdk-go`. The server implements the public `/v1` protocol and never imports an SDK.

Planning is the first major optional official Brain module. The standalone `plan` repository remains during migration, but Plan Cloud, a separate Plan frontend/SDK/identity system/agent gateway, and official Linear integration are removed directions. GitHub planning is transitional coordination, not permanent product storage.

## Core and module rules

Brain Core owns project identity, context, memory, retrieval, compilation, provenance, sessions, security boundaries, permissions, configuration, events, audit, module lifecycle, and capability registration. Hive Mind remains Core.

Official Brain Cloud modules begin as supervised OTP applications implementing formal lifecycle, capability, permission, configuration, event, migration, discovery, and audit behaviours. They receive no private exceptions. Community modules later use an external process protocol; transport is undecided. Do not load unrestricted third-party code in process.

Planning must be optional, capability-discovered, tracker-independent, and permission-separated from context and memory. Detailed Planning domain/storage/CLI/migration design is deferred to a dedicated contract.

## Umbrella applications

- `apps/brain_cloud`: Ecto/PostgreSQL, projects, immutable memory revisions, exact content hashes, project-scoped keyword search, system information, readiness, release migrations, and domain supervision.
- `apps/brain_cloud_web`: Phoenix, Bandit, temporary development bearer authentication, LiveView, structured JSON routes, assets, and endpoint supervision.
- No worker-only application or queue exists; future jobs run under explicit OTP supervision.

## Protocol and deployment

Implemented product routes are `POST /v1/projects`, `POST /v1/projects/{project_id}/memories`, `GET /v1/projects/{project_id}/memories/{memory_id}`, and `GET /v1/projects/{project_id}/search`. `GET /healthz`, `GET /readyz`, and `GET /v1/system/info` remain public. Discovery advertises the Phase 1 capabilities and `modules: []`; no module runtime exists. `openapi/brain-cloud-v1.yaml` documents the product contract and reserves module and Planning areas without speculative schemas.

`DEV_API_TOKEN` and `DEV_ACTOR_ID` provide development-only authentication and actor provenance. They do not implement production identity, authorization, or multi-tenancy.

`Dockerfile` builds a non-root OTP release and runs migrations before startup; `compose.yaml` provides the Phoenix server plus PostgreSQL; `.github/workflows/ci.yml` verifies formatting, compilation, database tests, and assets. `make smoke-phase1` verifies create/retrieve/search, API restart durability, and PostgreSQL outage/recovery against a running Compose project.

## Roadmap boundary

Phase 1 is the first persistent project/memory vertical slice. Phase 2 production identity and multi-tenancy is next. Core module framework is Phase 10. Official Planning integration is Phase 11 under a separate migration contract.

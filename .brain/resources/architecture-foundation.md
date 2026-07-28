---
title: Brain Cloud architecture foundation
updated: "2026-07-28T20:04:40Z"
---
## Repository boundary

Brain Cloud is the one hosted and self-hostable platform for Brain Core and optional modules. The primary repository family is `brain`, `brain-cloud`, and `brain-cloud-sdk-go`. The server implements the public `/v1` protocol and never imports an SDK.

Planning is the first major optional official Brain module. The standalone `plan` repository remains during migration, but Plan Cloud, a separate Plan frontend/SDK/identity system/agent gateway, and official Linear integration are removed directions. GitHub planning is transitional coordination, not permanent product storage.

## Core and module rules

Brain Core owns project identity, context, memory, retrieval, compilation, provenance, sessions, security boundaries, permissions, configuration, events, audit, module lifecycle, and capability registration. Hive Mind remains Core.

Official Brain Cloud modules begin as supervised OTP applications implementing formal lifecycle, capability, permission, configuration, event, migration, discovery, and audit behaviours. They receive no private exceptions. Community modules later use an external process protocol; transport is undecided. Do not load unrestricted third-party code in process.

Planning must be optional, capability-discovered, tracker-independent, and permission-separated from context and memory. Detailed Planning domain/storage/CLI/migration design is deferred to a dedicated contract.

## Umbrella applications

- `apps/brain_cloud`: Ecto/PostgreSQL, accounts, organization tenancy, scoped token digests, immutable audit events, organization-owned projects, immutable memory revisions, exact content hashes, tenant/project-scoped keyword search, system information, readiness, release migrations/bootstrap, and domain supervision.
- `apps/brain_cloud_web`: Phoenix, Bandit, persisted bearer authentication and fixed-scope enforcement, LiveView, structured JSON routes, assets, and endpoint supervision.
- No worker-only application or queue exists; future jobs run under explicit OTP supervision.

## Protocol and deployment

Implemented product routes include token create/list/revoke, project creation, memory creation/retrieval, and keyword search. Root, health, readiness, and system discovery remain public. Discovery advertises implemented fixed scopes including `tokens.manage` and `modules: []`; no module runtime exists. `openapi/brain-cloud-v1.yaml` documents the product contract and reserves module and Planning areas without speculative schemas.

Release bootstrap creates or reuses an organization owner and prints an initial full-scope token once. Explicit recovery revokes the active bootstrap token and prints one replacement. Every credential is bound to one active organization membership; tenant-aware queries enforce organization scope before loading protected content.

`Dockerfile` builds a non-root OTP release and runs migrations before startup; `compose.yaml` provides the Phoenix server plus PostgreSQL; `.github/workflows/ci.yml` verifies formatting, compilation, database tests, the isolated legacy upgrade, and assets. `make upgrade-phase2` verifies the legacy migration. `make smoke-phase2` verifies bootstrap/recovery, token lifecycle, two-organization isolation, create/retrieve/search, API restart durability, and PostgreSQL outage/recovery.

## Roadmap boundary

Phase 1 is the first persistent project/memory vertical slice. Phase 2A implements GitHub spec [#5](https://github.com/JimmyMcBride/brain-cloud/issues/5): production API identity, organization tenancy, scoped revocable tokens, authorization on existing product routes, Phase 1 data migration, release bootstrap/recovery, and minimal immutable audit events. Teams, agent credentials, interactive identity, and fine-grained project permissions remain later Phase 2 work. Core module framework is Phase 10. Official Planning integration is Phase 11 under a separate migration contract.

---
updated: "2026-08-09T08:45:48Z"
---
# Brain Cloud roadmap

## Direction

Brain is the core platform for durable project context, memory, retrieval, grounding, collaboration, and optional workflow modules. Brain Cloud hosts and self-hosts that platform. Local, cloud-native, hybrid, and self-hosted operation remain first-class.

Planning is the first major optional official Brain module. It is not a separate cloud platform and must not require GitHub or another external tracker. GitHub remains useful for transitional coordination and later as an optional integration. Official Linear integration is removed from the product direction.

## Product capabilities

### Brain Cloud Core

- Cloud-native projects, users, organizations, teams, access control, conversations, revisions, hosted retrieval and bounded context compilation.
- Hybrid synchronization with stable document identities, cursors, selective visibility, idempotency, explicit conflicts, and Brain-compatible export.
- Hive Mind with authorized project selection, per-project retrieval, cross-project reranking, relationships, contradictions, provenance, and Hive Memory.
- Agent-safe APIs, scoped credentials, proposals, events, audit logs, background processing, hosted operation, and self-hosting.
- One unified web application and one SDK family per language.

### Module ecosystem

- Core module lifecycle, registry, explicit enable/disable, capability registration, configuration, permissions, events, migrations, storage ownership, discovery, and audit.
- Stage 1: supervised official OTP applications validating stable behaviours and contracts.
- Stage 2: external-process community modules through a future language-neutral protocol; no shared runtime ABI dependency.
- Stage 3: hosted module services, jobs, APIs, agent tools, and constrained web extensions.
- Candidate extension points: commands, context/search providers, memory types, agent tools, events, jobs, routes, web surfaces, and integration providers.
- Manifest direction: stable ID/version, Brain API range, runtimes, capabilities, permissions, dependencies, configuration, migrations, network/secrets declarations, provenance, publisher, and integrity data.
- Security direction: explicit install approval, allowlists, version pinning, signatures/checksums, revocation, audit, scoped secrets/network/filesystem access, upgrade review, isolation where practical, safe failure, and Core mediation.

### Optional Planning

- Official module; optional locally, in cloud, and in hybrid mode.
- Separate planning permissions from context and memory.
- Cloud planning data and UI hosted inside Brain Cloud only when enabled.
- Stable Brain module interfaces with no private internal exceptions.
- Works without GitHub, Jira, or another work tracker.
- External systems may be import, publication, mirror, or execution targets.
- Standalone `plan` remains during migration; its domain, storage, CLI, and compatibility plan require a dedicated contract.

### Unified clients and UI

- `brain-cloud-sdk-go` offers core and capability-gated optional clients: projects, context, memory, search, Hive Mind, modules, and Planning.
- Absence of `planning` is valid. SDKs contain no local `.brain/`/`.plan/` behavior or module implementation.
- One web application contains core surfaces; Planning surfaces appear only when enabled.

## Delivery phases

### Phase 0 — Repository and server foundation

**Complete.** Repository bootstrap, Phoenix umbrella and LiveView shell, health/database readiness/system info, OpenAPI, OTP release, Docker/Compose, CI, Brain and Plan initialization, temporary GitHub planning mode, and foundational product/architecture documentation.

### Phase 1 — First Brain Cloud vertical slice

**Complete.** Development authentication, project creation, one immutable Markdown memory revision, exact content hashing and actor provenance, project-scoped PostgreSQL keyword search, structured API errors, OpenAPI coverage, and restart-durability verification.

### Phase 2 — Identity and multi-tenancy

**Phase 2A complete.** [Production identity and organization tenant foundation](https://github.com/JimmyMcBride/brain-cloud/issues/5) adds persisted users and organizations, owner/member memberships, scoped revocable API tokens, tenant ownership and authorization on existing project/memory/search routes, deterministic Phase 1 data migration, release owner bootstrap/recovery, and minimal immutable audit events.

**Phase 2B complete.** [Organization membership administration foundation](https://github.com/JimmyMcBride/brain-cloud/issues/9) adds owner-only membership create/list/role/deactivate/reactivate operations, one-time target-member credentials, non-enumerating tenant boundaries, transactional credential revocation, final-owner concurrency protection, and membership audit events.

**Phase 2C complete.** [Project access control foundation](https://github.com/JimmyMcBride/brain-cloud/issues/12) adds direct reader/editor grants for human memberships, implicit owner access, member-creator editor grants, PostgreSQL-enforced tenant alignment, compatibility backfill, owner-only grant administration, deterministic audit events, and project authorization before memory/revision/search lookup.

**Phase 2D complete.** [Team access foundation](https://github.com/JimmyMcBride/brain-cloud/issues/14) adds reusable organization teams, soft lifecycle, retained membership links, reader/editor team project grants, strongest-access authorization, tenant-safe database constraints, and transactional audit events.

**Phase 2E complete.** [Agent identity and credential foundation](https://github.com/JimmyMcBride/brain-cloud/issues/16) adds organization-owned agent principals, revocable read-only credentials, direct reader grants, explicit authentication provenance, tenant-safe constraints, and transactional lifecycle audits.

**Phase 2F ready.** [Agent-authored memory provenance foundation](https://github.com/JimmyMcBride/brain-cloud/issues/19) adds explicit human/agent memory and audit provenance, direct agent editor grants, and scoped agent-authored immutable memory creation.

Later Phase 2 slices add invitations, interactive identity, proposals, and finer-grained access.

### Phase 3 — Complete cloud-native Brain project model

Context/memory categories, metadata, revisions, diff/restore, archive/delete, import/export, repository associations, and project relationships.

### Phase 4 — Hosted retrieval and context compilation

Full-text and semantic retrieval, filters, reranking, bounded compilation, provenance, freshness, warnings, and permission-aware indexing.

### Phase 5 — `brain-cloud-sdk-go`

Protocol models; handwritten client; auth and compatibility negotiation; project, context, memory, search, compilation, structured errors, retries, and pagination.

### Phase 6 — Brain CLI cloud mode

Server profiles, authentication, cloud projects, search, context compilation, and cloud-native workflows in the separate `brain` repository.

### Phase 7 — Hybrid synchronization

Project linking, push/pull, stable identities, cursors, offline work, conflicts, selective sync, `.brainignore`, secret warnings, and local Brain export.

### Phase 8 — Hive Mind

Personal Hive Mind, selected-project queries, custom collections, per-project retrieval, cross-project reranking, provenance, and permission preservation.

### Phase 9 — Advanced Hive Mind

Team/organization Hive Mind, patterns, duplication, dependencies, contradictions, Hive Memory, portfolio summaries, and freshness analysis.

### Phase 10 — Core module framework

Internal module interfaces and registry; enable/disable lifecycle; capabilities; configuration; permission declarations; events; module migrations; discovery; and module audit events.

General community execution waits until official internal modules validate these contracts.

### Phase 11 — Official Planning module integration

Listed now; specified by a separate Planning-module contract. High-level scope:

- migrate relevant Plan domain concepts into Brain;
- optional local, cloud, and hybrid operation;
- first-class Brain context and memory proposals from planning outcomes;
- planning permissions, APIs, and unified UI;
- transitional GitHub support;
- remove official Linear direction;
- compatibility and migration strategy for the current `plan` command.

### Phase 12 — Agent and external client platform

Agent-safe APIs, MCP, ChatGPT-compatible actions, scoped credentials, module-contributed tools, proposals, and audit.

### Phase 13 — Unified Brain Cloud web application

Core Brain and Hive surfaces, module management, constrained module UI, Planning UI when enabled, teams, agents, and administration.

### Phase 14 — Community module protocol

After official module validation: external process protocol, language-neutral SDK, installation/discovery, permission approval, compatibility, signed packages, registry direction, lifecycle, crash containment, and diagnostics.

### Phase 15 — Production self-hosting and hosted operations

Production containers, Compose, migrations, backup/restore, upgrades, workers, observability, metrics, tracing, runbooks, and hosted-service operations.

## Removed and deferred direction

Brain Cloud is not planning:

- a separate Plan Cloud server, frontend, Go SDK, identity system, or agent gateway;
- official Linear integration;
- permanent dependence on GitHub for Planning;
- arbitrary Go native plugins or unrestricted in-process third-party loading;
- a universal issue tracker, source-code host, CI replacement, deployment replacement, or every project-management workflow.

Planning remains focused on turning durable project understanding into structured, execution-ready work. Its detailed domain and migration are deferred to the dedicated Planning-module integration effort.

## Current implementation non-goals

The current implementation does not include invitations, interactive login, agent-authored writes, proposals, custom roles, deny rules, complete revision history, semantic search, context compilation, sync, Hive Mind, SDK/CLI integration, the module registry, Planning domain, external process protocol, module sandbox, module UI, or module package format.

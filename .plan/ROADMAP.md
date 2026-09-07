---
updated: "2026-09-07T15:01:19Z"
---
# Roadmap: brain-cloud

Created: 2026-07-27T17:43:26Z

## Overview

Brain Cloud hosts Brain Core plus explicitly enabled official/community modules. Planning is an optional official module—not Plan Cloud. GitHub remains transitional planning coordination; official Linear work is abandoned. See `docs/roadmap.md` for the full product capability inventory.

## Phase 0 — Repository and server foundation

**Complete.** Repository, Phoenix umbrella and LiveView shell, health/database readiness/system discovery, OpenAPI, OTP release, Docker/Compose, CI, Brain/Plan initialization, temporary GitHub planning mode, vision, architecture, and ADRs.

## Phase 1 — First Brain Cloud vertical slice

**Complete.** Create one cloud project, store and retrieve one immutable Markdown memory revision, and search it through project-scoped PostgreSQL full-text search. Includes development auth, provenance, structured errors, OpenAPI, and restart durability.

## Phase 2 — Identity and multi-tenancy

Phase 2A complete from [#5](https://github.com/JimmyMcBride/brain-cloud/issues/5): persisted users and organizations, owner/member memberships, scoped revocable API tokens, tenant ownership and authorization on existing project/memory/search routes, Phase 1 data migration, release owner bootstrap/recovery, and minimal immutable audit events.

Phase 2D is complete from [#14](https://github.com/JimmyMcBride/brain-cloud/issues/14): reusable organization teams, retained membership links, soft lifecycle, team reader/editor project grants, strongest-access authorization, tenant-safe constraints, and transactional audit events.

Phase 2E is complete from [#16](https://github.com/JimmyMcBride/brain-cloud/issues/16): first-class organization agent principals, revocable read-only credentials, and direct reader project grants without synthetic human identities.

Phase 2F is complete from [#19](https://github.com/JimmyMcBride/brain-cloud/issues/19) and merged [PR #21](https://github.com/JimmyMcBride/brain-cloud/pull/21): explicit human/agent memory and audit provenance, direct agent editor grants, and scoped agent-authored immutable memory creation.

Phase 2G is complete from [#22](https://github.com/JimmyMcBride/brain-cloud/issues/22) and merged [PR #24](https://github.com/JimmyMcBride/brain-cloud/pull/24): owner-managed, member-only invitations with one-time expiring acceptance, transactional membership and initial-credential issuance, tenant-safe constraints, linearized terminal states, and audit provenance.

Phase 2H is implemented from [#25](https://github.com/JimmyMcBride/brain-cloud/issues/25): closed-enrollment Phoenix passwordless magic-link sign-in for existing humans, tracked browser sessions, explicit active-organization selection, rehydrated LiveView authorization, global auth security events, synchronous SMTP delivery, and a minimal authenticated shell. product CRUD UI, alternate authenticators, owner invitations, proposals, and finer-grained permissions remain later slices.

Phase 2I is implemented on its work branch from [#28](https://github.com/JimmyMcBride/brain-cloud/issues/28): a minimal owner invitation panel, synchronous email send/resend with secret rotation and unchanged expiry, credential-free browser acceptance, and separate existing sign-in. Preserve all existing API contracts. Implementation awaits PR review.

## Phase 3 — Complete cloud-native project model

Context/memory categories, metadata, revisions, diff/restore, archive/delete, import/export, repositories, and project relationships.

## Phase 4 — Hosted retrieval and context compilation

Full-text/semantic retrieval, filters, reranking, bounded compilation, provenance, freshness, warnings, and permission-aware indexing.

## Phase 5 — `brain-cloud-sdk-go`

Protocol models, handwritten client, authentication, capability negotiation, projects, context, memory, search, compilation, errors, retries, and pagination.

## Phase 6 — Brain CLI cloud mode

Profiles, auth, cloud projects, search, context, and cloud-native workflows in `brain`.

## Phase 7 — Hybrid synchronization

Linking, push/pull, stable IDs, cursors, offline work, conflicts, selective sync, `.brainignore`, secret warnings, and local export.

## Phase 8 — Hive Mind

Personal Hive, selected projects, collections, cross-project retrieval/reranking, provenance, and permissions.

## Phase 9 — Advanced Hive Mind

Team/org Hive, patterns, duplication, dependencies, contradictions, Hive Memory, portfolios, and freshness.

## Phase 10 — Core module framework

Supervised official OTP application behaviours and registry, lifecycle, capabilities, configuration, permission declarations, events, migrations, discovery, and audit. No general community execution yet.

## Phase 11 — Official Planning module integration

Separate contract required. High-level direction: optional local/cloud/hybrid Planning, migrated Plan concepts, Brain context access, memory proposals, planning permissions/APIs/UI, transitional GitHub support, no official Linear integration, and compatibility for the current `plan` command.

## Phase 12 — Agent and external client platform

Agent-safe APIs, MCP, ChatGPT-compatible actions, scoped credentials, module tools, proposals, and audit.

## Phase 13 — Unified Brain Cloud web application

Core/Hive surfaces, module management, constrained module UI, Planning UI only when enabled, and administration.

## Phase 14 — Community module protocol

External process protocol, language-neutral SDK, discovery/install, permissions, compatibility, signing, registry direction, lifecycle, crash containment, and diagnostics—after official modules validate contracts.

## Phase 15 — Production self-hosting and hosted operations

Containers, Compose, migrations, backup/restore, upgrades, workers, observability, metrics, tracing, runbooks, and hosted operations.

## Explicit removed direction

- No separate Plan Cloud server, frontend, SDK, identity system, or agent gateway.
- No official Linear integration.
- No permanent GitHub dependency for Planning.
- No arbitrary Go native plugins or unrestricted third-party in-process code.
- No universal issue tracker, source host, CI replacement, or deployment replacement.

## Current non-goals

This revision does not implement Planning, migrate standalone Plan, choose an external module transport, define the final manifest, load community code, or scaffold module UI.

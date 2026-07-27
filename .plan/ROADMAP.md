# Roadmap: brain-cloud

Created: 2026-07-27T17:43:26Z

## Overview

Brain Cloud hosts Brain Core plus explicitly enabled official/community modules. Planning is an optional official module—not Plan Cloud. GitHub remains transitional planning coordination; official Linear work is abandoned. See `docs/roadmap.md` for the full product capability inventory.

## Phase 0 — Repository and server foundation

**Complete.** Repository, Go API/worker, health/readiness/system discovery, OpenAPI, Docker/Compose, CI, Brain/Plan initialization, temporary GitHub planning mode, vision, architecture, and ADRs.

## Phase 1 — First Brain Cloud vertical slice

Create one cloud project, store durable context/memory, retrieve it, and search it. Development auth, revision foundation, PostgreSQL persistence, OpenAPI expansion, and end-to-end restart tests.

## Phase 2 — Identity and multi-tenancy

Users, organizations, teams, memberships, ownership, permissions, tokens, agent credentials, tenant isolation, and audit.

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

Compiled internal module interface/registry, lifecycle, capabilities, configuration, permission declarations, events, migrations, discovery, and audit. No general community execution yet.

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

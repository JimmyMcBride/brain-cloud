# Roadmap: brain-cloud

Created: 2026-07-27T17:43:26Z

## Overview

One public protocol supports hosted and self-hosted servers. Local, cloud-native, and hybrid Brain remain equal modes. SDKs stay external; project boundaries, permissions, provenance, portability, auditable durable writes, and the Brain/Plan domain boundary remain invariant.

The expanded human-readable roadmap is in `docs/roadmap.md`. This Plan roadmap records the same full product inventory and phase ordering so planning remains self-contained.

## Complete feature inventory

### A. Deployment and server configuration

Hosted, self-hosted, localhost, Compose, single-server, multi-service; configurable base URLs; discovery, protocol/capabilities, health/readiness; no hosted-service hard coding.

### B. Identity, authentication, and authorization

Users, personal workspaces, organizations, teams and memberships; user/org projects; sessions, API/device/agent tokens, service accounts, expiration/revocation, roles/capabilities, audit. Provider-independent future password, magic link, GitHub, Google, OAuth, OIDC, SAML, enterprise SSO.

### C. Cloud-native Brain projects

Create/use without local repo; API/web knowledge; archive/restore/export/delete; repositories, metadata, relationships, tags, technologies, ownership, invitations, permissions. Stable ID, name, description, owner, visibility/status/timestamps, repositories, sync config, index status.

### D. Context and memory

Distinct context and curated memory: current state, architecture, decisions, conventions, constraints, history, summaries, custom categories, provenance, visibility, revisions. Non-Markdown storage allowed; human-readable Brain-compatible export required.

### E. Revision history

Stable document IDs; immutable/parent revisions; hashes; user/agent/device actors; time, summary, diffs, restore, deletion/conflict history. Explain what, who/what, when, why, and evidence.

### F. Search and retrieval

Single/selected/personal/team/org/custom-Hive scopes; keyword/semantic retrieval, metadata/recency/source filters, reranking, provenance/freshness. Filter unauthorized content before retrieval/model context.

### G. Context compilation

Inputs: task, scope, token budget, included/excluded categories, recency, required sources, format. Outputs: bounded selections, source/revision/freshness, rationale, contradictions, missing warnings. Never send all documents by default.

### H. Conversations and hosted chat

Project, selected projects, personal/team/org/custom Hive scopes. Retain query, scope, sources, context, response, citations, proposals, related projects. Conversation history never automatically becomes durable memory; promotion is explicit.

### I. Hybrid synchronization

Link, push/pull/two-way, offline edits, stable IDs, cursors, revision comparison, hashes, idempotency/retries, rename/delete/interruption/conflicts/resolution. Sync durable content/metadata, never SQLite/indexes. CLI uses external Go SDK.

### J. Selective synchronization

Local-only, cloud-private, project/team/org-shared policies; future `.brainignore` and pre-upload secret detection; content and project enforcement.

### K. Conflict handling

No silent overwrite. Three-way merge, unresolved conflict records, preserve both revisions, user resolution, agent-assisted proposals, auditable history.

### L. Hive Mind

Personal/team/org/custom/selected-project scopes; cross-project questions, related projects, implementations, patterns, contradictions, duplication, dependencies, comparisons, portfolios, stale knowledge, bounded context, provenance. Identity/scope → authorized projects → per-project retrieval → cross-project rerank → analysis → bounded answer. Never flatten boundaries/globalize the pool.

### M. Hive Memory

Project memory says how one project works; Hive Memory says how projects relate: shared patterns, terminology, standards, infrastructure, inconsistencies, reusable approaches, constraints, decisions. Normally proposal/review driven.

### N. Contradiction detection

Across projects, architecture, decisions, current state, project/Hive memory. Record claims, projects/revisions, dates, confidence, suggestion, optional Plan reference. Never silently choose a winner.

### O. Memory proposals and review

Proposal with rationale/evidence → authorized approve/edit/reject → auditable revision. Separate read/search/compile/propose/approve/edit/admin permissions. Agents do not directly mutate by default.

### P. Agent and integration APIs

List projects; metadata; project/Hive search; compile; read memory/source; propose/status; contradictions; scoped conversations. Initial surface is read-only plus proposals.

### Q. ChatGPT, MCP, and external clients

ChatGPT/custom GPT, MCP, Claude, IDE/CI/GitHub agents, enterprise assistants, mobile, third-party frameworks; same hosted/self-hosted contract.

### R. Brain CLI support

Future connect/disconnect/servers/status; login/logout/whoami; cloud project create/list/show/archive/export; link/unlink and sync status/push/pull/conflicts/resolve; cloud search/ask/context; Hive ask/search/projects/create/list/memory/contradictions; agent create/list/revoke. Names are directional.

### S. Brain Cloud web application

Sign-in; projects; context/memory/revisions; search; project/Hive chat; collections; proposals/review; contradictions; teams/agents/audit/admin. Frontend framework waits for future ADR.

### T. Self-hosting

Images/Compose, environment docs, migrations, admin bootstrap, health, backup/restore, upgrades, storage/search/worker config, production guidance; target `docker compose up`.

### U. Storage architecture

Interfaces around PostgreSQL, filesystem/object durable content, search/vector indexes when justified, queue/workers, optional cache. No premature managed-provider commitment.

### V. Security

TLS/at-rest encryption, token security/revocation, tenant isolation, permissions, validation, rate limits, audit, secure delete, secrets, sensitive retrieval, prompt-injection defense, agent boundaries, redaction, backup security. Checks precede retrieval.

### W. Encryption modes

Server-readable, future end-to-end encrypted, or local-only. Server-readable enables hosted search/compilation/Hive/agents; E2EE may require trusted client/user retrieval and lose hosted features. Searchable E2EE is not initial scope.

### X. Data portability

Export/import projects, project/Hive memory, metadata, revisions; hosted ↔ self-hosted ↔ local-only; Brain-compatible human-readable cloud export.

### Y. Auditability and events

Audit auth/access/search/compilation/agents/proposals/permissions/sync/conflicts/exports/deletions. Events for project, conflicts, proposals, contradictions, token use, permissions, indexing, import/export. Future webhooks, notifications, Plan Cloud, GitHub, Slack, email.

### Z. Plan Cloud integration

Brain/Hive context → Plan work → agent execution → outcomes → Brain proposals → stronger Hive. Context references, planning-time Hive, contradiction-to-work, completion-to-memory. Shared platform only after demonstrated need.

## Delivery phases

### Phase 0 — Repository and architecture foundation

Git/GitHub, Brain, Plan, GitHub source mode, Go API/worker, health/readiness/system info, OpenAPI, Docker/Compose, CI, vision, architecture, ADRs, roadmap. Current session only.

### Phase 1 — First vertical cloud slice

Goal: create one cloud project, store one durable memory, retrieve it through API, and search it. Development auth; project/document/memory creation; revisions; keyword search; PostgreSQL; OpenAPI; E2E tests. Acceptance: create/add/retrieve/search and survive restart.

### Phase 2 — Identity and multi-tenancy

Users, orgs, teams, membership, ownership, roles/capabilities, tokens/agent credentials, tenant isolation, audit.

### Phase 3 — Complete cloud-native project model

Categories, metadata, revisions/diffs/restore, archive/delete, import/export, repositories, relationships, visibility.

### Phase 4 — Search and context compilation

Full text/semantic, filters/reranking, token bounds, provenance/freshness/warnings, permission-aware indexes/retrieval.

### Phase 5 — `brain-cloud-sdk-go`

External generated protocol and handwritten client; auth/discovery/projects/memory/search/context/errors/pagination/retries/integration tests.

### Phase 6 — Brain CLI cloud mode

Profiles/base URLs, auth, cloud projects, cloud search/context; hosted default without exclusivity.

### Phase 7 — Hybrid synchronization

Linking, stable identities, push/pull/cursors/idempotency/offline/conflicts/selective sync/`.brainignore`/secret warnings/local export.

### Phase 8 — Hive Mind foundation

Personal/selected/custom scopes, per-project retrieval, cross-project reranking, provenance, consulted-project visibility, permissions.

### Phase 9 — Advanced Hive Mind

Team/org, patterns, duplication, dependencies, contradictions, Hive Memory proposals, portfolios, freshness.

### Phase 10 — Agent and external integration platform

Agent-safe APIs, MCP, ChatGPT actions, scoped tokens, proposals, limits, audit, docs.

### Phase 11 — Brain Cloud web application

Auth/dashboard/context/memory/search/project and Hive chat/review/revisions/contradictions/team and agent admin.

### Phase 12 — Production self-hosting and operations

Images/Compose/migrations/workers/backup/restore/upgrades/observability/metrics/tracing/logs/rate limits/runbooks.

### Phase 13 — Hosted service and enterprise capabilities

As justified: billing/quotas, SSO/OIDC/SAML, org policy, retention/compliance, regions, reporting.

### Phase 14 — Plan Cloud ecosystem integration

Separate Plan Cloud work: Brain context/references, Hive during planning, contradiction-to-work, completion-to-memory, shared project/repo references, unified agents.

## Initial non-goals

No full authentication, organizations/teams, semantic search/embeddings, hybrid sync, Hive Mind, ChatGPT/MCP, Brain CLI changes, SDK repository, frontend, billing, enterprise SSO, real-time collaboration, autonomous cloud agents, Plan Cloud, searchable E2EE, or multi-region deployment in Phase 0.

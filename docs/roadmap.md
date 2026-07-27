# Brain Cloud roadmap

## Principles

One public protocol serves hosted, self-hosted, local clients, integrations, and agents. Local, cloud-native, hybrid, and self-hosted operation are all first-class. SDKs stay external. Hive Mind connects projects without erasing boundaries. Durable writes are explicit and auditable; permissions precede retrieval; provenance is mandatory; data remains portable; Brain and Plan remain separate domains.

## Complete feature inventory

### A. Deployment and server configuration

- Official hosted service, self-hosting, developer localhost, Docker Compose, single-server, and scalable multi-service deployments.
- Configurable base URLs; server/protocol discovery; capability negotiation; health and readiness checks.
- Clients may conceptually run `brain cloud connect https://brain.example.com`; no official-service-only hard coding.

### B. Identity, authentication, and authorization

- Users, personal workspaces, organizations, teams, memberships, and user/org-owned projects.
- Sessions, API/device/agent tokens, service accounts, expiration, revocation, RBAC, capability permissions, and audit history.
- Provider-independent authentication supporting future password, magic link, GitHub, Google, OAuth, OIDC, SAML, and enterprise SSO.

### C. Cloud-native Brain projects

- Create and use projects without local repositories; add knowledge through API/web; archive, restore, export, delete, associate repositories, add metadata/relationships/tags/technology/ownership, invite members, and set project permissions.
- Stable ID, name, description, owner, visibility, status, timestamps, repository associations, sync configuration, and index status.

### D. Context and memory

- Keep context distinct from curated durable memory.
- Current state, architecture, decisions, conventions, constraints, history, summaries, custom categories, sources/provenance, visibility, and revisions.
- Storage need not originate as Markdown; durable content exports to human-readable Brain-compatible form.

### E. Revision history

- Stable document IDs; immutable and parent revisions; hashes; user, agent, and device actors; timestamps; summaries; diffs; restore; deletion/conflict history.
- Answer what changed, who/what changed it, when, why, and which evidence supported it.

### F. Search and retrieval

- Single/selected/personal/team/organization project scopes and custom Hive collections.
- Keyword/semantic search, filters, recency, source types, permission-aware retrieval, reranking, provenance, and freshness.
- Filter unauthorized content before retrieval; never place it in model context.

### G. Context compilation

- Inputs: task, project scope, token budget, included/excluded categories, recency, required sources, and format.
- Outputs: bounded context, source/revision/freshness references, selection rationale, contradictions, and missing-information warnings.
- Never send every document from every project by default.

### H. Conversations and hosted chat

- Project, selected-project, personal/team/organization Hive, and custom-collection scopes.
- Retain query, scope, retrieved sources, compiled context, response, citations, proposals, and related projects.
- Conversation history never automatically becomes durable memory; users explicitly promote useful material.

### I. Hybrid synchronization

- Linking, push, pull, two-way sync, offline edits, stable IDs, cursors, revision comparison, hashes, idempotent/retry-safe operations, renames, deletions, interruption, conflicts, and explicit resolution.
- Synchronize durable content and metadata—not local SQLite or derived indexes. Brain CLI consumes the external Go SDK.

### J. Selective synchronization

- Visibility policies: local only, cloud private, project shared, team shared, organization shared.
- Brain CLI will support `.brainignore` and pre-upload secret detection. Server enforces content and project access controls.

### K. Conflict handling

- Never silently overwrite divergent durable content.
- Safe three-way merges, unresolved conflict records, both revisions, user resolution, agent-assisted proposals, and auditable resolution history.

### L. Hive Mind

- Personal, team, organization, custom collection, and selected-project scopes.
- Cross-project search/questions; related projects; repeated implementations; patterns; contradictions; duplicated work; dependencies; comparisons; portfolio summaries; stale knowledge; bounded compilation; full provenance.
- Pipeline: question → identity/scope → authorized projects → per-project retrieval → cross-project rerank → relationship/contradiction analysis → bounded context → sourced answer.
- Never flatten project boundaries or use one undifferentiated global pool.

### M. Hive Memory

- Project memory says how one project works; Hive Memory says how projects relate.
- Shared patterns, terminology, standards, infrastructure, inconsistencies, reusable approaches, constraints, and cross-project decisions.
- Changes normally use proposals and review.

### N. Contradiction detection

- Compare projects, architecture, decisions, current state, project memory, and Hive Memory.
- Record claims, source projects/revisions, update dates, confidence, suggested resolution, and optional Plan reference.
- Never silently select a winner.

### O. Memory proposals and review

- User/agent proposes with rationale/evidence; authorized reviewer approves, edits, or rejects; acceptance creates an auditable revision.
- Separate read, search, compile, propose, approve, direct-edit, and administer permissions. Agents do not mutate durable memory by default.

### P. Agent and integration APIs

- List projects; read metadata/memory/sources; project/Hive search; compile context; propose memory; inspect proposals/contradictions; create scoped conversations.
- Initial agent surface is read-only plus proposals; direct mutation stays restricted.

### Q. ChatGPT, MCP, and external clients

- ChatGPT actions, custom GPTs, MCP, Claude, IDE/CI/GitHub agents, enterprise assistants, mobile, and third-party frameworks.
- One contract works against hosted and self-hosted servers.

### R. Brain CLI support

- Server profiles: `cloud connect|disconnect|servers|status`; identity: `login|logout|whoami`.
- Cloud projects: `project create|list|show|archive|export`; hybrid: `link|unlink`, `sync [status|push|pull|conflicts|resolve]`.
- Retrieval: `cloud search|ask|context`; Hive: `hive ask|search|projects|create|list|memory|contradictions`; agents: `agent create|list|revoke`.
- Names are directional, not final API commitments.

### S. Brain Cloud web application

- Sign-in; project/context/memory/revision management; search; project/Hive chat; collections; proposals/review; contradictions; teams; agents; audit; server administration.
- Frontend framework waits for a future ADR; Phase 0 does not scaffold one.

### T. Self-hosting

- Images, Compose, environment docs, migrations, admin bootstrap, health, backup/restore, upgrades, storage/search/worker configuration, and production guidance.
- Target development experience approaches `docker compose up`.

### U. Storage architecture

- Interfaces shield PostgreSQL transactional data, filesystem/object content, search/vector indexes where justified, queue/workers, and optional cache.
- Avoid premature managed-provider commitments; preserve self-hosting.

### V. Security

- TLS, encryption at rest, secure/revocable tokens, tenant isolation, authorization, validation, rate limits, audit, secure deletion, secret detection, sensitive retrieval, prompt-injection resistance, agent boundaries, redaction, and backup security.
- Security checks happen before retrieval, not only before display.

### W. Encryption modes

- Future projects may be server-readable, end-to-end encrypted, or local-only.
- Server-readable enables hosted search, compilation, Hive, and agents. End-to-end encrypted mode may require trusted client/user retrieval and lose hosted features.
- Searchable end-to-end encryption is not an initial requirement.

### X. Data portability

- Export/import projects, project/Hive memory, metadata, and revisions.
- Move hosted ↔ self-hosted and return to local-only Brain.
- Export cloud-native projects as Brain-compatible human-readable directories.

### Y. Auditability and events

- Audit auth, access, search, compilation, agent use, proposals/approvals, permissions, sync/conflict resolution, exports, and deletions.
- Events: project updates, conflicts, proposal lifecycle, contradictions, agent-token use, permission changes, indexing, import/export.
- Future consumers: webhooks, notifications, Plan Cloud, GitHub, Slack, and email.

### Z. Plan Cloud integration

- Brain/Hive context → Plan Cloud work → agent execution → recorded outcomes → Brain memory proposals → stronger Hive knowledge.
- Support Brain references, planning-time Hive queries, contradiction-to-work, and completion-to-memory.
- Shared identity/org/project/repository/agent/audit primitives may emerge later; do not extract a shared platform prematurely.

## Delivery phases

### Phase 0 — Repository and architecture foundation

Deliver Git/GitHub repositories; Brain and Plan initialization; Plan GitHub mode; Go module; API/worker binaries; health, readiness, system info; OpenAPI; Docker/Compose; CI; vision; architecture; ADRs; full roadmap. **Current session implements this phase only.**

### Phase 1 — First vertical cloud slice

Goal: create one cloud project, store one durable memory, retrieve it through the API, and search it.

Deliver development auth, project and durable document/memory creation, basic revisions and keyword search, PostgreSQL persistence, OpenAPI expansion, and end-to-end tests. Acceptance: a client creates a project, adds/retrieves/searches memory, and data survives restart.

### Phase 2 — Identity and multi-tenancy

Users, organizations, teams, memberships, ownership, roles/capabilities, API tokens, agent credentials, tenant isolation, and audit foundation.

### Phase 3 — Complete cloud-native project model

Context/memory categories, metadata, revisions/diffs/restore, archive/delete, import/export, repository associations, relationships, and visibility.

### Phase 4 — Search and context compilation

Full text and semantic retrieval, filters, reranking, token-bounded compilation, provenance, freshness, missing-context warnings, and permission-aware indexing/retrieval.

### Phase 5 — `brain-cloud-sdk-go`

External repository with generated protocol, handwritten client, auth/discovery, projects/memory/search/context, structured errors, pagination/retries, and server integration tests.

### Phase 6 — Brain CLI cloud mode

Separate Brain repository: profiles/base URLs, login/logout, cloud project operations, search/context, and hosted default without exclusivity.

### Phase 7 — Hybrid synchronization

Server/SDK/CLI linking, stable identities, push/pull, cursors, idempotency, offline work, conflicts/resolution, selective sync, `.brainignore`, secret warnings, and local-format export.

### Phase 8 — Hive Mind foundation

Personal Hive, selected projects, custom collections, per-project retrieval, cross-project reranking, provenance, consultation visibility, and permission preservation.

### Phase 9 — Advanced Hive Mind

Team/org Hive, patterns, duplication, dependencies, contradictions, Hive Memory proposals, portfolios, and freshness analysis.

### Phase 10 — Agent and external integration platform

Agent-safe APIs, MCP, ChatGPT-compatible actions, scoped tokens, proposals, rate limits, audit, and integration docs.

### Phase 11 — Brain Cloud web application

Authentication, dashboard, context/memory, search/chat/Hive, review/revisions/contradictions, and team/agent administration.

### Phase 12 — Production self-hosting and operations

Production images/Compose, migrations, workers, backup/restore, upgrades, observability/metrics/tracing/logging, rate limits, and runbooks.

### Phase 13 — Hosted service and enterprise capabilities

As justified: billing/quotas, SSO/OIDC/SAML, organization policy, retention/compliance, regional deployment, and admin reporting.

### Phase 14 — Plan Cloud ecosystem integration

Separate Plan Cloud work: Brain context/references in specs, Hive questions, contradiction-to-work, completion-to-memory, shared project/repository references, and unified agent experience.

## Initial non-goals

Phase 0 does not implement full auth, organizations/teams, semantic search/embeddings, hybrid sync, Hive Mind, ChatGPT/MCP, Brain CLI changes, SDK repositories, frontend, billing, enterprise SSO, real-time collaboration, autonomous cloud agents, Plan Cloud, searchable end-to-end encryption, or multi-region deployment.

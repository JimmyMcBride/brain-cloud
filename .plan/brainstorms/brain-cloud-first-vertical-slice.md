---
created_at: "2026-07-27T17:50:37Z"
project: brain-cloud
slug: brain-cloud-first-vertical-slice
status: active
title: Brain Cloud first vertical slice
type: brainstorm
updated_at: "2026-07-27T17:52:34Z"
---

# Brainstorm: Brain Cloud first vertical slice

Started: 2026-07-27T17:50:37Z

## Focus Question

What is the smallest persistent Brain Cloud API slice that proves cloud-native project memory from creation through retrieval and keyword search?
## Desired Outcome

A client creates one cloud project, stores one durable memory, retrieves it, searches it by keyword, and observes the data survive an API restart.
## Vision

Prove Brain Cloud as a real durable knowledge service through one complete, intentionally narrow path rather than broad placeholder architecture.

## Supporting Material

- `docs/product-vision.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `openapi/brain-cloud-v1.yaml`
- `docs/adr/0001-brain-cloud-repository-boundaries.md` through `0006-plan-cloud-remains-a-separate-domain.md`

## Constraints

- One cloud project and one durable memory path only.
- PostgreSQL is the source of truth and restart durability is required.
- HTTP contract remains versioned under /v1 and OpenAPI changes with implementation.
- Use development authentication only; preserve future tenant and permission seams.
- No organizations, teams, semantic search, sync, Hive Mind, SDK, CLI, MCP, or frontend work.

## Open Questions

- What minimal development-auth identity is sufficient without hardening a throwaway model into the contract?
- Should keyword search use PostgreSQL full-text search immediately or a simpler indexed text query for the slice?
- Which idempotency guarantees belong in Phase 1 create operations versus the later sync phase?
- What exact export-neutral content representation best preserves future Brain compatibility?
## Ideas

## Raw Notes

Vision: prove Brain Cloud as a real durable knowledge service through one complete, intentionally narrow path rather than broad placeholder architecture.

Supporting material: docs/product-vision.md, docs/architecture.md, docs/roadmap.md, openapi/brain-cloud-v1.yaml, and ADRs 0001-0006.

API operations: POST /v1/projects; POST /v1/projects/{project_id}/memory; GET /v1/projects/{project_id}/memory/{memory_id}; GET /v1/projects/{project_id}/search?q=...; retain GET /v1/system/info.

Persistence model: PostgreSQL projects, stable document/memory identities, immutable first revision with content hash/actor/timestamps, migration-owned schema, and project-scoped keyword indexing.

Testing strategy: unit-test domain/handlers, integration-test repositories against PostgreSQL, and run an end-to-end create-store-retrieve-search flow with process restart before the final retrieval.

Explicit exclusions: production authentication, organizations, teams, fine-grained authorization, semantic/vector search, sync, Hive Mind, SDK/CLI work, MCP/ChatGPT, web UI, queue/worker jobs, proposals, collaboration, and generalized platform extraction.

Acceptance criteria: client creates a project; client adds durable memory; client retrieves exact stored memory with revision metadata; project-scoped keyword search returns it with provenance; invalid/missing resources return structured errors; restart preserves all data; OpenAPI matches behavior; tests, vet, and builds pass.

## Refinement

### Problem

Brain Cloud has an architectural foundation but no proven persistent product path. Phase 1 must validate the smallest end-to-end cloud knowledge loop without pulling identity, sync, Hive Mind, or frontend work forward.

### User / Value

A Brain client developer can create a cloud-native project, store one durable memory, retrieve it, and find it through keyword search. This proves the public API, persistence, revision, and search seams before broader platform investment.

### Appetite

One small vertical slice: schema and migrations, minimal domain/storage interfaces, five or fewer API operations, keyword search, and end-to-end tests. Stop once acceptance criteria pass; defer production identity and generalized infrastructure.

### Remaining Open Questions

- What minimal development-auth identity is sufficient without hardening a throwaway model into the contract?
- Should keyword search use PostgreSQL full-text search immediately or a simpler indexed text query for the slice?
- Which idempotency guarantees belong in Phase 1 create operations versus the later sync phase?
- What exact export-neutral content representation best preserves future Brain compatibility?

### Candidate Approaches

- Build a thin domain slice with projects, documents/memory revisions, and PostgreSQL repositories behind narrow interfaces.
- Expose POST /v1/projects, POST /v1/projects/{project_id}/memory, GET /v1/projects/{project_id}/memory/{memory_id}, and GET /v1/projects/{project_id}/search?q=... plus existing system discovery.
- Use SQL migrations, database-generated persistence timestamps, stable opaque IDs, immutable first revisions, and PostgreSQL text search scoped by project.
- Test handlers with fakes, repositories against PostgreSQL, and the complete create-store-retrieve-search path including service restart durability.
- Keep OpenAPI and structured errors aligned with each implemented operation.

### Decision Snapshot

Keep Phase 1 as one spec and one vertical slice. Use PostgreSQL-backed project and memory/revision repositories, four new /v1 operations, project-scoped keyword search, development-only identity, structured errors, synchronized OpenAPI, and restart-durability end-to-end tests. Defer every cross-project, production identity, sync, agent, and UI concern.

## Challenge

### Rabbit Holes

- Designing complete identity, authorization, sync, or revision systems before one path works.
- Creating generic repositories, event buses, queues, or provider abstractions without two concrete consumers.
- Adding semantic search or embeddings when keyword search proves the persistence/retrieval seam.
- Generating SDKs before the API shape is validated end to end.

### No-Gos

- No production authentication or multi-tenancy.
- No organizations, teams, sync, Hive Mind, proposals, agents, SDK/CLI changes, MCP, ChatGPT, or frontend.
- No derived infrastructure beyond PostgreSQL-backed keyword search.
- No silent loss of revision metadata or restart durability.

### Assumptions

- PostgreSQL is available for development and integration tests.
- A fixed development actor can establish ownership/provenance without defining production auth.
- Simple project-scoped PostgreSQL text search is sufficient for Phase 1 acceptance.
- One immutable initial memory revision is enough to prove the future revision seam.

### Likely Overengineering

Abstracting every future storage/search/auth provider, modeling the full revision graph, or introducing asynchronous indexing. Phase 1 needs narrow interfaces at domain boundaries, synchronous writes/search, and only schema elements exercised by acceptance tests.

### Simpler Alternative

One API process, one PostgreSQL database, one migration set, one fixed development actor, four new endpoints, synchronous project-scoped keyword search, and one restart-durability end-to-end test. Add no other service or product surface.

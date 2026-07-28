---
created_at: "2026-07-27T17:50:37Z"
project: brain-cloud
slug: brain-cloud-first-vertical-slice
status: active
title: Brain Cloud first vertical slice
type: brainstorm
updated_at: "2026-07-28T04:47:12Z"
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
- `docs/adr/0001-brain-cloud-repository-boundaries.md` through `0012-github-planning-support-is-transitional-and-optional.md`; ADR 0006 is historical and superseded by ADRs 0007 and 0010.

## Constraints

- One cloud project and one durable memory path only.
- PostgreSQL is the source of truth and restart durability is required.
- HTTP contract remains versioned under /v1 and OpenAPI changes with implementation.
- Use development authentication only; preserve future tenant and permission seams.
- No organizations, teams, semantic search, sync, Hive Mind, SDK, CLI, MCP, or frontend work.

## Resolved Decisions

- Development authentication uses one bearer token from `DEV_API_TOKEN` and one
  principal UUID from `DEV_ACTOR_ID`, with no user or token tables.
- Search uses synchronous PostgreSQL full-text search with the language-neutral
  `simple` configuration and a GIN index.
- Revision content is `title`, UTF-8 `content`, and explicit `content_type`;
  Phase 1 accepts only `text/markdown`.
- Create operations generate server-side UUIDs and are not idempotent in Phase
  1. Retry/idempotency contracts remain deferred to agent and sync phases.

## Ideas

- The approved implementation contract is captured in the Promotion map below.
## Raw Notes

Vision: prove Brain Cloud as a real durable knowledge service through one complete, intentionally narrow path rather than broad placeholder architecture.

Supporting material: docs/product-vision.md, docs/architecture.md, docs/roadmap.md, openapi/brain-cloud-v1.yaml, and ADRs 0001-0006.

API operations: POST /v1/projects; POST
/v1/projects/{project_id}/memories; GET
/v1/projects/{project_id}/memories/{memory_id}; GET
/v1/projects/{project_id}/search?q=...; retain GET /v1/system/info.

Persistence model: PostgreSQL projects, stable document/memory identities, immutable first revision with content hash/actor/timestamps, migration-owned schema, and project-scoped keyword indexing.

Testing strategy: test Phoenix contexts and controllers against Ecto's SQL
sandbox, then run an end-to-end create-store-retrieve-search flow with an API
restart before the final retrieval and search.

Explicit exclusions: production authentication, organizations, teams, fine-grained authorization, semantic/vector search, sync, Hive Mind, SDK/CLI work, MCP/ChatGPT, web UI, queue/worker jobs, proposals, collaboration, and generalized platform extraction.

Acceptance criteria: client creates a project; client adds durable memory; client
retrieves exact stored memory with revision metadata; project-scoped keyword
search returns it with provenance; invalid/missing resources return structured
errors; restart preserves all data; OpenAPI matches behavior; Mix checks and
container builds pass.

## Refinement

### Problem

Brain Cloud has an architectural foundation but no proven persistent product path. Phase 1 must validate the smallest end-to-end cloud knowledge loop without pulling identity, sync, Hive Mind, or frontend work forward.

### User / Value

A Brain client developer can create a cloud-native project, store one durable memory, retrieve it, and find it through keyword search. This proves the public API, persistence, revision, and search seams before broader platform investment.

### Appetite

One small vertical slice: schema and migrations, minimal domain/storage interfaces, five or fewer API operations, keyword search, and end-to-end tests. Stop once acceptance criteria pass; defer production identity and generalized infrastructure.

### Resolved Decisions

- Use a fixed development bearer token and actor UUID without persistence.
- Use PostgreSQL full-text search rather than `ILIKE`.
- Add no Phase 1 idempotency guarantee.
- Store UTF-8 Markdown in an explicitly typed immutable revision.

### Candidate Approaches

- Build a thin Phoenix context slice with `BrainCloud.Projects` and
  `BrainCloud.Memories`; use Ecto directly without generic repository/provider
  abstractions.
- Expose POST /v1/projects, POST /v1/projects/{project_id}/memories, GET
  /v1/projects/{project_id}/memories/{memory_id}, and GET
  /v1/projects/{project_id}/search?q=... plus existing system discovery.
- Use SQL migrations, database-generated persistence timestamps, stable opaque IDs, immutable first revisions, and PostgreSQL text search scoped by project.
- Test handlers with fakes, repositories against PostgreSQL, and the complete create-store-retrieve-search path including service restart durability.
- Keep OpenAPI and structured errors aligned with each implemented operation.

### Decision Snapshot

Keep Phase 1 as one spec and one vertical slice. Protect four new `/v1`
operations with a temporary bearer-token plug. Use two focused Phoenix contexts,
three PostgreSQL tables, an immutable first revision, SHA-256 content hashes,
actor provenance, project-scoped full-text search, structured errors,
synchronized OpenAPI, and restart-durability end-to-end tests. Preserve existing
operational endpoints and defer every cross-project, production identity, sync,
agent, module, Planning, and UI concern.

## Promotion map

### Spec 1 — Brain Cloud first vertical slice

Problem:

Brain Cloud has an architectural foundation but no proven persistent product
path. Phase 1 must validate the smallest end-to-end cloud knowledge loop without
pulling production identity, sync, Hive Mind, modules, Planning, or frontend work
forward.

Scope:

- Add `BrainCloud.Projects` and `BrainCloud.Memories` contexts in the core app;
  use Ecto directly and add no generic repository or provider abstraction.
- Add `projects`, `memories`, and `memory_revisions` tables with binary UUID
  primary keys, foreign keys, timestamps, a unique `(memory_id,
  revision_number)` constraint, and transactional memory-plus-revision creation.
- Store project `name` and creator actor UUID. Store revision number `1`, title,
  UTF-8 Markdown content, `content_type: "text/markdown"`, lowercase hexadecimal
  SHA-256 of the exact content bytes, actor UUID, and creation timestamp.
- Trim project names and memory titles; require project names of 1–120
  characters, titles of 1–200 characters, exact untrimmed content of 1 byte–1
  MiB, and trimmed search queries of 1–256 characters.
- Add a generated `tsvector` over revision title/content using PostgreSQL's
  `simple` configuration and a GIN index. Search synchronously, scope by project
  before ranking, and add no external search service or background indexing.
- Add a web authentication plug requiring `Authorization: Bearer <token>` on
  the new product routes only. Read `DEV_API_TOKEN` and UUID `DEV_ACTOR_ID` from
  runtime configuration, use deterministic development/test values, compare the
  secret safely, and assign the actor UUID for provenance.
- Keep `/`, `/healthz`, `/readyz`, and `/v1/system/info` public.
- Add `POST /v1/projects` with request `{"name": string}` and a `201` project
  response.
- Add `POST /v1/projects/{project_id}/memories` with request `{"title": string,
  "content": string, "content_type": "text/markdown"}` and a `201` memory
  response containing immutable revision `1`.
- Add `GET /v1/projects/{project_id}/memories/{memory_id}` returning the memory
  identity and revision `1`.
- Add `GET /v1/projects/{project_id}/search?q=...` returning
  `{"results": [...]}`. Each result includes memory/revision IDs, revision
  number, title, content type/hash, plain-text excerpt, rank, actor UUID, and
  revision timestamp.
- Use top-level `project`, `memory`, and `results` response envelopes, snake_case
  JSON fields, and ISO-8601 UTC timestamps.
- Return `{"error": {"code": string, "message": string, "details": object}}`
  for `401 unauthorized`, `404 project_not_found`/`memory_not_found`, and `422
  validation_failed`; expose no database or exception details.
- Add `projects.create`, `memory.write`, `memory.read`, and `search.keyword` to
  system capabilities while retaining `system.info` and `modules: []`.
- Update OpenAPI, README/self-hosting configuration, Compose development
  settings, and durable Brain context for the implemented contract.
- Generate server-side IDs. Repeated POST requests may create distinct
  resources; do not add idempotency keys in Phase 1.
- Add no list/update/delete/history API, production identity/authorization,
  users/orgs/teams, audit log, pagination, semantic/vector search, context
  compilation, sync, Hive Mind, SDK/CLI/MCP work, jobs, modules/Planning, or
  LiveView product UI.

Acceptance criteria:

- Existing public root, health, readiness, and system-info behavior remains compatible except for the explicitly expanded capability list.
- Missing, malformed, or incorrect bearer credentials cannot enter any Phase 1 controller and return the exact structured `401` response.
- An authenticated client can create a project and receives a server-generated project UUID, configured creator actor UUID, name, and timestamps.
- An authenticated client can create one memory whose identity and immutable revision `1` are committed atomically under the requested project.
- The stored revision returns the exact title/content/content type, the expected SHA-256 content hash, configured actor UUID, revision number, and timestamp.
- Project names, memory titles/content/content type, and search queries enforce the documented Phase 1 limits without normalizing stored Markdown content.
- A memory cannot be retrieved through a different project ID, and search never returns results from another project.
- Keyword search uses the indexed PostgreSQL `simple` vector, rejects a blank query, returns an empty list for no matches, and includes result provenance.
- Missing projects/memories and invalid names, titles, content, content type, or query values return the documented structured errors.
- OpenAPI defines bearer security, all four operations, exact schemas, errors, and examples; implementation and specification agree.
- A Compose flow creates a project and memory, retrieves and searches it, restarts only the API container, and then retrieves/searches the same IDs while PostgreSQL remains running.
- PostgreSQL unavailability still changes readiness to `503` without changing process health, and readiness recovers when PostgreSQL returns.

Verification:

- Context/schema tests cover changesets, foreign/unique constraints, transactional memory/revision creation, exact content hashing, project scoping, search ranking/provenance, blank/no-match queries, and failures.
- Plug/controller tests cover authentication, four exact success responses, structured `401`/`404`/`422` errors, capability discovery, and cross-project isolation against the SQL sandbox.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Build the non-root production image and run Compose create/retrieve/search, API-restart durability, and PostgreSQL outage/recovery smoke tests.
- Review the OpenAPI diff and run `brain context audit`, `plan check`, `git diff --check`, and `brain session finish`.

Dependencies: none.

Readiness: approved and ready for execution.

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

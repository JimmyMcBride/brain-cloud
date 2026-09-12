---
created_at: "2026-09-09T04:20:00Z"
project: brain-cloud
slug: memory-discovery-foundation
status: active
title: Memory discovery foundation
type: brainstorm
updated: "2026-09-12T04:50:41Z"
updated_at: "2026-09-12T02:45:00Z"
---
# Brainstorm: Memory discovery foundation

Started: 2026-09-09T04:20:00Z

## Focus Question

What is the smallest Phase 3B API slice that lets authorized humans and agents enumerate memories inside a discovered project without coupling discovery to search terms or prematurely designing revision mutation, archive, metadata, or UI?
## Desired Outcome

An authorized client can move from an accessible project to a stable, useful memory inventory, then fetch full content through the existing detail endpoint.

## Vision

Project discovery should lead naturally into memory discovery. Humans and agents browse compact current-revision summaries without guessing search terms, loading full content for every row, or gaining access beyond their existing `memory.read` scope and project grant.

## Supporting Material

- Canonical Phase 3A spec [#31](https://github.com/JimmyMcBride/brain-cloud/issues/31) and merged implementation PR [#34](https://github.com/JimmyMcBride/brain-cloud/pull/34).
- `apps/brain_cloud/lib/brain_cloud/memories.ex`: existing create, detail, search, authorization, and excerpt behavior.
- `apps/brain_cloud_web/lib/brain_cloud_web/api_json.ex`: existing full memory and revision projections.
- `apps/brain_cloud_web/lib/brain_cloud_web/project_cursor.ex`: strict endpoint-specific cursor precedent.
- `openapi/brain-cloud-v1.yaml`: existing memory create/detail/search contracts.

## Constraints

- Use existing bearer authentication, memory.read scope, and reader/editor project authorization; browser cookies remain insufficient.
- Authorize the project before loading memory or revision data and preserve concealed project/memory failures.
- List a compact current-revision summary without full content so page cost remains bounded; existing detail remains the content fetch.
- Use deterministic keyset pagination with strict opaque cursors, no totals, and fresh access checks per request.
- Avoid credential backfills and avoid business-data migration unless query-plan evidence requires an index.
- Exclude revision creation/history/diff/restore, memory update/archive/delete, categories, custom metadata, import/export, UI, SDK, and CLI.

## Open Questions

- Which exact summary fields give useful browsing without returning full content or inventing mutable metadata; should a bounded plain-text excerpt be included?
- Should pagination anchor on immutable memory inserted_at plus UUID, keeping traversal stable when later revisions change current-revision summaries?
- Should the query define “current revision” now as highest revision_number even though only revision 1 exists, or preserve the current single-revision assumption until revision authoring lands?
- What exact validation envelope and cursor encoding should align with project discovery without prematurely creating a generic paginator?
## Ideas

- Add one bearer-only GET /v1/projects/{project_id}/memories collection route using existing memory.read plus reader/editor project access.
- Return existing memory identity and current revision fields with bounded stable keyset pagination; no totals, new metadata, or revision history.
- Preserve project-first concealment, fresh authorization, exact existing detail/search semantics, and no credential backfill.
## Raw Notes

## Refinement

### Problem

Project discovery now exposes accessible projects, but clients still cannot browse the memories inside one. They must already know a memory ID or invent a search term, leaving the basic discovery path incomplete.

### User / Value

Authorized human and agent clients can move from project discovery to a deterministic inventory of memories, then use existing detail or search operations without guessing identifiers or queries.

### Appetite

One small Phase 3B spec and implementation PR: one collection endpoint, one compact response shape, one cursor version, focused index only if measured, tests/OpenAPI/docs/smoke. Stop before any mutation or full revision-history design.

### Remaining Open Questions

- Which exact summary fields give useful browsing without returning full content or inventing mutable metadata; should a bounded plain-text excerpt be included?
- Should pagination anchor on immutable memory inserted_at plus UUID, keeping traversal stable when later revisions change current-revision summaries?
- Should the query define “current revision” now as highest revision_number even though only revision 1 exists, or preserve the current single-revision assumption until revision authoring lands?
- What exact validation envelope and cursor encoding should align with project discovery without prematurely creating a generic paginator?

### Candidate Approaches

- Recommended: compact memory summary containing memory identity/timestamps plus latest revision identity, number, title, content type/hash, actor provenance, revision timestamp, and bounded excerpt; paginate by memory inserted_at/UUID.
- Simpler but heavy: reuse the full existing memory envelope, including content, for every list row; avoids a new projection but makes page cost content-sized.
- Smaller but weak: return only memory IDs/timestamps and require one detail request per row; bounded payload but creates an N+1 client workflow and cannot support a useful inventory.

### Decision Snapshot

Proceed with one GET memory collection endpoint. Reuse memory.read and existing project reader/editor authorization. Return compact latest-revision summaries without full content, including a bounded plain-text excerpt; order and cursor by immutable memory inserted_at plus UUID. Define latest as highest revision_number for forward compatibility, but add no revision mutation/history surface. Mirror project discovery validation and cursor rules through a memory-specific helper, not a generic pagination framework. Measure before adding an index.

## Challenge

### Rabbit Holes

- Designing mutable memory metadata, categories, tags, archive state, or complete revision APIs to make the list richer.
- Extracting a generic cursor/pagination framework after only two endpoints.
- Returning full content in collection rows and hiding unbounded response cost behind a page limit.
- Adding totals, offset pagination, snapshot guarantees, signed cursors, or cursor persistence.
- Building browser UI, SDK/CLI support, Planning integration, or asynchronous indexing in this slice.

### No-Gos

- No new write endpoint or change to existing memory creation/detail/search wire contracts.
- No weakening of memory.read or project reader/editor authorization and no browser-cookie API access.
- No full memory content, cross-project records, inaccessible counts, or authorization data in list responses/cursors.
- No credential, invitation, memory, or audit backfill.
- No new read audit events or durable mutation from listing.

### Assumptions

- Existing memory.read means both discovery and detail content access; no separate memory-list scope is needed.
- Memory inserted_at and UUID are immutable and form a stable deterministic pagination tuple.
- The highest revision_number is the current revision once later revision writes exist.
- A compact excerpt can reuse the existing deterministic search excerpt rules without creating stored data.
- Project authorization freshness remains sufficient for membership, team, agent, and credential lifecycle changes.

### Likely Overengineering

A reusable pagination DSL, current-revision materialized view, stored excerpt column, revision status model, or generalized collection envelope would exceed one read endpoint. Keep one query, one summary projector, and one memory cursor.

### Simpler Alternative

Add only GET /v1/projects/{project_id}/memories with existing auth. Return bounded compact summaries for the latest revision, ordered by memory creation tuple with a strict v1 cursor. Reuse existing error, excerpt, timestamp, and no-store conventions. Measure the query; add only the precise index proven necessary.

## Risks and Mitigations

Full content makes page limits misleading: return only a deterministic 240-character plain-text excerpt and metadata. Later revisions could reorder pages: paginate by immutable memory creation time and UUID, not revision time. Latest-revision joins could duplicate memories: select exactly one highest-numbered revision per memory before limit-plus-one pagination. Inaccessible project data could leak through validation or counts: authenticate, require scope, authorize the project, then validate list inputs and query; return no totals. Cursor reuse grants nothing because every page performs current project authorization.

## Promotion map

### Spec 1 — Memory discovery foundation

Problem:

Clients can now discover accessible projects but cannot enumerate memories inside one without already knowing a memory ID or supplying a search term. Add the smallest permission-safe memory inventory surface as Phase 3B.

Scope:

- Add bearer-only `GET /v1/projects/{project_id}/memories`. Reuse the existing `memory.read` scope and reader/editor project authorization for owners, members through direct or active-team grants, and agents through direct grants. Add no scope, capability, credential, invitation, or audit-row backfill. Browser cookies remain insufficient for `/v1`.
- Preserve project-first concealment and freshness. Error precedence is authenticate, require `memory.read`, authorize the project from current PostgreSQL state, then validate pagination. Missing/invalid/revoked credentials use existing `401 unauthorized`; missing scope uses existing `403 forbidden`; malformed, foreign, or inaccessible projects use existing `404 project_not_found` even when pagination is also invalid. Project access changes committed before a subsequent request affect that request. Requests already in flight may use their read snapshot.
- Return `200 {"memories":[<summary>],"next_cursor":<string-or-null>}` with `Cache-Control: no-store`. Empty results use an empty array and null cursor. No totals. Unknown unrelated query parameters are ignored.
- Each summary has exactly `id`, `project_id`, `inserted_at`, `updated_at`, and `revision`. The nested latest-revision summary has exactly `id`, `memory_id`, `revision_number`, `title`, `content_type`, `content_hash`, `excerpt`, `actor_type`, `actor_id`, and `inserted_at`. It excludes full `content`. Timestamp, actor, hash, and content-type semantics match existing detail/search responses. `excerpt` reuses the existing deterministic Markdown-to-plain-text normalization and 240-character bound.
- Define latest revision as the row with greatest `revision_number` for the memory. Select exactly one latest revision in PostgreSQL before serialization; do not preload all history. This definition is forward-compatible but exposes no revision creation, history, diff, or restore operation. Preserve the existing revision-1 write invariant: do not relax `MemoryRevision.changeset/2` or add a revision-writing path. Multi-revision coverage must use test-only database fixtures.
- List parameters mirror project discovery: `limit` defaults to 20 and accepts only a supplied scalar decimal integer from 1 through 100; `cursor` is optional. Empty, malformed, or non-scalar values return existing `422 validation_failed` with `details.limit = ["must be an integer between 1 and 100"]` and/or `details.cursor = ["is invalid"]`, including both keys when both inputs are invalid.
- Order ascending by immutable memory `inserted_at` and UUID. Filter to the already-authorized project, select one latest revision per memory, then take `limit + 1`. Return at most `limit`; emit the last returned memory cursor only when another authorized row exists. Cursor anchors need not remain present. Concurrent inserts behind the cursor may be missed until traversal restarts; no snapshot-export guarantee.
- Cursor v1 is an unpadded base64url UTF-8 JSON object with exactly `v: 1`, `inserted_at` as UTC RFC3339 with six fractional digits, and `id` as canonical lowercase UUID. Enforce scalar input and a 512-byte encoded maximum before safe JSON decode, exact keys/types/version/time/UUID, and no Erlang term decoding. Cursor is an unsigned position, never authorization, project identity, or persisted state. Use a memory-specific helper; do not extract a generic pagination framework.
- Keep query and latest-revision selection in `brain_cloud`; keep controller, cursor decoding, and JSON projection in `brain_cloud_web`. Add no logical data-model change. Add a reversible migration that replaces the existing single-column memories `project_id` index with `(project_id, inserted_at, id)`, whose leading column preserves project lookup support while its full order supports keyset traversal. Existing `(memory_id, revision_number)` uniqueness supports backward latest-revision lookup. Confirm both access paths with representative `EXPLAIN ANALYZE` output.
- Update OpenAPI, README, architecture/security/self-hosting/workflow/roadmap, Brain context, and release smoke. Preserve existing project discovery, memory create/detail/search, identity, access, browser, invitation, and system-info wire contracts. The operation count changes only for this one endpoint.
- Non-goals: revision creation/history/diff/restore; memory update/archive/delete; categories, tags, custom metadata, relationships, repositories, import/export; search changes; product UI; Planning; SDK/CLI; generic policy/pagination frameworks; background jobs.

Acceptance criteria:

- Scoped owners list only memories in their tenant project; scoped members and agents list only within projects they can currently read. Direct/team overlap cannot duplicate rows. Inaccessible projects, records, counts, revision data, and cursor contents never leak.
- Summaries contain the exact bounded fields, latest revision, provenance, hash, and excerpt but no full content. Existing detail still returns full content unchanged; search results remain unchanged.
- Pagination handles empty/final pages, limits 1 and 100, equal memory timestamps, different page sizes, deleted anchors, and a future-style memory with multiple revisions. Stable datasets produce no duplicates. Arbitrary or cross-credential cursors never bypass current project authorization.
- Invalid scalar/nested/empty/oversized cursor and limit inputs produce deterministic envelopes without crashes. Project concealment wins over pagination validation after authentication and scope.
- Listing creates no audit event or durable mutation. Existing credentials, invitations, memories, revisions, API responses, capabilities, and browser behavior remain unchanged except for the additive route.

Verification:

- Domain/controller tests cover owner, direct member, active-team member, agent, overlapping grants, no grants, foreign tenant, malformed project, invalid/revoked token, missing scope, and browser-cookie-only access.
- Pagination/cursor tests cover defaults, empty/final pages, limits 1/100, equal timestamps, anchor deletion, latest-revision selection, interleaved inaccessible projects, invalid encoding/keys/types/version/time/UUID, 512-byte boundary, nested parameters, and cross-credential reuse. Create any revision 2+ rows only through test-only database fixtures and assert the production changeset still rejects revision numbers other than 1.
- Assert exact success/error JSON, exact field exclusion of `content`, 240-character excerpt behavior, no-store, no read audits, fresh lifecycle/access changes, unchanged existing endpoint contracts, and unchanged system capabilities.
- Run `make check`, `make upgrade-phase2`, Docker build, expanded Compose smoke, OpenAPI parse/operation assertions, representative `EXPLAIN ANALYZE` for the composite memory and latest-revision indexes, reversible index-migration testing, `brain context audit`, `plan check`, `git diff --check`, and Brain session finish. No production migration or deployment.

Dependencies: none. Phase 3A canonical spec #31 is complete through merged PR #34; existing read authorization, immutable revision-1 persistence, provenance, detail/search projections, and cursor precedent are available on `develop`.

Readiness: approved. Review accepted the bounded contract, preserved the revision-1 write boundary, and fixed the composite-index requirement. Canonical GitHub spec #36 is ready for execution after the planning PR merges.

---
created_at: "2026-09-07T16:48:31Z"
project: brain-cloud
slug: project-discovery-foundation
status: active
title: Project discovery foundation
type: brainstorm
updated_at: "2026-09-07T19:18:16Z"
---
# Brainstorm: Project discovery foundation

## Vision

Clients can discover accessible projects and fetch basic details without retaining IDs from creation responses. Phase 3A starts the cloud-native project model with a small API-only read surface.

## Supporting Material

- docs/roadmap.md: Phase 3.
- apps/brain_cloud_web/lib/brain_cloud_web/router.ex: creation exists; list/detail do not.
- apps/brain_cloud/lib/brain_cloud/projects.ex: owner/member/team/agent authorization.
- apps/brain_cloud/lib/brain_cloud/accounts/scopes.ex: explicit fixed scopes.
- apps/brain_cloud_web/lib/brain_cloud_web/api_json.ex: current project representation.

## Refinement

### Problem

API clients can create projects but cannot discover their accessible projects or fetch project details.

### User / Value

Humans and agents gain permission-safe discovery for future SDK/CLI workflows.

### Appetite

Two read endpoints, one explicit scope, focused tests and docs. No browser product UI or new project mutation.

### Decision Snapshot

User requested continuation into scope review and specification. Recommend projects.read without credential backfills, existing project fields, and bounded keyset pagination. Canonical spec receives review before execution.

## Constraints

Preserve one /v1 protocol and current tenant/access rules. No scope implication or hidden widening of credentials. Filter before pagination; never expose inaccessible rows or counts.

## Challenge

### Rabbit Holes

Generic pagination frameworks, query languages, snapshot sessions, broader metadata/lifecycle, and browser dashboards.

### No-Gos

No rename, metadata expansion, archive/delete, revisions, import/export, browser product UI, Planning, or agent project administration.

### Assumptions

Project inserted_at and UUID are immutable and supply a deterministic traversal key. Existing explicit owner recovery can issue current full-scope credentials after upgrade.

### Risks and Mitigations

Scope backfills broaden existing credentials: do not backfill. Duplicate team joins corrupt pages: use an authorized distinct project set before ordering and limiting. Revoked grants must disappear on subsequent requests: authorize every page and detail lookup from database state. Cursor is a position, never proof of permission. No cross-request snapshot promise.

### Simpler Alternative

Detail-only leaves discovery unresolved. Offset paging is simpler but shifts under inserts. A small project-specific keyset helper avoids a generic framework and needs no signing secret because arbitrary valid positions grant no access.

## Promotion map

### Spec 1 — Project discovery foundation

Problem:

Clients can create projects but cannot list projects they may access or retrieve project details. Add the smallest permission-safe read surface as Phase 3A.

Scope:

- Non-goals: no project rename or metadata expansion, archive/delete, revisions, diff/restore, import/export, repositories/relationships, browser product UI, Planning, SDK/CLI implementation, or agent creation/administration. Phase 2I is complete through PR #30; this is the next bounded Phase 3A proposal.
- Add GET /v1/projects and GET /v1/projects/:id, using existing API bearer authentication only. Browser cookies alone remain insufficient. Add projects.read to fixed human and agent scope validation and system-info capabilities. This scope allows only project discovery/detail, never memory reading, search, creation, or access management. Existing scopes imply nothing about projects.read. Existing management and issuance authorization remains unchanged, including caller-scope subset checks where currently required and owner-only agents.manage authority for agent credential issuance. Members may receive projects.read; agents still require direct project grants.
- No token, invitation, or audit-row backfill. Existing credentials keep their exact stored scopes and all existing operations keep their behavior. Existing tokens lacking projects.read get 403 on these new endpoints. Newly bootstrapped/recovered owner tokens include the updated full scope set. Document deliberate owner recovery through the existing release bootstrap workflow with ROTATE_TOKEN=true for an existing bootstrap credential, including revocation of that old bootstrap token, then explicit human/agent credential issuance. New invitation requests may explicitly include projects.read under existing issuer rules; browser-created invitation default scopes stay unchanged. No automatic access grant or silent credential upgrade.
- Derive organization and principal from authenticated state, never query parameters. Active owners can read all organization projects. Active members need reader/editor direct grants or grants through retained active team membership and active teams. Active agents need reader/editor direct agent grants. Credential revocation, inactive memberships/agents, owner demotion, team deactivation, removed links, and grant deletion must affect the next request after commit. Apply tenant and access predicates in PostgreSQL before loading rows, deduplication, pagination, or serialization. Both endpoints share equivalent access semantics. Requests already in flight may use the authorization snapshot of their read; no cross-request snapshot or strict revocation linearization is promised.
- Project objects reuse the exact existing APIJSON.project fields and timestamp formatting: id, organization_id, name, creator_actor_id, inserted_at, updated_at. No memory, grant, user-profile, token, or aggregate fields. Detail succeeds with 200 {"project": <project>}. List succeeds with 200 {"projects": [<project>], "next_cursor": <string-or-null>}. Empty results are 200 with an empty projects array and null cursor. No totals.
- List supports limit, default 20, decimal integer 1 through 100, and optional cursor. Reject supplied empty/malformed/non-scalar limit or cursor with 422 validation_failed. Sort ascending by inserted_at and UUID; select strictly after the cursor tuple. Filter to distinct authorized projects before taking limit + 1 rows. Return at most limit rows; emit the last returned row cursor only when an additional authorized row exists. Cursor does not require the anchor project to still be visible or exist. Fresh authorization applies on each request. Concurrent inserts or grants behind the cursor may be missed until traversal restarts; no duplicate rows for a stable dataset or a snapshot-consistent export guarantee.
- Cursor v1 encoding: unpadded base64url UTF-8 JSON object with exactly v (integer 1), inserted_at (UTC RFC3339 timestamp with six fractional digits), and id (canonical lowercase UUID). Use safe JSON decoding, strict field/type/time/UUID validation, and a maximum encoded length of 512 bytes before decoding. A cursor is an unsigned position, not a credential or resource lookup; valid arbitrary positions and reuse under another credential still undergo all current access predicates. Reject invalid encoding, oversized input, unknown versions, missing/extra fields, or wrong types with the same 422 cursor error. No Erlang term decoding, cursor persistence, signing secret, or cursor-derived organization/authorization. Unknown unrelated query parameters are ignored and cannot change scope, order, or fields.
- Error precedence: authenticate, require projects.read, validate query inputs for list or authorize ID for detail. Missing/invalid/revoked credentials use existing 401 unauthorized envelope. Valid credential missing scope uses existing 403 forbidden. Detail absent, malformed UUID, foreign-tenant, or inaccessible ID uses existing 404 project_not_found envelope. Validation uses existing 422 {"error":{"code":"validation_failed","message":"Request validation failed","details":...}}: details.limit = ["must be an integer between 1 and 100"] and details.cursor = ["is invalid"]; include both keys when both supplied fields are invalid. Other error details remain {}. Both read responses use Cache-Control: no-store. No new read audit events or durable state mutation, beyond existing authentication bookkeeping.
- Keep domain queries in brain_cloud and controllers/encoding at appropriate existing boundaries in brain_cloud_web; do not add a generic framework. No business-data schema change or credential migration is required. A focused organization_id/inserted_at/id index migration is allowed if query-plan evidence warrants it, with reversible migration testing. Update OpenAPI for the two operations, scope enums/issuance docs, capabilities, response/error schemas, and pagination examples during implementation; preserve existing response fields and defaults except the explicitly additive projects.read capability/scope support. Document current versus planned behavior honestly.

Acceptance criteria:

- Scoped owner lists only its organization; scoped members and agents list only authorized projects and can retrieve exactly those details. Direct/team overlaps never duplicate rows. No inaccessible rows or counts leak through pagination, errors, or cursors.
- Existing tokens and pending invitations remain byte-for-byte equivalent in stored scopes after upgrade; new endpoints deny missing scope; explicit bootstrap/recovery and issuance enable intended clients without widening other permissions.
- Pagination handles empty/final pages, equal timestamps, different page sizes, and anchor removal. Invalid inputs return deterministic envelopes without crashes. Cursor reuse never bypasses tenancy or grants.
- Committed credential/access/lifecycle changes affect subsequent page and detail requests. Existing creation, memory/search, invitation, and browser contracts remain intact.

Verification:

- Domain/controller tests for owner, direct member, team member, agent, overlapping grants, zero grants, foreign tenant, invalid/revoked token, missing scope, and browser-cookie-only access.
- Tests for role/lifecycle/grant changes between pages; cursor anchor no longer accessible; inaccessible records interleaved across page boundaries; equal timestamps; limits 1 and 100; default/empty/final pages; malformed/oversized/nested parameters; unsupported cursor versions; cross-credential reuse.
- Assert exact JSON fields/errors, no-store, explicit scope issuance rules, no privilege implications, no read audits, unchanged existing token/invitation scopes, and additive system capability.
- Run make check, make upgrade-phase2, Docker build, existing release smoke plus project-discovery smoke, OpenAPI assertions, brain context audit, plan check, and git diff --check through Brain during implementation. Query-plan review uses a representative tenant dataset; any optional index is rollback/forward tested. No production migrations in this task.

Dependencies: Phase 2I spec #28 is complete through merged PR #30; existing identity, scope, project access, and agent foundations are present on develop.

Readiness: review. Contract is bounded and recommendations are explicit; canonical GitHub spec requires review before execution. This planning work implements no API operations.

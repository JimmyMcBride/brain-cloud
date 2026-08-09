---
created_at: "2026-08-09T08:38:23Z"
project: brain-cloud
slug: agent-authored-memory-provenance-foundation
status: active
title: Agent-authored memory provenance foundation
type: brainstorm
updated_at: "2026-08-09T08:41:57Z"
---

# Brainstorm: Agent-authored memory provenance foundation

Started: 2026-08-09T08:38:23Z

## Focus Question

What is the smallest secure Phase 2F slice that lets first-class agents author immutable memory revisions with explicit provenance, without granting project creation, human administration, or proposal/workflow powers?
## Desired Outcome

Active agents with explicit editor access and memory.write credentials can create immutable revision-1 Markdown memories. Every returned memory and search result identifies whether the author was a human user or agent. Existing human wire identifiers, authorization, audit, and upgrade behavior remain compatible.
## Vision

## Supporting Material

## Constraints

- Preserve human actor IDs and successful Phase 1-2E behavior.
- Require both memory.write scope and direct agent editor grant.
- Use explicit human-or-agent revision and audit provenance with database constraints.
- Keep agent writes limited to existing immutable revision-1 memory creation.
- Keep project creation, proposals, delegation, administration, and later identity features deferred.

## Open Questions

- How should PostgreSQL prove an agent-authored revision belongs to the same organization as its memory project without introducing a broad memory tenancy redesign?
## Ideas

- Use split nullable actor_user_id and actor_agent_id columns for memory revisions and audit events, with PostgreSQL exactly-one checks and restrictive foreign keys. Expose stable actor_type plus actor_id JSON; existing human actor_id remains the user ID, while agent actor_id is the agent ID.

- Expand direct agent project grants from reader-only to reader/editor. Editor implies read at the project-access layer. Expand allowed agent credential scopes to non-empty subsets of memory.write, memory.read, and search.keyword. Fixed route scopes remain independent from grants.

- Record agent memory.create audits with actor_agent_id and the authenticating agent token. Keep owner-driven agent/grant management audits human-authored. Add a database tenant guard for agent-authored revisions so direct SQL cannot attach a cross-organization agent to a project memory.
## Raw Notes

Dependency: merged Phase 2E PR #18 and canonical spec #16. Update Phase 2E roadmap status to complete in this planning PR. Verification must cover legacy actor migration, exact-one actor constraints, cross-tenant database rejection, human compatibility, agent write/read/search combinations, deactivation/revocation/grant removal, audits, upgrade, image, and Compose smoke.

## Refinement

### Problem

Phase 2E gives agents honest identities and read-only project access, but memory creation assumes every author is a human user. Granting memory.write now would either crash on missing user provenance, impersonate a human, or weaken database integrity. Revision and audit actor models must support agents before any agent-authored durable write is safe.

### User / Value

Organizations can give a narrowly scoped automation agent direct editor access to selected projects. Agents can create durable memory under their own identity; people and future clients can trust author provenance, revoke access immediately, and distinguish human from automated content without a separate workflow system.

### Appetite

One focused Phase 2F spec and implementation PR. Extend existing schemas, authorization, API representation, upgrade verification, and smoke coverage. No new service, worker, endpoint family, policy framework, or product UI.

### Remaining Open Questions

- How should PostgreSQL prove an agent-authored revision belongs to the same organization as its memory project without introducing a broad memory tenancy redesign?

### Candidate Approaches

- Preferred: split actor_user_id and actor_agent_id columns with exactly-one checks and foreign keys; expose actor_type plus actor_id; extend direct agent grants to reader/editor and agent scopes to write/read/search.
- Rejected: one polymorphic actor_id without foreign keys; simpler migration but weak integrity and ambiguous provenance.
- Rejected: introduce a universal principals table; cleaner long-term polymorphism but disproportionate migration and identity redesign for one write path.
- Rejected: add a proposal/approval workflow before direct writes; valuable later but belongs to the agent platform phase, not this bounded provenance slice.

### Decision Snapshot

Proceed with split human/agent actor columns, exactly-one constraints, stable actor_type plus actor_id API provenance, direct agent reader/editor grants, and write/read/search agent scopes. Preserve human actor IDs. Use a narrow PostgreSQL constraint trigger on memory revisions to reject an agent whose organization differs from the revision memory project; use the existing audit organization column for a composite agent tenant foreign key.

## Challenge

### Rabbit Holes

- Turning two actor variants into a universal principal registry.
- Designing future mutable revision history or proposal approval now.
- Expanding agents into project creation, teams, or administration.
- Building generic authorization, audit querying, pagination, jobs, or UI.
- Redesigning every tenant-owned table instead of guarding this write path.

### No-Gos

- No synthetic users or memberships for agents.
- No untyped actor ID without referential integrity.
- No agent write permission from scope alone or grant alone.
- No restoration of revoked credentials after reactivation.
- No changes to human actor IDs or existing content hashes.
- No new endpoint family for agent memory creation.

### Assumptions

- Phase 2E agent identity, lifecycle, credentials, and direct grants are merged and stable.
- Existing POST memory semantics are suitable for both human and agent authors.
- Human actor_id must remain a user ID for compatibility.
- Editor implies reader access, while route scopes remain independent.
- Direct agent writes are acceptable without a proposal workflow in this bounded phase.

### Likely Overengineering

A universal actor/principal abstraction would force unrelated project, membership, and audit migrations. Keep explicit human and agent columns plus small projection helpers. A broad tenant denormalization across memories and revisions would exceed this slice; use a targeted database tenant guard for agent revision authorship.

### Simpler Alternative

One additive provenance migration, one existing memory-create path, one expanded agent grant enum, and one expanded agent scope allowlist. Keep human behavior unchanged. Return actor_type alongside the existing actor_id projection. Verify direct writes, denial paths, migration, audit, and revocation; stop there.

## Promotion map

### Spec 1 — Agent-authored memory provenance foundation

Problem:

Phase 2E gives agents honest identities, scoped credentials, and direct reader access,
but memory creation and immutable audit provenance still require a human user. Enabling
`memory.write` without changing those boundaries would either impersonate a person,
lose referential integrity, or fail at runtime.

Scope:

- Rename `memory_revisions.actor_id` to `actor_user_id`, add nullable
  `actor_agent_id`, and require exactly one actor with restrictive foreign keys.
  Migrate every existing revision as human-authored without changing its user actor ID,
  content, content hash, revision number, or timestamps.
- Make `audit_events.actor_user_id` nullable, add nullable `actor_agent_id`, and
  require exactly one actor. Preserve every existing audit row as human-authored and
  add a composite agent/organization foreign key so agent audit actors belong to the
  event tenant.
- Add a narrow deferrable PostgreSQL constraint trigger for agent-authored memory
  revisions that rejects an agent whose organization differs from the revision
  memory's project organization. Keep the existing project creator and broader memory
  tenancy schema unchanged.
- Project revision and search-result provenance as additive `actor_type` plus the
  existing `actor_id`. `actor_type` is exactly `human` or `agent`; human `actor_id`
  remains the existing user UUID and agent `actor_id` is the agent UUID. Preserve all
  other successful memory and search fields exactly.
- Expand direct agent project access from fixed `reader` to `reader` or `editor`.
  Editor implies reader project access, while route scopes remain independent. Migrate
  existing reader grants unchanged.
- Keep the existing agent-access routes and envelopes. `PUT` accepts either access
  value; a changed value updates the one grant row and returns `200`; an identical PUT
  is a no-op. Add transactional `agent_project_access.change` auditing with safe prior
  and current access metadata; retain existing grant/revoke auditing.
- Allow agent credentials to request any non-empty subset of `memory.write`,
  `memory.read`, and `search.keyword`. Continue rejecting every project creation,
  access-management, membership, team, agent, and token-management scope with exact
  `422 validation_failed` field details. Human token scope behavior remains unchanged.
- Reuse `POST /v1/projects/{project_id}/memories`; add no agent-specific endpoint.
  Agent creation requires an active agent credential with `memory.write` and a direct
  editor grant for that project. A reader grant never permits writes. Scope failure is
  `403 forbidden` before project lookup; missing, malformed, inaccessible, or
  cross-tenant projects remain exact `404 project_not_found` after scope succeeds.
- For agent writes, authorize the active agent and direct grant in the memory-create
  transaction with row locking sufficient to linearize against lifecycle, credential,
  and grant mutations. A write that starts after deactivation, credential revocation,
  expiry, or grant removal commits is denied. An already in-flight request may finish
  on its documented side of the lock ordering; do not claim request cancellation.
- Create immutable revision 1 with authentic agent provenance and emit the existing
  `memory.create` audit action with `actor_agent_id` in the same transaction. Preserve
  human memory creation, human audit actors, request validation, content hashing, and
  response semantics.
- Authorize agent retrieval/search with either reader or editor project access plus
  the corresponding fixed `memory.read` or `search.keyword` scope. Keep explicit
  scope-and-grant checks, tenant concealment, no authorization cache, and immediate
  next-request lifecycle effects.
- Keep owner plus `projects.manage_access` checks before protected lookup on all agent
  grant management routes. Agent credentials remain forbidden from grant management,
  project creation, human administration, agent administration, and token management.
- Preserve all Phase 1–2E human identity, token, owner, membership, team, project,
  direct/team access, memory, search, audit, health, readiness, migration, release, and
  successful wire behavior except the documented additive provenance field.
- Update OpenAPI, README, architecture, security, self-hosting, roadmap, LiveView copy,
  release upgrade/smoke documentation, Plan, AGENTS, and durable Brain context without
  implying later agent-platform features exist.
- Add no project creation by agents, agent team membership, administration,
  delegation, sub-agents, proposals/approval workflows, mutable revision API, custom
  roles, deny rules, inheritance, generic principal table, generic policy engine, RLS,
  authorization cache, audit-query API, pagination, jobs, management UI, MCP/actions,
  module tools, invitations, interactive login, OAuth/OIDC, SSO, SCIM, refresh/exchange
  tokens, workload federation, mTLS, or signing keys.

Acceptance criteria:

- PostgreSQL rejects revision/audit rows with zero or two actors and rejects cross-organization agent revision/audit provenance when application validation is bypassed. Existing human rows migrate unchanged and rollback/forward migration paths are safe for supported upgrades.
- Existing human memory creation, retrieval, and search return the same actor UUID as before plus exact `actor_type: "human"`; content hashes and all other successful fields remain unchanged. Agent-authored results return exact `actor_type: "agent"` and the authentic agent UUID.
- Active agents can create immutable revision-1 Markdown only when both `memory.write` and a direct editor grant permit it. Missing scope, reader-only/no grant, inactive agent, revoked/expired credential, and tenant mismatch produce the documented concealed errors and commit no memory, revision, or audit row.
- Agent editor access permits retrieval/search only when the independent read/search scope is present. Write scope alone never implies read/search; read/search scopes never imply write.
- Grant reader-to-editor and editor-to-reader changes converge on one row, return the exact existing envelope, and emit one `agent_project_access.change` audit per real change. Identical PUTs remain audit-free no-ops; retained grants remain dormant while an agent is inactive.
- Every human or agent memory creation commits one immutable `memory.create` event with exactly one authentic actor in the same transaction. Failures and no-ops commit no event; credentials and digests never enter logs, errors, responses, or audit metadata.
- Lifecycle, credential, grant, and write races linearize without duplicate rows, partial state, integrity exceptions, or 500 responses. Requests beginning after a committed deactivation, revocation, expiry, or grant removal cannot write.
- OpenAPI documents additive provenance, agent editor grants, agent write scopes, authorization precedence, exact field sets, and relevant `401`, `403`, `404`, `409`, and `422` responses while preserving all existing operations.

Verification:

- Migration/domain tests cover legacy human actor preservation, exactly-one actor checks, human/agent foreign keys, cross-tenant database rejection, unchanged hashes, reader/editor grant transitions, allowed/rejected agent scope subsets, and transactional/no-op audits.
- Authentication/project/memory/search tests cover human compatibility, agent writer success, scope/grant independence, editor read implication, authorization-before-load, tenant concealment, inactive/revoked/expired denial, retained grants, and exact provenance projection.
- Concurrency tests cover reader/editor PUT convergence and agent writes racing deactivation, credential revocation, and grant change/removal, with exact row/audit counts and no database exceptions or 500 responses.
- Controller tests cover exact JSON/status/field contracts, validation, malformed and cross-tenant IDs, scope precedence, reader-only write denial, human and agent memory creation, retrieval, search, and idempotent grant behavior.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Extend `make upgrade-phase2` to prove Phase 1–2E data/access remains intact, every legacy revision/audit actor stays human with the same ID, existing reader grants and tokens remain compatible, and the new constraints hold after upgrade.
- Build the non-root production image and extend `make smoke-phase2` for human compatibility, agent editor grant transitions, scoped write/read/search, exact provenance, lifecycle/revocation/removal denial, two-organization isolation, restart persistence, and PostgreSQL outage/recovery.
- Before implementation, adopt the promoted GitHub issue into Plan metadata on a fresh execution branch and require `plan check` to pass.
- Run `brain context audit`, `plan check`, OpenAPI parsing/operation assertions, shell syntax checks, `git diff --check`, and `brain session finish`.

Dependencies: Phase 2E agent identity and credential foundation is merged.

Readiness: ready.

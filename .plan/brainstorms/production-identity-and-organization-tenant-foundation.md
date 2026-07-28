---
created_at: "2026-07-28T19:24:11Z"
project: brain-cloud
slug: production-identity-and-organization-tenant-foundation
status: active
title: Production identity and organization tenant foundation
type: brainstorm
updated_at: "2026-07-28T19:26:54Z"
---

# Brainstorm: Production identity and organization tenant foundation

Started: 2026-07-28T19:24:11Z

## Focus Question

What is the smallest production-capable identity and organization boundary that replaces Phase 1 development authentication and prevents cross-tenant access on the existing project, memory, and search APIs?
## Desired Outcome

A release operator bootstraps one organization owner and receives one API token exactly once. That owner can issue and revoke scoped tokens. Every existing project, memory, and search request derives one authenticated user and organization, rejects inactive or insufficient credentials, and cannot observe another tenant's resources. Durable Phase 1 data remains readable with preserved actor provenance.
## Vision

Replace the Phase 1 development credential with a production-capable API
identity boundary without turning this phase into a complete identity product.
Every protected request resolves a persisted human principal, one organization,
one active membership, and explicit token scopes before domain data is touched.
Self-hosters can create the first owner from the OTP release, secrets are never
stored in plaintext, durable writes remain attributable, and tenant isolation is
proved against the existing project-memory-search path.

## Supporting Material

- `docs/security.md`
- `docs/architecture.md`
- `docs/roadmap.md`
- `docs/self-hosting.md`
- `openapi/brain-cloud-v1.yaml`
- Phase 1 implementation and spec [#2](https://github.com/JimmyMcBride/brain-cloud/issues/2)
- ADR 0010, establishing one shared identity and access foundation

## Constraints

- Keep the existing Phoenix umbrella and PostgreSQL as the only required data service.
- Preserve one public /v1 protocol and keep operational routes public.
- Preserve all Phase 1 projects, memories, revisions, actor provenance, and wire-compatible retrieval/search responses.
- Authenticate tokens from stored one-way digests; show raw secrets only at creation.
- Return 404 for inaccessible tenant resources to avoid cross-tenant enumeration.
- Enforce authorization before project lookup, retrieval, or search result generation.
- Keep bootstrap usable from an OTP release without a web UI.
- No teams, agent credentials, passwords, browser sessions, OAuth/OIDC, invitations, SCIM, SSO, fine-grained project ACLs, or module/Planning work.
## Resolved Decisions

- One token is bound to one user and one organization membership. Requests do
  not select or switch tenant through a header.
- Membership roles are `owner` and `member`. Tokens further restrict access
  through explicit fixed scopes; a token never grants more than its membership.
- The token secret is random, returned once, stored only as a digest, optionally
  expires, and can be revoked immediately.
- The release bootstrap is the only unauthenticated identity creation path in
  this slice. It creates an organization, owner, membership, and initial token
  idempotently.
- Existing Phase 1 actor UUIDs remain the user/principal IDs recorded in project
  and revision provenance. A deterministic migration creates compatibility
  principals and organizations and assigns every existing project.
- Cross-tenant and unauthorized resource lookups return the same structured
  `404` as a missing resource. Invalid, expired, or revoked credentials return
  structured `401`; valid credentials lacking scope return structured `403`
  only when no resource identity would be disclosed.
- Audit events cover bootstrap, token creation/revocation, project creation, and
  memory creation. Read/search audit and audit-query APIs remain deferred.

## Open Questions

## Ideas

- Persist users, organizations, owner/member memberships, and hashed revocable API tokens.
- Require both active organization membership and token scopes before existing project, memory, or search access.
- Add project organization ownership and an immutable audit foundation while preserving Phase 1 data.
- Defer teams, agent credentials, browser login, OAuth, invitations, and fine-grained project ACLs.
## Raw Notes

This is Phase 2A, not the whole Phase 2 inventory. It establishes the shared
identity and tenant invariant needed by later teams, agent credentials, complete
project permissions, hosted retrieval, Hive Mind, modules, and Planning.

## Refinement

### Problem

Phase 1 trusts one process-wide bearer token and actor UUID. It cannot identify real users, isolate organizations, revoke credentials, enforce permissions, or prove who performed durable writes. Existing project, memory, and search routes therefore cannot be exposed beyond trusted development networks.

### User / Value

A self-hosting administrator can bootstrap the first owner safely. Human API clients can use individually issued credentials. Every existing project, memory, and search operation is confined to organizations where the authenticated user has active membership and sufficient token scope.

### Appetite

One production identity vertical slice: schema and migration, release bootstrap, token issue/list/revoke lifecycle, organization membership and fixed role checks, tenant ownership on existing resources, a minimal immutable audit log, OpenAPI, tests, and release smoke coverage. Stop when one owner can bootstrap, issue credentials, use existing APIs inside one organization, and prove another organization cannot observe them.

### Remaining Open Questions


### Candidate Approaches

- Model users, organizations, memberships, API tokens, and audit events in a focused BrainCloud.Accounts context; keep tenant-aware project/memory queries in their existing contexts.
- Bind each API token to one user and one organization membership so every request has an unambiguous tenant; use owner/member roles plus explicit read/write/token-management scopes.
- Use a versioned bc_ token format containing a public token identifier and a random secret; store only a SHA-256 digest, compare safely, and support optional expiry and revocation.
- Provide an idempotent OTP release bootstrap command that creates the first user, organization, owner membership, and single-use displayed token without storing plaintext.
- Backfill existing Phase 1 actor UUIDs into synthetic users and organizations deterministically, preserve actor IDs as user IDs, assign every project an organization, and keep existing data readable.
- Record immutable audit events for bootstrap, token issuance/revocation, project creation, and memory creation; defer read/search auditing and export APIs.

### Decision Snapshot

Keep Phase 2A as one production identity vertical slice. Add a focused Accounts
domain for persisted users, organizations, owner/member memberships, scoped API
tokens, and immutable audit events. Bind each token to one membership so the
tenant is unambiguous. Replace the development auth plug on product routes,
assign projects to organizations, preserve actor UUID provenance, and require
tenant-aware domain queries before retrieval or search. Bootstrap the first
owner through an idempotent OTP release command and expose authenticated token
issue/list/revoke operations. Migrate Phase 1 data deterministically. Stop
before teams, agents, interactive login, invitations, SSO, per-project ACLs, or
broader Phase 2 administration.

## Promotion map

### Spec 1 — Production identity and organization tenant foundation

Problem:

Phase 1 protects every product route with one process-wide development token and
records one configured actor UUID. It cannot identify real principals, revoke
individual credentials, isolate organizations, enforce permissions, or provide
a security audit trail. The current project-memory-search path therefore cannot
be exposed as a production multi-tenant service.

Scope:

- Add a focused `BrainCloud.Accounts` context in the core application. Use Ecto
  directly; add no external identity service, policy engine, or generic provider
  abstraction.
- Add `users`, `organizations`, `organization_memberships`, `api_tokens`, and
  `audit_events` tables with binary UUID primary keys, timestamps, foreign keys,
  and the minimum uniqueness and lookup indexes required by this slice.
- Store normalized unique user email plus display name. Store organization name
  plus normalized unique slug. A membership binds one user to one organization,
  is unique per pair, has `owner` or `member` role, and can be deactivated.
- Bind every API token to exactly one active membership. Use a versioned
  `bc1_<public_id>_<secret>` format with a cryptographically random 32-byte
  secret. Store the public identifier and SHA-256 digest, never plaintext or
  reversible token material.
- Support token name, fixed scopes, optional expiry, and revocation timestamp.
  Return the raw token only from successful creation.
  Never expose a token digest through API responses, logs, errors, audit
  metadata, or inspection output.
- Use the protected product capability names as token scopes:
  `projects.create`, `memory.write`, `memory.read`, and `search.keyword`. Add
  `tokens.manage`; require both owner role and that scope for token lifecycle
  operations. A new token can receive only a subset of the caller's scopes.
- Replace `BrainCloudWeb.Plugs.DevAuth` with persisted token authentication.
  Resolve and assign one immutable request auth context containing user,
  organization, membership, role, token, and scopes. Reject malformed, unknown,
  expired, revoked, digest-mismatched, or inactive-membership credentials before
  entering a product controller.
- Remove `DEV_API_TOKEN` and `DEV_ACTOR_ID` runtime requirements, Compose
  defaults, documentation, and test helpers. Add no compatibility fallback to
  the Phase 1 credential.
- Add an idempotent OTP release command that accepts owner email/display name
  and organization name/slug, creates or reuses the user, organization, owner
  membership, and initial full-scope token transactionally, and prints the raw
  token exactly once. A repeated identical bootstrap creates no new token and
  cannot recover the prior secret. Provide an explicit recovery option that
  revokes the existing bootstrap token and issues one replacement when the
  operator loses the one-time output.
- Preserve Phase 1 data. The migration creates one deterministic
  `phase-1-import` compatibility organization, creates synthetic users for every
  distinct existing project/revision actor UUID, creates their memberships,
  assigns every existing project to that organization, and preserves all
  project, memory, revision, content-hash, timestamp, and actor values.
- Let the release bootstrap explicitly adopt the `phase-1-import` organization
  so a real owner can access migrated data. Do not silently attach new owners to
  legacy data.
- Add a non-null `organization_id` foreign key and index to projects. New project
  creation derives the organization and creator actor from the authenticated
  context; its request body remains `{"name": string}`. Add
  `organization_id` to the project response while preserving existing fields.
- Require tenant-aware context functions for project creation, memory creation
  and retrieval, and keyword search. Scope the initial database query by
  organization; do not load content and filter it afterward.
- Keep `/`, `/healthz`, `/readyz`, and `/v1/system/info` public. Protect all
  other implemented `/v1` routes with persisted authentication and their
  required token scope.
- Add `POST /v1/auth/tokens` to create a token for the caller's membership,
  `GET /v1/auth/tokens` to list the caller's organization token metadata, and
  `DELETE /v1/auth/tokens/{token_id}` to revoke an organization token. Require
  owner role plus `tokens.manage`; never return another token's raw secret or
  digest.
- Keep authenticated resource errors non-enumerating. Invalid credentials
  return the existing structured `401 unauthorized`. Valid credentials lacking
  a required scope return structured `403 forbidden` before resource lookup.
  Missing or cross-tenant projects/memories return the same structured `404`.
  Invalid bootstrap or token inputs return safe structured errors without
  database or secret details.
- Add immutable audit events for `identity.bootstrap`, `token.create`,
  `token.revoke`, `project.create`, and `memory.create`. Record organization,
  actor user, credential when present, action, resource type/ID, safe metadata,
  and timestamp. Commit each durable action and its audit event in one database
  transaction.
- Add `tokens.manage` to system capability discovery while preserving existing
  capabilities and `modules: []`.
- Update OpenAPI, README, self-hosting, Compose, release documentation, security
  notes, roadmap state, and durable Brain context for the implemented contract.
- Add no general user/organization/membership CRUD API, team model, invitation
  flow, password, browser session, email verification, OAuth/OIDC, SSO, SCIM,
  agent credential, service account, refresh token, per-project ACL, audit query
  API, rate-limiting system, module/Planning behavior, or new LiveView product
  surface.

Acceptance criteria:

- The release bootstrap creates one user, organization, owner membership, and full-scope token atomically and displays the raw token once; repeating it is idempotent and displays no recoverable prior secret.
- An explicit bootstrap recovery invocation revokes the previous bootstrap token, emits one replacement secret once, records the rotation, and leaves the old credential unusable.
- Stored token rows contain only public lookup metadata and a digest; automated tests and log capture prove raw tokens and digests do not appear in normal logs, errors, audit metadata, list responses, or revoke responses.
- Missing, malformed, unknown, expired, revoked, digest-mismatched, and inactive-membership tokens return the exact structured `401` response and cannot enter a product controller.
- A valid token without the required scope returns the exact structured `403` response before any project, memory, revision, or search-content query.
- An owner with `tokens.manage` can create, list, and revoke organization token metadata; issued scopes are a subset of the caller's scopes, and revocation takes effect on the next request, including for the current token.
- A token is permanently bound to one membership and organization; no request header or body can switch its tenant.
- Project creation preserves the Phase 1 request contract, derives actor and organization from authentication, and returns the existing project fields plus `organization_id`.
- Memory creation/retrieval and keyword search preserve successful Phase 1 wire shapes, content hashes, actor provenance, and query behavior inside the authenticated organization.
- With two bootstrapped organizations, neither can retrieve, write to, search, distinguish, or enumerate the other's projects or memories; cross-tenant IDs return the same structured `404` as nonexistent IDs.
- Authorization is enforced in Ecto query predicates before protected content is loaded; controller-only filtering does not satisfy this criterion.
- The Phase 1 upgrade path preserves every project, memory, revision, actor UUID, hash, and timestamp; assigns them to `phase-1-import`; and requires explicit owner adoption before access.
- Bootstrap, token create/revoke, project create, and memory create each commit exactly one safe immutable audit event with the correct organization, actor, credential, action, and resource provenance; failed transactions leave neither domain data nor audit events.
- Public root, health, readiness, and system-info behavior remains compatible except for the explicitly added capability; PostgreSQL outage still changes readiness to `503` without changing process health and recovers normally.
- Restarting the API preserves identities, memberships, token validity, revocation, tenant ownership, audit events, projects, memories, and search.
- OpenAPI defines persisted bearer authentication, all three token operations, organization-aware project responses, exact errors/scopes, and examples; implementation and specification agree.

Verification:

- Accounts-context tests cover normalization and uniqueness, owner/member memberships, token format and digest verification, scope subset validation, expiry, revocation, deactivation, idempotent bootstrap, explicit bootstrap-token recovery, legacy adoption, and transactional audit writes.
- Project/memory context tests cover organization assignment, tenant-scoped predicates, preserved actor provenance, and cross-tenant create/read/search denial.
- Plug/controller tests cover exact `401`, `403`, and non-enumerating `404` responses; token create/list/revoke; project creation; memory creation/retrieval; search; system capabilities; and secret redaction.
- Run an isolated upgrade test that migrates only through the Phase 1 schema, seeds multiple actor IDs and durable records, applies Phase 2A migrations, adopts `phase-1-import`, and verifies all identities, ownership, content, hashes, timestamps, provenance, retrieval, and search.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Build the non-root production image and run Compose bootstrap, token lifecycle, two-organization isolation, API-restart durability, and PostgreSQL outage/recovery smoke tests.
- Review OpenAPI and secret-redaction diffs; run `brain context audit`, `plan check`, `git diff --check`, and `brain session finish`.

Dependencies: none. Phase 1 project-memory-search is already complete in
[#4](https://github.com/JimmyMcBride/brain-cloud/pull/4).

Readiness: approved and ready for execution.

## Challenge

### Rabbit Holes

- Building password login, email verification, browser sessions, OAuth/OIDC, SSO, SCIM, or an identity-provider abstraction before API tenancy works.
- Designing arbitrary RBAC or policy DSLs instead of two membership roles and fixed token scopes.
- Pulling teams, invitations, agent credentials, per-project ACLs, billing, or hosted account administration into the first tenant boundary.
- Auditing every read/search request or building audit export/query before durable security events exist.
- Adding caches, Redis, queues, or a separate identity service when PostgreSQL and Phoenix contexts are sufficient.

### No-Gos

- No plaintext, reversible, or loggable token storage.
- No process-wide production bearer secret or fallback to DEV_API_TOKEN.
- No domain query that loads project, memory, revision, or search content before tenant authorization.
- No destructive reset of Phase 1 data or actor provenance.
- No cross-tenant resource enumeration through status, error, timing-sensitive branch behavior, or search.
- No teams, agent principals, external identity providers, web login, project ACLs, module work, or Planning domain work.

### Assumptions

- Phase 2A can support production API access without interactive human login; operators provision the first owner and owners manage subsequent tokens.
- One organization per token is acceptable for now and avoids tenant-selection ambiguity.
- Organization-wide project access for active members is sufficient until fine-grained project ACLs are specified.
- Owner/member roles plus fixed token scopes are enough to prove authorization composition.
- PostgreSQL can authenticate tokens, enforce tenant-aware queries, and store the initial audit trail without another service.
- Early Phase 1 data volume permits a deterministic transactional backfill during migration.

### Likely Overengineering

A general authorization engine, hierarchical organizations, polymorphic principals, identity-provider adapters, refresh-token flows, exhaustive audit infrastructure, or tenant-context abstractions detached from the four existing product routes. Keep explicit Ecto schemas, fixed roles/scopes, one auth plug, tenant-aware context functions, and only endpoints exercised by the acceptance flow.

### Simpler Alternative

One Accounts context, five focused tables, one release bootstrap command, one persisted-token auth plug, three token-management operations, organization ownership on projects, tenant-scoped versions of the four existing product routes, fixed roles/scopes, four durable audit actions, and one two-organization isolation smoke flow. Add no other identity surface.

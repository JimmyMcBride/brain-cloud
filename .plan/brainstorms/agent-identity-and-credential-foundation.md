---
created_at: "2026-07-29T21:07:28Z"
project: brain-cloud
slug: agent-identity-and-credential-foundation
status: active
title: Agent identity and credential foundation
type: brainstorm
updated_at: "2026-07-29T21:12:23Z"
---

# Brainstorm: Agent identity and credential foundation

Started: 2026-07-29T21:07:28Z

## Focus Question

What is the smallest secure Phase 2E slice that gives organization-owned AI agents first-class non-human identities, revocable scoped credentials, and project access without impersonating humans or introducing interactive login?
## Desired Outcome

Deliver a production-capable Phase 2E identity boundary for AI agents: explicit tenant-owned principals, safe lifecycle, credential issuance/revocation, reader-only project grants, immediate authorization changes, tenant concealment, and immutable management audits. Preserve every human token and direct/team access contract.
## Vision

Brain Cloud owners can create a named AI agent as a first-class organization principal,
issue a one-time credential, and grant that agent read/search access to selected projects.
The agent never masquerades as a person, never receives an email address or human
membership, and never gains authority through an owner or team role.

## Supporting Material

- GitHub spec #14 and PR #15 establish the Phase 2D direct/team access boundary.
- `apps/brain_cloud/lib/brain_cloud/accounts.ex` owns human credentials and authentication.
- `apps/brain_cloud/lib/brain_cloud/accounts/auth_context.ex` currently assumes every caller is a human membership.
- `apps/brain_cloud/lib/brain_cloud/accounts/api_token.ex` binds every token to a membership.
- `apps/brain_cloud/lib/brain_cloud/projects.ex` resolves owner, direct-human, and team access.
- `apps/brain_cloud/lib/brain_cloud/accounts/audit_event.ex` requires a human actor for durable mutations.
- `openapi/brain-cloud-v1.yaml`, `docs/security.md`, and `docs/roadmap.md` define the public/security boundary.

## Constraints

- Keep Phoenix/Ecto/PostgreSQL boundaries. Preserve bc1 bearer authentication and existing human-token wire behavior. Add explicit agent identity; never create synthetic users, fake emails, or human memberships. Allow only memory.read and search.keyword on agent credentials in this slice. Agent project grants are reader-only and separate from human/team grants. Keep fixed scopes independent from project authorization. Management requires active owner plus agents.manage; project grant changes require active owner plus projects.manage_access. Use database tenant constraints, row locking, one-time secrets, digest-only storage, transactional revocation/audits, and authorization before lookup.

## Open Questions

- None for promotion. Agent-authored durable writes become a later spec that must decide
- how projects, revisions, and audit events represent non-human actors without weakening
- foreign-key integrity or changing successful wire shapes accidentally.
## Ideas

- Add explicit organization-owned agent principals instead of overloading users or human organization memberships.
- Reuse one-time bc1 credential issuance and digest storage while making principal type explicit in authentication and audit provenance.
- Start with owner-managed direct project reader grants; defer editor access and team membership until principal-aware write provenance is designed.
## Raw Notes

Supporting material: GitHub spec #14 and PR #15; Accounts, AuthContext, ApiToken, Projects, AuditEvent, OpenAPI, security, and roadmap surfaces.

## Refinement

### Problem

All current credentials are permanently attached to human organization memberships.
Automations must therefore impersonate a person or remain outside Brain Cloud's persisted
identity and project authorization model. Synthetic users would contaminate human
membership, ownership, final-owner, team, provenance, and audit semantics.

### User / Value

Organization owners need named, independently revocable credentials for AI agents.
Agents need least-privilege access to retrieve and search approved project memory without
sharing a human token. Operators need immediate suspension, tenant concealment, and an
audit trail showing which owner created the agent, credential, and project grant.

### Appetite

One focused Phase 2E spec. Reuse the existing token format, digest storage, fixed scopes,
reader authorization, error envelopes, audit mechanism, release migration, and smoke
harness. Accept the narrow read-only limit to avoid a premature principal/provenance
rewrite.

### Remaining Open Questions

- None for promotion. Agent-authored durable writes become a later spec that must decide
- how projects, revisions, and audit events represent non-human actors without weakening
- foreign-key integrity or changing successful wire shapes accidentally.

### Candidate Approaches

- 1. **Synthetic human membership:** smallest code diff, rejected because agents would
- appear human and could interact with ownership/team invariants.
- 2. **General principal supertype now:** clean long-term abstraction, rejected because it
- migrates users, memberships, project/revision provenance, audits, grants, and public
- models before write access is required.
- 3. **Separate agent principal with shared token table and parallel reader grants:**
- chosen. It preserves one `bc1_` authentication mechanism and database-enforced token
- ownership while keeping Phase 2E bounded.
- 4. **Separate agent token table/prefix:** rejected because cross-table public-ID
- uniqueness, duplicated digest/lifecycle logic, and multiple bearer parsers add risk
- without product value.

### Decision Snapshot

#### Persistence

- Add UUID `agents` with `organization_id`, trimmed `name`, `deactivated_at`, and
  microsecond timestamps. Names are non-empty, at most 100 characters, and
  case-insensitively unique per organization including inactive agents.
- Make `api_tokens.membership_id` nullable; add nullable `agent_id`; require exactly one
  principal with a database check. Keep one globally unique public ID and the `bc1_`
  format. Existing rows remain membership-bound without data rewrite.
- Add UUID `agent_project_access_grants` with organization/project/agent, fixed
  `reader` access, timestamps, unique project-agent pair, and composite tenant foreign
  keys. No agent/grant backfill.

#### Authentication and authorization

- Extend `AuthContext` with `principal_type` (`human` or `agent`) and `principal_id`.
  Existing human fields remain populated for human callers; agent contexts have
  `agent_id`, `role: "agent"`, and no human user/membership.
- Agent tokens may contain only `memory.read` and `search.keyword`. They cannot receive
  `projects.create`, `projects.manage_access`, `memory.write`, `members.manage`,
  `teams.manage`, `agents.manage`, or `tokens.manage`.
- Active agents require a retained direct reader grant plus the endpoint's fixed scope.
  They may retrieve memory and keyword-search only. Owner, human direct, and team access
  behavior remains unchanged.
- Agent deactivation immediately blocks authentication and transactionally revokes all
  active agent credentials. Retained grants become dormant. Reactivation restores no
  credential; an owner must issue a fresh one.

#### Management contracts

- Add fixed `agents.manage` to supported scopes and system discovery. Upgrade only
  active owner tokens containing every pre-Phase 2E supported scope; preserve partial
  tokens byte-for-byte. Member credentials reject `agents.manage`.
- Require owner plus `agents.manage` for:
  - `POST/GET /v1/organization/agents`
  - `PATCH/DELETE /v1/organization/agents/{agent_id}`
  - `POST /v1/organization/agents/{agent_id}/reactivate`
  - `POST/GET /v1/organization/agents/{agent_id}/tokens`
  - `DELETE /v1/organization/agents/{agent_id}/tokens/{token_id}`
- Require owner plus `projects.manage_access` for:
  - `GET /v1/projects/{project_id}/agent-access`
  - idempotent `PUT/DELETE /v1/projects/{project_id}/agent-access/{agent_id}`
- Token creation returns the raw secret once. List/revoke responses never expose raw
  tokens or digests. PUT accepts only `{"access":"reader"}`.
- Lists sort by `inserted_at`, then `id`. Lifecycle/revoke/delete operations are
  idempotent. Malformed, missing, and cross-tenant IDs return exact concealed
  `agent_not_found`, `token_not_found`, or `project_not_found`, with authorization before
  lookup and project-before-agent precedence on grant routes.

#### Concurrency and audit

- Lock the tenant-scoped agent row for lifecycle, credential, and project-grant
  mutations. A credential/grant PUT racing deactivation linearizes to a committed then
  revoked/dormant result or exact `409 agent_inactive`.
- Concurrent identical grant PUTs converge on one row and one creation audit. Concurrent
  case-insensitive names return one success and one `422 validation_failed`, never 500.
- Add transactional immutable actions `agent.create`, `agent.rename`,
  `agent.deactivate`, `agent.reactivate`, `agent_token.create`,
  `agent_token.revoke`, `agent_project_access.grant`, and
  `agent_project_access.revoke`. Management events retain the human owner as actor and
  exclude secrets/digests. No events for no-ops or read requests.
## Challenge

### Rabbit Holes

- Generalizing every human/agent/team relationship into a universal principal-policy
  engine.
- Adding agent-authored memories before non-human provenance is designed.
- Adding refresh tokens, workload identity federation, OAuth client credentials, mTLS,
  signing keys, or secret-manager integrations.

### No-Gos

- No synthetic users, fake emails, human memberships, owner role, team membership, or
  human-token impersonation for agents.
- No agent editor/write/project-create access.
- No invitations, browser sessions, passwords, OAuth/OIDC, SSO, SCIM, custom roles,
  deny rules, inheritance, generic policy engine, RLS, authorization cache, audit-query
  API, pagination, or management UI.
- No service-account/user impersonation, agent delegation, sub-agents, credential
  exchange, or agent-created credentials.

### Assumptions

- Read/search is a useful independently deployable agent capability.
- A shared `api_tokens` table is safer than duplicated bearer-token machinery.
- Existing UUID actor fields and successful API shapes remain human-only until a later
  write-provenance contract explicitly changes them.
- Phase 12 still owns broader agent-safe APIs, MCP/actions, proposals, and module tools;
  Phase 2E supplies only identity, credentials, and read authorization.

### Likely Overengineering

Introducing a generic `principals` table now would touch most identity, provenance,
authorization, audit, migration, and API surfaces while Phase 2E needs no agent writes.
Allowing editor access while storing a human `actor_id` would be dishonest and weaken
forensic integrity.

### Simpler Alternative

Treat agents as owner-named, organization-owned, read-only principals. Reuse current
bearer tokens and reader authorization through explicit agent columns/tables. Defer
principal-generalization until a concrete write/provenance spec needs it.

## Promotion map

### Spec 1 — Agent identity and credential foundation

Problem:

Brain Cloud binds every credential to a human organization membership. Automations must
share or impersonate a human credential, which prevents independent revocation, honest
identity, least-privilege project access, and trustworthy ownership/audit semantics.

Scope:

- Add UUID-backed `agents` owned by one organization with `name`, `deactivated_at`, and
  microsecond timestamps. Trim names; require non-empty names of at most 100 characters;
  enforce case-insensitive uniqueness per organization including deactivated agents.
- Make `api_tokens.membership_id` nullable, add nullable `agent_id`, and add a PostgreSQL
  check requiring exactly one principal. Preserve the current `bc1_` format, globally
  unique public IDs, digest-only storage, expiry/revocation behavior, human token rows,
  bootstrap behavior, and successful human token wire shapes.
- Add UUID-backed `agent_project_access_grants` with organization, project, agent,
  fixed `reader` access, and timestamps. Enforce one project-agent pair and composite
  project/agent tenant foreign keys with restrictive deletion. Add no agent or grant
  backfill.
- Extend authentication context with explicit `principal_type` and `principal_id`.
  Human contexts remain wire/behavior compatible and retain user/membership/role fields.
  Agent contexts identify the agent, carry role `agent`, and contain no synthetic user
  or organization membership.
- Agent credentials may request only `memory.read` and `search.keyword`. Reject
  `projects.create`, `projects.manage_access`, `memory.write`, `members.manage`,
  `teams.manage`, `agents.manage`, `tokens.manage`, unknown scopes, and empty scope sets
  with standard `422 validation_failed` field details.
- Add fixed `agents.manage` to supported scopes and system discovery. During upgrade,
  append it only to active owner tokens containing every pre-Phase 2E supported scope:
  `projects.create`, `projects.manage_access`, `memory.write`, `memory.read`,
  `search.keyword`, `members.manage`, `teams.manage`, and `tokens.manage`. Preserve
  partial tokens byte-for-byte; reject `agents.manage` for member-role credentials; make
  bootstrap/recovery full-scope tokens include it.
- Require active owner role plus `agents.manage` before resource lookup for every agent
  lifecycle and credential route.
- Add `POST /v1/organization/agents` with `{"name":"..."}` returning
  `201 {"agent":{...}}`, and `GET /v1/organization/agents` returning
  `200 {"agents":[...]}` sorted by `inserted_at`, then `id`, including active and
  inactive agents. An agent contains exactly `id`, `name`, `active`, `deactivated_at`,
  `inserted_at`, and `updated_at`.
- Add `PATCH /v1/organization/agents/{agent_id}` with `{"name":"..."}` returning the
  exact agent envelope for active or inactive agents. Normalized no-op rename returns
  the current object without an audit event.
- Add idempotent `DELETE /v1/organization/agents/{agent_id}` returning `204`.
  Deactivation retains project grants, revokes every active agent credential in the
  same transaction, and blocks authentication immediately. Add idempotent
  `POST /v1/organization/agents/{agent_id}/reactivate` returning the exact agent
  envelope. Reactivation restores no revoked credential; fresh issuance is required.
- Add `POST /v1/organization/agents/{agent_id}/tokens` with token name, allowed scopes,
  and optional expiry, returning `201 {"token":{...}}` with the raw secret exactly once.
  Reject issuance for inactive agents with exact `409 agent_inactive`.
- Add `GET /v1/organization/agents/{agent_id}/tokens` returning metadata sorted by
  `inserted_at`, then `id`, including revoked/expired credentials, with no raw secret or
  digest. Add idempotent
  `DELETE /v1/organization/agents/{agent_id}/tokens/{token_id}` returning `204`.
  Listing/revocation remains available while the agent is inactive.
- Keep `/v1/auth/tokens` human-membership-only and wire compatible. Agent credentials
  cannot create, list, or revoke credentials.
- Require active owner plus `projects.manage_access` before lookup for agent project
  grant routes. Keep human direct grants at `/access` and team grants at `/team-access`
  unchanged and type-specific.
- Add `GET /v1/projects/{project_id}/agent-access` returning
  `200 {"agent_access_grants":[...]}` sorted by `inserted_at`, then `id`, including
  grants retained for inactive agents. A grant contains exactly `id`, `project_id`,
  `agent_id`, `access`, `inserted_at`, and `updated_at`.
- Add idempotent
  `PUT /v1/projects/{project_id}/agent-access/{agent_id}` accepting only
  `{"access":"reader"}` and returning
  `200 {"agent_access_grant":{...}}` for create/no-op. Add idempotent DELETE returning
  `204`. Reject PUT for an inactive agent with exact `409 agent_inactive`; allow
  listing/revocation.
- Authorize an active agent for memory retrieval/search only when its active credential
  has the route scope and a retained direct reader grant for the tenant project.
  Deactivation, credential revocation/expiry, and grant removal take effect on the next
  request without caching or token rotation.
- Agent credentials must receive `403 forbidden` for management and write routes before
  protected lookup when a forbidden role/scope combination is presented. Missing fixed
  read/search scopes return `403`; inaccessible/missing/malformed/cross-tenant projects
  return exact `404 project_not_found`.
- Return role/scope failures before agent/project/token lookup. Return exact concealed
  `404 agent_not_found` for malformed, missing, or cross-tenant agent IDs. Nested token
  routes evaluate agent before token and return exact `404 token_not_found` only after a
  valid tenant agent. Project grant routes evaluate project before agent.
- Lock the tenant-scoped agent row for lifecycle, credential, and project-grant
  mutations. Credential issuance/grant PUT racing deactivation must linearize to either
  committed then revoked/dormant state or exact `409 agent_inactive`. Concurrent
  identical grant PUTs return `200`, converge on one row, and emit one creation audit.
  Concurrent case-insensitive agent names return one success and one exact
  `422 validation_failed`, never 500.
- Append transactional immutable audit actions `agent.create`, `agent.rename`,
  `agent.deactivate`, `agent.reactivate`, `agent_token.create`, `agent_token.revoke`,
  `agent_project_access.grant`, and `agent_project_access.revoke`, using resource types
  `agent`, `api_token`, and `agent_project_access_grant`. Management events retain the
  human owner actor and safe agent/project/scope metadata without raw secrets or digests.
  Emit no event for reads or idempotent no-ops.
- Preserve every Phase 1/2A/2B/2C/2D human identity, membership, token, owner, direct
  grant, team, memory, search, audit, health, readiness, migration, release, and wire
  contract except the documented additive scope/context behavior.
- Update OpenAPI, README, architecture, security, self-hosting, roadmap, LiveView copy,
  release upgrade/smoke documentation, Plan, AGENTS, and durable Brain context without
  implying deferred agent write/platform features exist.
- Add no agent-authored project/memory writes, editor grants, project creation, team
  membership, synthetic users, fake emails, human memberships, owner role, invitations,
  browser sessions, passwords, OAuth/OIDC, SSO, SCIM, service-account impersonation,
  refresh/exchange tokens, workload federation, mTLS, signing keys, delegation,
  sub-agents, custom roles, deny rules, inheritance, generic policy engine, RLS,
  authorization cache, audit-query API, pagination, management UI, MCP/actions,
  proposals, or module tools.

Acceptance criteria:

- PostgreSQL rejects tokens with zero/two principals and cross-organization agent grants even when application validation is bypassed; existing membership tokens migrate unchanged and still authenticate.
- Authorized owners can create/list/rename/deactivate/reactivate agents and issue/list/revoke one-time credentials with exact envelopes, deterministic ordering, tenant concealment, inactive-state rules, and idempotent behavior.
- Only active, previously full-scope owner credentials gain `agents.manage`; partial owner credentials remain unchanged and human member/agent credentials cannot receive management scopes.
- Agent credentials expose explicit agent identity, never a synthetic human identity, and can only retrieve/search a directly granted project when both fixed scope and reader grant permit it.
- Agent deactivation immediately blocks authentication, revokes active credentials transactionally, retains project grants, and never restores revoked secrets on reactivation. Fresh issuance plus retained grant restores bounded read access.
- Existing human direct/team strongest-access behavior and human token APIs remain wire compatible and isolated from agent token/grant listing.
- Concurrent grants, name collisions, and deactivation races converge on documented outcomes without duplicates, partial state, excess audits, database exceptions, or 500 responses.
- Every real management mutation commits the named immutable audit event transactionally; failures and no-ops commit no event; raw credentials/digests never enter logs, errors, lists, or audit metadata.
- OpenAPI documents all agent operations, exact field sets, roles/scopes, lifecycle, precedence, and `401`, `403`, `404`, `409`, and `422` responses while preserving existing operations.

Verification:

- Migration/domain tests cover exactly-one token principal, existing-token compatibility, full-scope-only upgrade, agent name normalization/uniqueness, tenant constraints, lifecycle, credential expiry/revocation, allowed/rejected scopes, deterministic lists, retained grants, and transactional/no-op audits.
- Authentication tests cover explicit human/agent contexts, digest matching, inactive/revoked/expired rejection, no synthetic user/membership, and unchanged human bootstrap/member behavior.
- Project/memory/search tests cover agent reader access, fixed-scope independence, authorization-before-load, immediate deactivation/revocation/grant effects, cross-tenant concealment, and unchanged human direct/team strongest access.
- Concurrency tests cover identical grant PUTs, same-name create/rename conflicts, credential/grant PUT racing deactivation, single-row convergence, exact audit counts, and absence of database exceptions/500.
- Controller tests cover exact JSON/status/field contracts, ordering, validation, malformed/cross-tenant IDs, role/scope failures, precedence, inactive states, one-time secrets, metadata-only lists, and idempotent no-ops.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Extend `make upgrade-phase2` to prove Phase 1–2D data/access remains intact, existing tokens keep one human principal, agent tables start empty, only full owner tokens gain `agents.manage`, and partial tokens remain compatible.
- Build the non-root production image and extend `make smoke-phase2` for agent lifecycle, one-time issuance, read/search authorization, write/management denial, immediate revocation/dormancy, reactivation with fresh credentials, two-organization isolation, restart persistence, and PostgreSQL outage/recovery.
- Before implementation, adopt the promoted GitHub issue into Plan metadata on a fresh execution branch and require `plan check` to pass.
- Run `brain context audit`, `plan check`, OpenAPI parsing/operation assertions, shell syntax checks, `git diff --check`, and `brain session finish`.

Dependencies: Phase 2D team access foundation is merged.

Readiness: ready.

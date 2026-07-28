---
created_at: "2026-07-28T20:54:06Z"
project: brain-cloud
slug: organization-membership-administration-foundation
status: active
title: organization membership administration foundation
type: brainstorm
updated_at: "2026-07-28T20:56:02Z"
---

# Brainstorm: organization membership administration foundation

Started: 2026-07-28T20:54:06Z

## Focus Question

What is the smallest secure Phase 2B slice that lets organization owners add, inspect, role-change, deactivate, and reactivate human memberships without introducing invitations, passwords, browser sessions, teams, or project ACLs?
## Desired Outcome

An organization owner can provision another human member, list organization memberships,
change owner/member roles, suspend or restore access, and issue a one-time scoped credential
for that member without operator database work.

## Vision

Phase 2A tenancy becomes usable by more than one release-bootstrapped owner. Membership
administration stays explicit, organization-bound, scope-gated, immediately enforceable,
and transactionally audited. Suspended members cannot authenticate, reactivation cannot
silently restore old secrets, and concurrent changes cannot remove the final active owner.

## Supporting Material

- `docs/roadmap.md`
- `docs/security.md`
- `apps/brain_cloud/lib/brain_cloud/accounts.ex`
- `openapi/brain-cloud-v1.yaml`

## Constraints

- Keep one organization per token and require owner role plus members.manage for every membership mutation. Never let an owner deactivate or demote the last active owner. Existing tokens stop authenticating immediately when membership is deactivated. No email delivery, login, teams, agent/service principals, project ACLs, pagination framework, or generic policy engine.

## Resolved Questions

- New members receive one-time target-member API tokens that owners transfer out of band.
- Deactivation and owner demotion revoke every target token transactionally.
- PostgreSQL row locks serialize mutations that could remove the final active owner.
- Target-member credential issuance requires owner role, `members.manage`, and
  `tokens.manage`.
## Ideas

- Add owner-only organization membership list/create/update/deactivate endpoints with fixed members.manage scope and non-enumerating tenant boundaries.
- Reuse normalized users by email, bind memberships to the caller organization, preserve owner safety invariants, and audit every membership lifecycle change transactionally.
- Keep invitation delivery, interactive login, teams, service accounts, agent credentials, and project permissions deferred.
## Raw Notes

## Refinement

### Problem

Phase 2A can create secure organizations, but only release operators can create an owner.
Owners cannot add another human principal, inspect memberships, change roles, suspend
access, restore access, or provision a usable member credential. Multi-user organization
tenancy therefore is not operationally usable.

### User / Value

Organization owners gain safe self-service administration. Human members gain explicitly
provisioned organization access. Operators stop editing database state for routine
membership changes.

### Appetite

One small vertical slice: schema/audit extensions, Accounts operations, owner-only JSON endpoints, OpenAPI, tests, migration, and Compose smoke. Stop when two owners can safely administer human memberships and suspended access fails on the next request.

### Remaining Open Questions

None. Exact endpoint names and error schemas are fixed in the promotion map below.

### Candidate Approaches

- Recommended: owner-only membership endpoints plus explicit one-time target-member token issuance; deactivation transactionally revokes target tokens; PostgreSQL locking preserves at least one active owner.
- Narrower but unusable: manage membership rows only and defer credential delivery.
- Broader and rejected: add invitations, email delivery, passwords, or browser sessions now.

### Decision Snapshot

Proceed with explicit owner-only membership administration plus one-time target-member
token provisioning. Require owner role and `members.manage` for membership mutations;
require `tokens.manage` as well for target-member credential issuance. Deactivation
transactionally revokes every target token, so reactivation requires fresh issuance.
Serialize owner-role mutations in PostgreSQL and reject demotion or deactivation of the
last active owner. Keep invitations, email, passwords, browser sessions, teams, service
identities, agent credentials, and project ACLs deferred.

## Challenge

### Rabbit Holes

- Turning membership provisioning into invitation/email delivery or interactive login.
- Building generic RBAC, policy engines, or arbitrary custom roles.
- Adding teams or per-project access before basic organization membership works.
- Designing service-account or agent identity through human membership APIs.

### No-Gos

- Never expose cross-organization users or memberships.
- Never allow request bodies or headers to choose a tenant.
- Never demote or deactivate the final active owner.
- Never reactivate previously valid secrets after membership restoration.

### Assumptions

- Owners can securely pass one-time member tokens out of band during this API-only phase.
- PostgreSQL row locking can serialize owner-safety decisions at current scale.
- Fixed owner/member roles and fixed scopes remain sufficient for this slice.

### Likely Overengineering

Generic authorization abstractions, invitation state machines, notification delivery, credential recovery, pagination frameworks, and team hierarchies.

### Simpler Alternative

Membership rows alone are smaller but leave members unable to authenticate. Smallest useful slice pairs membership lifecycle with explicit one-time target-member token issuance and revokes those tokens on suspension.

## Promotion map

### Spec 1 — Organization membership administration foundation

Problem:

Phase 2A establishes production API identity and organization tenancy, but only a release
operator can bootstrap an owner. Organization owners cannot add another human principal,
inspect memberships, change roles, suspend or restore access, or provision a credential
for another membership. Multi-user organization tenancy therefore remains operationally
incomplete.

Scope:

- Extend `BrainCloud.Accounts` directly; add no identity provider, policy engine, generic
  RBAC abstraction, or separate service.
- Add fixed `members.manage` scope. Require owner role plus `members.manage` for every
  membership lifecycle operation. Add the capability to bootstrap full-scope tokens and
  `/v1/system/info` without changing existing scope meanings.
- Add `POST /v1/organization/memberships` with normalized email, display name, and
  `owner` or `member` role. Reuse an existing normalized user without exposing a separate
  user-lookup API; create exactly one membership per user/organization.
- Do not silently mutate an existing membership. Active duplicates return structured
  `409 membership_exists`; inactive duplicates return structured
  `409 membership_inactive` and require explicit reactivation.
- Add `GET /v1/organization/memberships` returning only caller-organization membership
  metadata: membership ID, user ID, email, display name, role, active state, deactivation
  timestamp, and timestamps.
- Add `PATCH /v1/organization/memberships/{membership_id}` for explicit owner/member role
  changes, `DELETE /v1/organization/memberships/{membership_id}` for deactivation, and
  `POST /v1/organization/memberships/{membership_id}/reactivate` for explicit
  reactivation.
- Add `POST /v1/organization/memberships/{membership_id}/tokens` for one-time
  target-member credential issuance. Require owner role plus both `members.manage` and
  `tokens.manage`; require requested scopes to be a subset of caller scopes. Return raw
  token material only from successful creation.
- Never grant `members.manage` or `tokens.manage` to a target whose current role is
  `member`. Promotion to owner does not mutate or replace credentials; a new owner token
  must be explicitly issued.
- Lock organization membership rows during any mutation that could remove an active
  owner. Reject demotion or deactivation of the final active owner with structured
  `409 last_owner_required`, including under concurrent requests.
- Deactivation and owner-to-member demotion revoke every active token bound to the target
  membership in the same transaction. Reactivation never clears token revocation and
  therefore requires explicit fresh credential issuance.
- Scope every membership query by the authenticated organization before user or
  membership metadata loads. Missing, malformed, or cross-tenant membership IDs return
  the same structured `404 membership_not_found`. Required-scope `403` occurs before
  resource lookup.
- Add immutable transactional audit actions for membership create, role change,
  deactivate, and reactivate. Continue using `token.create` for target-member issuance
  with safe target-membership metadata; store no raw token or digest in audit data.
- Preserve existing users, memberships, credentials, projects, memories, revisions,
  audit events, public endpoints, product-route wire shapes, and readiness behavior.
- Update OpenAPI, README, security, self-hosting, roadmap state, Compose smoke coverage,
  and durable Brain context.
- Add no invitations, email delivery, passwords, browser sessions, email verification,
  OAuth/OIDC, SSO, SCIM, teams, service accounts, agent credentials, refresh tokens,
  project ACLs, custom roles, audit-query API, pagination framework, or LiveView product
  UI.

Acceptance criteria:

- An authorized owner can create a human user/membership, list it only inside the caller organization, change its role, deactivate it, and reactivate it through explicit APIs.
- Normalized duplicate users are reused safely, duplicate organization memberships are rejected deterministically, and no general email-enumeration endpoint exists.
- Target-member token creation returns one raw `bc1_...` secret once, stores only its digest, enforces caller-scope subset rules, and rejects management scopes for members.
- A caller missing either required management scope receives exact `403 forbidden` before membership lookup; a cross-tenant or nonexistent membership receives the same exact `404 membership_not_found`.
- Deactivation invalidates every target credential on the next request. Reactivation does not restore any old credential. Owner-to-member demotion also revokes every target credential so later promotion cannot resurrect prior privilege.
- The final active owner cannot be demoted or deactivated, including two concurrent attempts against the last two owners.
- Every successful membership mutation commits one safe immutable audit event with organization, actor, credential, target, action, and timestamp provenance. Failed transactions commit neither membership/token changes nor audit events.
- Existing Phase 2A bootstrap, token lifecycle, project, memory, search, system-info, health, readiness, migration, and restart-durability contracts remain compatible except for the added capability and endpoints.
- OpenAPI describes every request/response, required role/scope, exact `401`, `403`, `404`, `409`, and `422` errors, and one-time credential response without exposing digests.

Verification:

- Accounts tests cover normalized user reuse, membership uniqueness, active/inactive lifecycle, role changes, target-token scope limits, token revocation on deactivation and demotion, reactivation, last-owner protection, concurrent owner mutations, and transactional audit writes.
- Plug/controller tests cover exact authorization and non-enumerating errors, every membership endpoint, target-member token issuance, secret redaction, and existing product-route compatibility.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Run the isolated Phase 1/Phase 2A upgrade test, build the non-root image, and extend Compose smoke coverage for two-owner administration, member credential use, immediate suspension, non-restoration after reactivation, API restart durability, and PostgreSQL outage/recovery.
- Run `brain context audit`, `plan check`, `git diff --check`, and `brain session finish`.

Dependencies: Phase 2A production identity and organization tenancy merged in
[#7](https://github.com/JimmyMcBride/brain-cloud/pull/7).

Readiness: ready for promotion after planning review.

---
created_at: "2026-07-29T04:57:10Z"
project: brain-cloud
slug: project-access-control-foundation
status: active
title: project access control foundation
type: brainstorm
updated_at: "2026-07-29T05:01:43Z"
---

# Brainstorm: project access control foundation

Started: 2026-07-29T04:57:10Z

## Focus Question

What is the smallest secure Phase 2C slice that stops every active organization member from implicitly reading and writing every project without pulling teams, custom roles, invitations, interactive login, or a generic policy engine into scope?

## Desired Outcome

Organization owners can grant and revoke direct project access for human memberships. Readers can retrieve and search project memory; editors can also create memory. Existing access survives the upgrade, while new projects are private to organization owners and their member creator until explicitly shared.

## Vision

Add one narrow authorization boundary between organization membership and project data. Keep organization owners implicitly authorized across their organization, keep token scopes mandatory, and use explicit per-project reader/editor grants for ordinary human members. Every current memory path must authorize before loading project data so inaccessible projects remain indistinguishable from missing projects.

## Supporting Material

- Phase 2B organization membership administration merged in PR #10.
- `BrainCloud.Projects` currently creates and fetches projects using organization tenancy only.
- `BrainCloud.Memories` currently creates, retrieves, and searches memory using organization tenancy only.
- Existing controller scope plugs already provide the fixed-scope half of authorization.
- Product roadmap reserves teams, invitations, agent principals, interactive login, and fine-grained ACL expansion for later Phase 2 work.

## Constraints

- Preserve one public `/v1` protocol and existing successful response shapes unless this slice explicitly adds a field or endpoint.
- Preserve access to existing projects for existing member-role memberships during migration.
- Keep owner access implicit, but never let role or project grants bypass fixed token scopes.
- Authorize before resource lookup and conceal inaccessible or cross-tenant projects with the exact existing not-found contract.
- Keep grant mutation and immutable audit creation transactional.
- Do not add teams, team grants, custom roles, deny rules, inheritance, row-level security, a generic policy engine, or authorization caching.

## Open Questions

None blocking. Direct membership grants are the chosen first access-control primitive; teams can compose over them later.

## Ideas

- Add `project_access_grants` keyed by project and organization membership with `reader` or `editor` access.
- Give organization owners implicit full project access.
- Add `projects.manage_access` for owner-operated grant administration.
- Backfill editor grants for every existing member-role membership across every existing organization project, including inactive memberships so reactivation preserves prior access.
- Give a member creator an editor grant in the same transaction as project creation; an owner creator relies on implicit access.
- Return explicit grants from access-list endpoints and document owner access as implicit.
- Apply project authorization in one domain boundary reused by memory creation, retrieval, and search.

## Raw Notes

- Invitations require delivery and login work that does not close the immediate over-broad data access.
- Agent credentials require a broader principal model and should not be smuggled into a human-membership grant table.
- Team-based sharing is valuable, but direct grants establish the minimal semantics teams can later target.
- Grant changes should affect the next request without credential rotation.
- Membership suspension already blocks authentication. Reactivation should preserve grants but must not restore revoked credentials.

## Refinement

### Problem

Phase 2B lets owners add multiple humans to an organization, but every active human member still inherits organization-wide access to every project. That is too broad for meaningful multi-user use and makes later team work build on an unsafe default.

### User / Value

An organization owner can share only the projects a collaborator needs and choose whether that collaborator may read/search or also write memory. Existing installations upgrade without unexpectedly losing access.

### Appetite

One focused implementation spec and one implementation PR. Database grant model, domain authorization, three management endpoints, OpenAPI, audit events, migration backfill, and full tests/smoke coverage are in scope.

### Remaining Open Questions

None required before canonical spec promotion.

### Candidate Approaches

1. Direct membership grants with owner implicit access. Smallest secure slice; chosen.
2. Teams first. Better group administration eventually, but adds team lifecycle and membership semantics before the core project permission boundary exists.
3. Generic policy engine or database row-level security. Powerful, but disproportionate to two fixed access levels and harder to audit across the existing Phoenix contexts.

### Decision Snapshot

Use direct project-to-human-membership grants with fixed `reader` and `editor` values. Owners remain implicitly authorized. Token scopes remain an independent required check. Backfill existing member access, then make newly created projects private by default.

## Challenge

### Rabbit Holes

- Turning access levels into arbitrary role definitions.
- Adding negative grants, inheritance, or precedence rules.
- Building teams, invitations, email, login, or agent principals alongside the project boundary.
- Caching authorization before correctness and invalidation semantics are proven.
- Adding a project access UI before the API contract is stable.

### No-Gos

- No organization-wide implicit project access for newly created projects assigned to ordinary members.
- No grant-based escalation past token scopes.
- No existence leaks through different error status, body, or lookup ordering.
- No unrestricted third-party policy code or private authorization exceptions.

### Assumptions

- `reader` means memory retrieval and keyword search.
- `editor` includes reader capabilities plus memory creation.
- Organization owners may manage all project grants and access all organization projects.
- Existing inactive memberships should receive migration grants so later reactivation matches pre-upgrade access, while authentication remains blocked during suspension.
- Deleting an already absent grant is idempotently successful.

### Likely Overengineering

A generic authorization framework, per-action ACL rows, team hierarchy, database RLS, or cached policy evaluation would add more moving parts than this fixed two-level boundary needs.

### Simpler Alternative

Keep organization-wide member access and add only owner-managed write restrictions. Rejected: it leaves project memory readable across unrelated collaborators and does not establish the needed project boundary.

## Promotion map

### Spec 1 — Project access control foundation

#### Problem

Active organization members currently inherit access to every organization project. Brain Cloud needs a project boundary before broader collaboration can be safe.

#### Scope

- Add a UUID-backed `project_access_grants` table with `project_id`, `organization_membership_id`, fixed `reader` or `editor` access, timestamps, uniqueness on the project-membership pair, supporting indexes, and database constraints.
- Add `projects.manage_access` to supported fixed scopes and system discovery capabilities.
- Treat active organization owners as implicitly authorized for every organization project while continuing to require the endpoint's fixed token scope.
- Treat an explicit reader grant as authorization for memory retrieval and keyword search, and an explicit editor grant as reader authorization plus memory creation.
- Keep `projects.create` as the project-creation scope. In the creation transaction, give a member creator an editor grant; let an owner creator rely on implicit access.
- Backfill editor grants for every existing member-role membership and every existing project in the same organization, including inactive memberships. Do not backfill owners.
- Add `GET /v1/projects/{project_id}/access` to list explicit grants, `PUT /v1/projects/{project_id}/access/{membership_id}` with `{"access":"reader"|"editor"}` to create or replace a grant idempotently, and `DELETE /v1/projects/{project_id}/access/{membership_id}` to revoke idempotently.
- Require owner role plus `projects.manage_access` for all grant-management endpoints and return authorization failures before project or membership lookup.
- Return exact `404 project_not_found` for malformed, missing, inaccessible, or cross-tenant project identifiers. Return exact `404 membership_not_found` for missing or cross-tenant target memberships. Return `409 membership_inactive` when granting to an inactive membership, while allowing deletion of a stored inactive-membership grant.
- Enforce project authorization before loading project or memory data in every current memory creation, retrieval, revision, and search path.
- Make grant changes effective on the next request without token rotation. Preserve grants through membership suspension/reactivation while preserving existing credential revocation rules.
- Append immutable audit events transactionally for grant creation, access changes, and revocation without storing credential secrets or digests.
- Update OpenAPI, architecture, security, self-hosting, roadmap, project context, release upgrade, and smoke documentation for the new boundary.
- Defer teams and team grants, invitations, email/password login, OAuth/SSO/SCIM, service or agent principals, project listing, public links, custom roles, deny rules, inheritance, RLS, generic policy engines, authorization caches, audit-query APIs, pagination, and access-management UI.

#### Acceptance criteria

- Existing member-role credentials retain their pre-upgrade access to existing projects through migration grants, including grants retained for inactive memberships pending later reactivation.
- A new project is accessible to organization owners and its member creator, but not to another member until that member receives an explicit grant.
- A reader with the required fixed token scopes can retrieve and search project memory but cannot create memory; an editor with the required scopes can retrieve, search, and create.
- Fixed token scopes remain mandatory for every operation and neither owner role nor a project grant escalates a credential beyond its scopes.
- Grant PUT creates or changes the explicit access idempotently, grant DELETE is idempotent, and revocation blocks the affected project on the next request without token rotation.
- Missing owner role or `projects.manage_access` returns the exact authorization response before resource lookup, while missing, malformed, inaccessible, and cross-tenant projects share exact `404 project_not_found` behavior.
- Missing or cross-tenant target memberships return exact `404 membership_not_found`; attempts to grant access to inactive memberships return exact `409 membership_inactive`.
- Membership suspension blocks authentication, reactivation preserves stored grants, and previously revoked credentials remain revoked so a fresh credential is required.
- Grant creation, access change, and revocation emit immutable audit events in the same transaction and never record token plaintext or digests.
- Existing public contracts remain compatible except for the documented capability, access endpoints, and intentional authorization applied to newly private project data paths.
- OpenAPI documents all new operations, schemas, fixed scopes, and exact error responses without adding deferred Phase 2 features.

#### Verification

- Project-domain tests cover migration backfill, owner implicit access, member-creator grants, reader/editor decisions, idempotent grant changes and revocation, inactive-membership handling, tenant concealment, and transactional audit events.
- Memory and search tests prove both grant and fixed-scope enforcement, authorization before resource loading, immediate revocation, and exact concealment behavior.
- Controller tests cover exact JSON/status contracts for access listing, grant creation/change/revocation, role/scope failures, cross-tenant targets, inactive memberships, and unauthorized project access.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation and migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Run the release upgrade path, production Docker build, and Compose smoke tests for owner implicit access, new-project privacy, reader/editor behavior, immediate revocation, suspension/reactivation, restart persistence, and PostgreSQL outage recovery.
- Run `brain context audit`, `plan check`, OpenAPI parsing, shell syntax checks, `git diff --check`, and finish the Brain session.

#### Dependencies

- Phase 2B organization membership administration from merged PR #10.

#### Readiness

Ready for canonical spec promotion after planning review.

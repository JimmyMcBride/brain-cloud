---
status: done
title: Team access foundation
type: spec
updated_at: "2026-07-29T09:04:36Z"
---

## Spec
Team access foundation

## Goals
- Add reusable, tenant-safe teams and team-derived project reader/editor access.
- Preserve direct grants and every existing Phase 2C authorization contract.
- Make team lifecycle, membership, grants, and audits transactional, immediate, and concurrency-safe.
- Expose the complete owner-managed HTTP contract, discovery metadata, upgrade path, and deployment verification.

## Non-Goals
- No hard deletion, nesting, team managers, team roles, invitations, identity-provider integration, service identities, deny rules, inheritance, generic policy engine, RLS, authorization cache, effective-access endpoint, audit-query API, pagination, or access-management UI.
- No changes to the direct project-access wire contract or deferred collaboration features.

## Constraints
- Keep one Phoenix umbrella and PostgreSQL as the authoritative store.
- Enforce tenant alignment with composite database foreign keys and preserve retained links/grants through soft deactivation.
- Require fixed scopes independently from project access and conceal cross-tenant identifiers.
- Serialize team mutations through tenant-scoped team row locks and emit audits only for committed state changes.

## Problem
Phase 2C protects projects with direct reader/editor grants, but owners must repeat those
grants for every person. Brain Cloud has no reusable organization group boundary, making
multi-project collaboration tedious and error-prone as organizations grow.

## Scope
- Add UUID-backed `teams`, `team_memberships`, and `team_project_access_grants` tables.
  Every table is organization-scoped and timestamped. Teams also store
  `deactivated_at`. Team names are trimmed, non-empty, at most 100 characters, and
  case-insensitively unique inside one organization, including deactivated teams.
  Team-membership pairs and project-team grant pairs are unique.
- Add composite parent indexes and foreign keys so PostgreSQL rejects a team membership
  unless its team and organization membership share an organization, and rejects a team
  project grant unless its team and project share an organization. Use restrictive
  foreign keys; Phase 2D never permanently deletes a team or cascades its links/grants.
- Add fixed `teams.manage` to supported scopes and system discovery. During upgrade,
  append it only to active owner tokens containing every pre-Phase 2D supported scope:
  `projects.create`, `projects.manage_access`, `memory.write`, `memory.read`,
  `search.keyword`, `members.manage`, and `tokens.manage`. Leave every partial owner
  token unchanged and reject `teams.manage` when issuing credentials to member-role
  memberships. New bootstrap/recovery full-scope tokens include it.
- Require owner role plus `teams.manage` for team lifecycle and membership operations.
  Continue requiring owner role plus `projects.manage_access` for team project grant
  operations.
- Add `POST /v1/organization/teams` with `{"name":"..."}` returning
  `201 {"team":{...}}`, and `GET /v1/organization/teams` returning
  `200 {"teams":[...]}` sorted by `inserted_at` then `id`, including active and
  deactivated teams. A team contains exactly `id`, `name`, `active`, `deactivated_at`,
  `inserted_at`, and `updated_at`.
- Add `PATCH /v1/organization/teams/{team_id}` with `{"name":"..."}` returning the exact
  `200 {"team":{...}}` envelope for active or deactivated teams. A normalized no-op
  rename returns the current team without an audit event.
- Add idempotent `DELETE /v1/organization/teams/{team_id}` returning `204` to deactivate
  a team without deleting its membership links or project grants. Add idempotent
  `POST /v1/organization/teams/{team_id}/reactivate` returning
  `200 {"team":{...}}`. Repeated deactivate/reactivate operations emit no extra audit
  event.
- Add `GET /v1/organization/teams/{team_id}/members` returning
  `200 {"team_memberships":[...]}` sorted by `inserted_at` then `id` for active or
  deactivated teams. Each link contains exactly `id`, `team_id`, `membership_id`, and
  `inserted_at`.
- Add idempotent
  `PUT /v1/organization/teams/{team_id}/members/{membership_id}` returning
  `200 {"team_membership":{...}}` for create or no-op, and idempotent
  `DELETE /v1/organization/teams/{team_id}/members/{membership_id}` returning `204`
  whether a valid target link existed or not. Reject PUT against a deactivated team with
  exact `409 team_inactive`; allow listing/removal while deactivated.
- Allow an organization membership to belong to multiple teams and allow either current
  organization role to be linked. Reject PUT for an inactive organization membership
  with exact `409 membership_inactive`; allow removal of its stored link. Preserve team
  links through organization membership deactivation/reactivation and owner/member role
  changes. Links remain dormant while either membership or team is inactive and become
  effective again after explicit reactivation and fresh credential issuance where the
  existing membership lifecycle requires it.
- Keep `GET /v1/projects/{project_id}/access` direct-grant-only. Add separate
  `GET /v1/projects/{project_id}/team-access` returning
  `200 {"team_access_grants":[...]}` sorted by `inserted_at` then `id`. Each grant
  contains exactly `id`, `project_id`, `team_id`, `access`, `inserted_at`, and
  `updated_at`. Listing remains available for a deactivated team.
- Add idempotent
  `PUT /v1/projects/{project_id}/team-access/{team_id}` with
  `{"access":"reader"|"editor"}` returning
  `200 {"team_access_grant":{...}}` for create, change, or no-op, and idempotent
  `DELETE /v1/projects/{project_id}/team-access/{team_id}` returning `204` whether a
  valid target grant existed or not. Empty teams may receive a grant. Reject PUT against
  a deactivated team with exact `409 team_inactive`; allow listing/revocation.
- Keep active organization owners implicitly authorized for every organization project.
  For an active member, authorize reader access when any direct grant or grant from an
  active linked team is `reader` or `editor`, and authorize editor access when any such
  grant is `editor`. Strongest access wins; there are no deny rules. Continue requiring
  each endpoint's fixed token scope independently of project access.
- Make membership, grant, access-level, team deactivation, and team reactivation changes
  effective on the next request without token rotation or authorization caching.
  Deactivation makes every retained team link/grant dormant; explicit reactivation
  restores remaining team-derived access. Preserve Phase 2C member-creator direct editor
  grants and every existing direct-grant behavior.
- Serialize team lifecycle, team-membership, and team-project-grant mutations by locking
  the tenant-scoped team row. Implement conflict-safe upserts so concurrent identical
  membership PUTs or identical team-grant PUTs both return `200`, converge on one row,
  and emit exactly one creation audit event. Concurrent case-insensitive name conflicts
  return one success and one exact `422 validation_failed`, never a database exception or
  `500`. A PUT racing team deactivation linearizes to either a committed then-dormant
  mutation or exact `409 team_inactive`.
- Return role/scope failures before team, project, or membership lookup. Return exact
  `404 team_not_found` for malformed, missing, or cross-tenant team IDs and exact
  `404 membership_not_found` for malformed, missing, or cross-tenant membership IDs. On
  project team-access routes, return exact `404 project_not_found` before evaluating the
  team, then `404 team_not_found`. Return standard `422 validation_failed` with field
  details for invalid names/access or duplicate names.
- Append immutable transactional audit actions `team.create`, `team.rename`,
  `team.deactivate`, `team.reactivate`, `team_membership.add`,
  `team_membership.remove`, `team_project_access.grant`,
  `team_project_access.change`, and `team_project_access.revoke`. Use resource types
  `team`, `team_membership`, and `team_project_access_grant`; record relevant team,
  membership, project, access, and previous-access metadata without credential secrets
  or digests. Because deactivation preserves related rows, the audit trail plus current
  state can reconstruct access. Emit no event for idempotent no-ops.
- Add no team-data backfill. Existing direct grants preserve all current access. Extend
  the isolated upgrade path to prove Phase 1/2A/2B/2C data and access remain intact,
  new team tables start empty, only previously full-scope owner tokens gain
  `teams.manage`, and partial tokens remain byte-for-byte scope compatible.
- Update OpenAPI, README, architecture, security, self-hosting, roadmap, LiveView
  bootstrap copy, release upgrade/smoke documentation, and durable Brain context without
  implying deferred collaboration features exist.
- Add no hard team deletion, nested teams, team managers, team-level roles, invitations,
  email delivery, passwords, browser sessions, OAuth/OIDC, SSO, SCIM, service or agent
  identities, project listing, custom roles, deny rules, inheritance, generic policy
  engine, RLS, authorization cache, effective-access endpoint, audit-query API,
  pagination, or access-management UI.

## Acceptance Criteria
- PostgreSQL rejects cross-organization team memberships and team project grants even when application validation is bypassed; team names cannot collide case-insensitively inside one organization.
- Authorized owners can create, list, rename, deactivate, and reactivate teams; inspect retained memberships/grants while inactive; and idempotently add/remove active organization memberships with exact documented responses.
- Deactivation preserves every team membership and project grant while removing all team-derived access on the next request. Explicit reactivation restores remaining access, making the lifecycle fully auditable without hard deletion.
- Team lifecycle/membership endpoints require owner plus `teams.manage`; project team-access endpoints require owner plus `projects.manage_access`. Only active owner credentials containing every pre-Phase 2D scope gain `teams.manage`; partial credentials remain unchanged and member-role credentials cannot receive it.
- An active member gains reader/editor access from an active team on the next request, loses only that source when links/grants are removed or the team is inactive, and retains stronger direct or other-team access. Editor outranks reader.
- Membership deactivation still blocks authentication. Membership/team reactivation never restores revoked credentials; fresh issuance remains required by existing membership lifecycle rules. Role changes preserve links, owner access stays implicit, and later demotion activates applicable grants after fresh credential issuance.
- Existing Phase 2C direct access listing/mutations remain wire compatible and direct-only. Member project creators still receive a direct editor grant.
- Concurrent identical membership/team-grant PUTs converge on one row with successful responses and one create audit event. Concurrent name conflicts and lifecycle races return documented outcomes without duplicates, partial state, or `500`.
- Identifiers remain tenant-concealed with documented error precedence. Invalid names/access, inactive-team PUTs, and inactive-member additions return exact structured responses.
- Every real mutation commits its named immutable audit event transactionally. Failed mutations/no-ops commit no event, and retained inactive state preserves forensic access history.
- Existing identity, token, membership, project, memory, revision, search, health, readiness, system-info, migration, restart-durability, and PostgreSQL outage/recovery contracts remain compatible except for documented team behavior.
- OpenAPI documents every operation, schema, role/scope rule, lifecycle state, and exact `401`, `403`, `404`, `409`, and `422` response without deferred Phase 2 features.

## Verification
- Domain tests cover full-scope-only upgrade, partial/member-scope rejection, name normalization/uniqueness, tenant alignment, deterministic lists, soft lifecycle, inactive membership/team behavior, role persistence, transactional/no-op audits, and no team-data backfill.
- Concurrency tests cover identical membership/team-grant PUTs, same-name create/rename collisions, deactivation racing membership/grant PUT, single-row convergence, exact audit counts, and absence of database exceptions/`500`.
- Project/memory/search tests cover implicit owner, direct-only, team-only, combined strongest-grant, multiple-team resolution, fixed scopes, authorization-before-load, immediate lifecycle/grant effects, and tenant concealment.
- Controller tests cover exact JSON/status contracts, ordering, field sets, validation, malformed identifiers, role/scope failures, cross-tenant targets, inactive states, idempotent no-ops, and deactivation/reactivation.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Run `make upgrade-phase2`, build the non-root production image, and extend `make smoke-phase2` for team lifecycle, membership, reader/editor/strongest access, immediate dormant/restored access, two-organization isolation, restart persistence, and PostgreSQL outage/recovery.
- Before implementation, adopt GitHub issue #14 into Plan metadata on the fresh execution branch and require `plan check` to pass.
- Run `brain context audit`, `plan check`, OpenAPI parsing, shell syntax checks, `git diff --check`, and `brain session finish`.

## Dependencies
- blocked by: none

## Readiness
- status: ready
- note: ready.

## Source
- .plan/brainstorms/team-access-foundation.md

> Canonical source: https://github.com/JimmyMcBride/brain-cloud/issues/14. This local mirror exists for Plan CLI execution.

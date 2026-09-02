---
created_at: "2026-09-01T14:31:46Z"
project: brain-cloud
slug: human-invitation-and-acceptance-foundation
status: active
title: Human invitation and acceptance foundation
type: brainstorm
updated_at: "2026-09-01T14:34:40Z"
---

# Brainstorm: Human invitation and acceptance foundation

Started: 2026-09-01T14:31:46Z

## Focus Question

What is the smallest secure Phase 2G slice that lets organization owners invite humans and recipients accept membership without adding passwords, browser sessions, email delivery, OAuth/OIDC, SSO, or SCIM?
## Desired Outcome

Owners create an auditable, member-only invitation and hand one acceptance secret to the recipient through an external trusted channel. The recipient accepts exactly once and receives its own initial Brain Cloud credential without an owner creating or sharing that credential on its behalf.

## Vision

Human onboarding becomes an explicit organization action followed by an explicit recipient action. Brain Cloud owns invitation integrity, expiry, acceptance, membership creation, initial credential issuance, and provenance while remaining API-first and independent from email delivery or interactive login.

## Supporting Material

- `docs/security.md` Phase 2A–2F identity, token, tenant, and audit boundaries.
- GitHub spec #9 and the existing owner-managed membership/token APIs.
- GitHub spec #19 and merged PR #21 for exact human/agent provenance and Phase 2F completion.

## Constraints

- Preserve existing owner-created membership and target-token APIs.
- Require owner plus members.manage to create/list/revoke invitations; tokens.manage governs requested initial credential scopes.
- Store only invitation lookup ID and constant-time-comparable secret digest; raw acceptance secret appears once.
- Make invitation acceptance public but non-enumerating, expiring, single-use, and transactionally race-safe.
- Bind invitation permanently to organization, normalized email, inviter-supplied display name, fixed member role, creator membership, expiry, and requested initial scopes.
- Reuse an existing user only when normalized email matches; reject an existing membership without exposing tenant details.
- Create user when absent, membership, initial credential, invitation consumption, and audit events in one transaction.
- No email delivery, passwords, browser sessions, email verification, OAuth/OIDC, SSO, SCIM, refresh tokens, or UI.
- No custom roles, team assignment, project grants, automatic access, or generic policy engine.

## Open Questions

- None block promotion. The decision snapshot resolves the initial role, display-name, uniqueness, and audit questions.
## Ideas

- Add owner-managed, organization-scoped invitations with one-time expiring acceptance secrets stored only as digests.
- Acceptance creates or links the human identity and activates one membership exactly once, with transactional audit provenance and an initial constrained credential.
- Keep delivery out of scope: return the acceptance secret once so an external trusted channel can deliver it.
## Raw Notes

## Refinement

### Problem

Brain Cloud owners can provision human memberships and credentials, but recipients cannot claim their own identity or membership. Owners must create an identity and manually hand over a bearer token, which weakens ownership, lifecycle clarity, and audit provenance.

### User / Value

Organization owners gain an auditable onboarding boundary; invited humans can accept membership themselves through the API and receive a one-time initial credential without impersonation, shared secrets, or an interactive identity stack.

### Appetite

One focused Phase 2G spec and implementation PR. Extend the existing accounts context, Ecto schema, API controllers, OpenAPI, upgrade verification, and Compose smoke. Add no mailer, job system, session system, or frontend.

### Remaining Open Questions

None for promotion. Exact field names and response envelopes are fixed in the promotion map below.

### Candidate Approaches

- Recommended: store a separate pending invitation; create or reuse the user and create the membership only during one locked acceptance transaction.
- Alternative: pre-create an inactive membership and attach a claim secret; rejected because deactivation already means suspended access and should not double as pending acceptance.
- Alternative: require interactive login before acceptance; rejected because it couples this slice to passwords, sessions, recovery, and email verification.

### Decision Snapshot

Proceed with a separate invitation table and a public one-time acceptance endpoint. Phase 2G invitations are member-only. Creating an invitation requires active owner plus members.manage and tokens.manage because the inviter fixes the display name and initial member-safe scopes. Allow one unresolved invitation per organization and normalized email; expired invitations are unusable but must be revoked before reissue, and duplicate creation returns conflict rather than rotating a secret. The raw invitation secret is returned once, expires within a bounded window, and is stored only as a digest. Acceptance takes only that secret, row-locks the invitation, creates or reuses the normalized-email user without changing an existing profile, creates one active member membership, issues one initial credential, consumes the invitation, and emits one invitation.accept audit in one transaction. Keep all login, delivery, owner invitations, grants, teams, and UI deferred.

## Challenge

### Rabbit Holes

- Turning invitation delivery into a mailer, queue, template, notification, or retry system.
- Building browser login, session, password reset, email verification, OAuth/OIDC, SSO, or SCIM alongside acceptance.
- Generalizing one-time secrets into a reusable token/exchange framework.
- Adding organization discovery, invitation preview, or error distinctions that leak tenant or email state.
- Designing owner invitations, team assignment, project grants, or custom role policy now.
- Adding cleanup jobs for expired rows before any background jobs otherwise exist.

### No-Gos

- No plaintext invitation secrets at rest, in logs, audits, list responses, or errors.
- No invitation acceptance that can succeed twice or race into duplicate membership/token/audit rows.
- No accepting arbitrary role or scope fields from the recipient.
- No changing an existing user's email or display name during acceptance.
- No creating a second membership for the same user and organization.
- No bypass of existing member-scope restrictions or owner authorization.

### Assumptions

- Possession of the one-time secret delivered through an external trusted channel is sufficient acceptance proof for this API-first slice; it is not email verification.
- Normalized email remains the global human identity key.
- Member-only invitations avoid elevated-role acceptance risk while still closing the main onboarding gap.
- Expired and consumed invitations may remain stored for auditability; authorization filters them without a cleanup job.
- Existing bc1 credential issuance can be reused after membership creation without exposing its digest.

### Likely Overengineering

A generic identity exchange or notification platform. Keep one invitation schema, three owner management operations, one public acceptance operation, existing token machinery, and explicit state transitions.

### Simpler Alternative

Owner creates a member-only invitation with email, display name, initial scopes, and expiry and receives one raw secret. Owner can list safe metadata or revoke it. Recipient posts only the secret to one public endpoint. Brain Cloud atomically validates, consumes, creates or reuses identity, creates membership, issues a fixed-name initial token with inviter-selected scopes, audits acceptance, and returns the membership and token once.

## Promotion map

### Spec 1 — Human invitation and acceptance foundation

Problem:

Brain Cloud owners can provision human memberships and credentials, but recipients
cannot claim membership and obtain their own first credential. Owners currently create
the identity and manually transfer a bearer credential, collapsing organization approval,
recipient acceptance, and credential possession into one administrative action.

Scope:

- Mark Phase 2F complete from merged PR #21, then implement one bounded Phase 2G
  invitation and acceptance slice in the existing Phoenix umbrella. Add no new OTP
  application, worker, job system, mailer, or frontend.
- Add organization-owned human invitation persistence with binary UUIDs, normalized
  email, inviter-supplied display name, fixed `member` role, inviter membership,
  requested initial credential scopes, unique public lookup ID, SHA-256 digest of the
  full raw acceptance token, required expiry, nullable accepted/revoked timestamps,
  and accepted membership provenance. Store no raw secret.
- Use a distinct `bci1_<public_id>_<secret>` acceptance-token format with the same
  32-character public ID and 43-character URL-safe secret entropy shape as existing
  `bc1` credentials. Filter token/secret parameters from Phoenix logs and compare
  digests in constant time after public-ID lookup.
- Add PostgreSQL foreign keys and composite tenant constraints so invitation,
  organization, inviter membership, and accepted membership cannot cross tenants.
  Enforce one unresolved invitation per organization and normalized email with a
  partial unique index over rows whose accepted/revoked timestamps are null. Expiry
  makes a row unusable but does not remove it from that unresolved slot; an owner must
  revoke it before reissuing.
- Add authenticated owner routes `POST /v1/organization/invitations`,
  `GET /v1/organization/invitations`, and
  `DELETE /v1/organization/invitations/{invitation_id}`. Create requires active owner,
  `members.manage`, and `tokens.manage`; list/revoke require active owner and
  `members.manage`. Authorization precedes validation and lookup.
- Invitation create accepts exactly normalized `email`, trimmed `display_name`,
  inviter-selected `scopes`, and `expires_at`. Role is not accepted and is always
  `member`. Expiry must be in the future and no more than seven days ahead. Scopes
  must be a subset of the creating credential and must exclude all member-forbidden
  management scopes under the existing target-member rules.
- Successful create returns `201` with safe invitation metadata and the raw
  `acceptance_token` exactly once. The exact invitation object contains `id`, `email`,
  `display_name`, constant `role: "member"`, `scopes`, `status`, `expires_at`,
  `accepted_at`, `revoked_at`, `accepted_membership_id`,
  `created_by_membership_id`, `inserted_at`, and `updated_at`. Create returns
  `{"invitation": <object>, "acceptance_token": <raw>}`; list returns
  `{"invitations": [<object>]}` ordered by `inserted_at` then ID. Status is exactly
  `pending`, `expired`, `accepted`, or `revoked`, with accepted/revoked terminal state
  taking precedence over wall-clock expiry. No create/list/revoke response exposes a
  digest or a previously returned secret.
- Creating for an email that already has any membership in the organization returns
  existing exact `409 membership_exists`. Creating while an unresolved invitation
  exists returns `409 invitation_exists`; it never rotates or redisplays the secret.
  Validation failures use existing exact `422 validation_failed` field details.
- Revoke uses tenant-concealed UUID lookup, locks the invitation row, sets
  `revoked_at`, and emits one audit only for a real pending/expired-to-revoked change.
  Repeating revoke for an already revoked or accepted row returns `204` without a new
  audit. Missing, malformed, and cross-tenant IDs return exact
  `404 invitation_not_found`.
- Add public `POST /v1/invitations/accept` under the JSON pipeline without bearer
  authentication. It accepts only `acceptance_token`; malformed, unknown,
  wrong-secret, expired, revoked, accepted/replayed, or otherwise unavailable tokens
  return the same exact `404 invitation_not_found` response without tenant, email,
  user, state, or expiry disclosure.
- Acceptance row-locks the invitation and performs every durable effect in one
  transaction: revalidates token digest/state/expiry, finds the globally normalized
  email user or creates it with the inviter-supplied display name, preserves an
  existing user's email/display name, confirms no organization membership exists,
  creates one active `member` membership, issues one non-bootstrap `bc1` credential
  named `Invitation acceptance` with the pre-approved scopes and `expires_at: null`, marks the invitation
  accepted with membership provenance, and emits exactly one `invitation.accept`
  audit with the accepted human user actor and safe invitation/membership/token scope
  metadata. Emit no separate membership/token audit for this composite operation.
- Successful acceptance returns `201` with the existing exact membership shape and
  existing one-time created-token shape under exact envelope
  `{"membership": <membership>, "token": <created-token>}`. It never returns the
  acceptance token. Direct owner-created memberships and target-token issuance remain
  unchanged.
- If direct membership creation wins a race after invitation creation, acceptance
  returns exact `409 membership_exists` and commits no user, membership, token,
  invitation state change, or acceptance audit. Existing inactive memberships also
  count as existing; owners use the established reactivation flow.
- Acceptance/replay, acceptance/revoke, duplicate-create, and acceptance/direct-
  membership races must linearize without duplicate memberships, credentials,
  acceptance audits, partial state, integrity errors, or 500 responses. An accepted
  invitation cannot later be revoked into a different terminal state.
- Add transactional `invitation.create`, `invitation.revoke`, and
  `invitation.accept` audit actions. Management audits use the authentic owner and
  current API token; acceptance uses the accepted human user and issued API token.
  Each event uses the invitation as its resource. Create metadata contains only
  scopes and expiry; revoke metadata is empty; acceptance metadata contains only
  accepted membership ID, issued token ID, and scopes. Raw acceptance/API tokens,
  digests, email, and display name never enter audit metadata.
- Preserve all Phase 1–2F human/agent identity, membership, team, project access,
  token, provenance, memory, search, migration, release, health, readiness, and
  successful wire behavior. Add no fixed permission scope; reuse `members.manage`
  and `tokens.manage`.
- Update OpenAPI, README, architecture, security, self-hosting, roadmap, LiveView copy,
  release upgrade/smoke documentation, Plan, AGENTS, and durable Brain context without
  implying interactive identity or invitation delivery exists.
- Add no owner invitations, invitation update/resend, secret recovery/rotation, email
  delivery, email verification, passwords, browser sessions, password recovery,
  OAuth/OIDC, SSO, SCIM, MFA, refresh/exchange tokens, rate-limiting framework,
  organization discovery, team assignment, project grants, automatic access, custom
  roles, deny rules, generic policy engine, audit-query API, pagination, cleanup jobs,
  background workers, UI, proposals, Planning, MCP/actions, or module work.

Acceptance criteria:

- PostgreSQL rejects cross-tenant inviter/accepted membership references and duplicate unresolved organization/email invitations when application validation is bypassed. The migration adds no invitations or users, changes no existing scopes/data, and has safe forward/rollback behavior for supported upgrades.
- Create/list/revoke enforce exact owner/scope precedence, tenant concealment, normalization, seven-day expiry bound, member-safe scope subset validation, deterministic ordering/status, single-display secrets, duplicate conflict, and idempotent audit-free terminal-state revocation.
- Raw acceptance secrets appear only in the successful create response. Database, schema inspection, logs, errors, list/revoke/accept responses, and audit metadata contain no raw acceptance/API secret or digest.
- A valid pending invitation creates or reuses exactly one human user, creates exactly one active member membership, issues exactly one initial credential with the fixed name and approved scopes, marks exactly one invitation accepted, and commits exactly one authentic `invitation.accept` audit in the same transaction.
- Existing global users retain their email/display name and can accept membership in a new organization. Existing active or inactive membership in the target organization prevents acceptance with `409 membership_exists` and no partial durable changes.
- Malformed, unknown, wrong-secret, expired, revoked, accepted, and replayed acceptance tokens all return exact `404 invitation_not_found` without state or tenant leakage and commit no durable changes.
- Concurrent accepts yield one success and one concealed rejection. Accept/revoke and accept/direct-membership races commit exactly one valid serialized terminal outcome, with exact membership/token/audit counts and no integrity errors or 500 responses.
- Existing direct membership creation, lifecycle, token issuance/revocation, final-owner protection, human/agent authorization, project access, provenance, memory, and search controller/domain tests remain wire compatible.
- OpenAPI contains only the four implemented invitation operations, exact envelopes, safe fields, permission/precedence notes, and documented `201`, `204`, `401`, `403`, `404`, `409`, and `422` responses. Reserved later identity work remains absent.

Verification:

- Migration/schema tests cover normalization, required expiry, public-ID uniqueness, unresolved-email uniqueness, terminal states, composite tenant constraints, no backfill, and rollback/forward behavior.
- Domain tests cover owner/scope precedence, member-safe scope subsets, create/list/revoke states, secret hashing and constant-time verification, existing-user reuse, profile preservation, new membership/token/audit atomicity, expiry boundary, replay/revocation, and failure rollback.
- Raw PostgreSQL tests bypass changesets to prove tenant and uniqueness constraints. Separate-connection concurrency tests gate and verify accept/accept, accept/revoke, duplicate create, and accept/direct-membership races.
- Controller tests assert exact JSON/status/field contracts, safe metadata, filtered secrets, malformed/cross-tenant management IDs, every public invalid-token class, create validation, duplicate conflicts, existing-user/new-user acceptance, and unchanged direct membership/token behavior.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Extend `make upgrade-phase2` to prove Phase 1–2F data, credentials, scopes, grants, provenance, and APIs remain intact with an empty invitation table, then exercise one post-upgrade invitation acceptance.
- Build the non-root production image and extend `make smoke-phase2` for invitation create/list, single-display secret handling, recipient acceptance, new credential authentication, replay denial, revoke/reissue, existing-user cross-organization acceptance, restart persistence, two-organization isolation, and PostgreSQL outage/recovery.
- Run `brain context audit`, `plan check`, OpenAPI parsing/operation assertions, shell syntax checks, `git diff --check`, and `brain session finish`.

Dependencies: Phase 2F agent-authored memory provenance foundation is merged through
PR #21; spec #19 is closed.

Readiness: ready.

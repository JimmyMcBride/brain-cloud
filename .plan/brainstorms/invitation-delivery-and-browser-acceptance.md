---
created_at: "2026-09-07T02:50:39Z"
project: brain-cloud
slug: invitation-delivery-and-browser-acceptance
status: active
title: Invitation delivery and browser acceptance
type: brainstorm
updated_at: "2026-09-07T02:50:39Z"
---

# Brainstorm: Invitation delivery and browser acceptance

Started: 2026-09-07T02:50:39Z

## Focus Question

How can invited humans join through email and a browser while preserving Phase 2G admission semantics and Phase 2H authentication boundaries?
## Desired Outcome

An owner sends a member invitation. The recipient opens an email, explicitly joins through a browser, signs in, and reaches the existing organization shell without using an API client.

## Vision

Make the existing invitation and sign-in foundations usable together. Keep this an invitation bridge, not an administration dashboard or new identity system. Recommendations below await user review before canonical promotion.

## Supporting Material

- Phase 2G spec #22 and Phase 2H spec #25; implementation PR #27 is merged.
- `apps/brain_cloud/lib/brain_cloud/accounts.ex`: invitation issuance stores only a digest; acceptance currently always creates an API credential.
- `apps/brain_cloud_web/lib/brain_cloud_web/controllers/invitation_controller.ex`: existing create/list/revoke API contract.
- `docs/security.md`: admission is separate from verified browser identity; existing invitation expiry, row locks, and concealed failures.

## Constraints

- Preserve existing API create/list/revoke/accept responses and credential semantics. New browser acceptance must not call the API acceptance function and silently discard a newly minted credential.
- Invitation possession admits the invited email only. It does not verify email ownership, authenticate a browser, or permit editing the invited email.
- Reuse global users, member-only invitations, tenancy, synchronous Swoosh SMTP, encrypted sessions, and fresh browser scope.
- No owner invitations, account switching without consent, membership reactivation, project/team assignment, public registration, jobs, or broad product UI.

## Open Questions

- Recommended owner surface: one small invitation panel for the selected organization's owner, with email, display name, pending invitations, send, resend, and revoke. Alternative: API-triggered delivery now, owner UI later.
- Recommended identity handoff: explicit acceptance followed by existing magic-link sign-in. Already signed-in matching users can continue; a mismatched user must sign out explicitly before accepting. Alternative: prove mailbox ownership before membership admission, requiring a new pre-membership challenge contract.
- Recommended resend: rotate the invitation secret, invalidate older links, keep the original expiry, and synchronously send. A failed send leaves the invitation pending but the attempted secret unusable; retry rotates again. This must be reviewed because resending also invalidates any manually copied prior API token.

## Ideas

- Phase 2I: owner-triggered synchronous invitation email, browser acceptance without API credential issuance, then existing magic-link sign-in.
## Raw Notes

## Refinement

### Problem

API invitations and browser sign-in work independently. Recipients still need an API client to join, and operators cannot send invitation emails through Brain Cloud.

### User / Value

Owners invite humans; recipients join and sign in through ordinary browser interactions. Existing API clients keep their contracts.

### Appetite

One Phase 2I spec covering invitation delivery, bounded owner controls, recipient confirmation, authentication handoff, audit, and verification. No broader administration UI.

### Remaining Open Questions

Review the three recommended decisions above before publishing a canonical execution spec.

### Candidate Approaches

- Recommended: narrow owner panel, synchronous delivery, credential-free browser acceptance, separate existing sign-in.
- Smaller: delivery endpoint plus recipient UI, leaving owner initiation API-only.
- Larger: invitation-specific mailbox verification before admission; defer unless the admission policy needs changing.

### Decision Snapshot

Proposed, not approved: preserve Phase 2G API behavior, add a browser-specific acceptance result without issuing an API credential, and use Phase 2H for actual authentication. Never infer email verification from an invitation because owners receive invitation secrets through the existing API.

## Challenge

### Rabbit Holes

- Full membership administration, job queues, generic notifications, email preferences, enterprise authentication, or Planning-module work.

### No-Gos

- No state-changing GET, raw secrets in query strings/logs/audits, browser API token exposure, or automatic login as the invited email.
- No SMTP call inside a database transaction holding invitation locks.
- No duplicate membership, duplicate acceptance event, or revive-on-accept behavior for inactive memberships.

### Assumptions

- Existing SMTP setup and public URL configuration suffice for invitation mail.
- Acceptance before login matches the existing API admission model; a later sign-in proves mailbox ownership.
- Initial API credentials remain available only through existing API workflows, not browser acceptance.

### Likely Overengineering

Introducing durable jobs merely for resend, or building a full organization dashboard around a small invitation panel.

### Simpler Alternative

Owner-triggered delivery through an additive API endpoint plus recipient confirmation would reduce UI scope, but owners would still need an API client.

## Promotion map

### Spec 1 — Invitation delivery and browser acceptance

Problem:

Invited humans cannot complete admission through email and a browser despite working API invitation and browser sign-in foundations.

Scope:

- Add a minimal owner-only invitation panel for the currently selected active organization; reauthorize all operations using fresh database scope. Mirror current member-only scope validation without fabricating API credentials for browser owners.
- Add owner-triggered synchronous Swoosh invitation send/resend with digest-only secrets, fixed safe public URL, sanitized operational outcomes, and explicit bounded cooldown/rolling limits. Final spec must fix exact limits and response semantics.
- Preserve existing API behavior; automatic email is not a hidden side effect of the existing API create operation. Define any additive API delivery operation explicitly before implementation.
- Use generation-aware delivery state: reserve a new secret under lock, send outside the transaction, and finalize only if still current. Revocation, acceptance, and newer sends must win over stale completion. Store no recoverable raw secret. Preserve original expiration on resend; failed or uncertain delivery requires a new explicit attempt, never an automatic retry with a discarded token.
- Browser links carry invitation secrets in fragments; clear the URL and require CSRF-protected explicit confirmation. Validate before revealing invitation details, never consume on GET, use fixed redirect destinations, and conceal invalid/expired/revoked/replayed tokens consistently.
- Browser acceptance shares locked admission logic with API acceptance but creates no API credential. Atomically create/reuse the invited user, create member membership, mark acceptance, and record truthful audit provenance with no fictitious credential or unverified signed-in actor. Preserve historical audit rows and API acceptance metadata.
- A signed-in different email cannot accept while retaining that identity; offer explicit logout and retain no raw invitation secret in a redirect or durable session. A matching signed-in user continues into the invited organization only after fresh membership validation. Signed-out acceptance leads to the existing sign-in request; no automatic verification or browser session creation.
- Preserve closed enrollment, existing profiles, inactive-membership conflict behavior, tenant isolation, existing invitation lifetime, and final-state concurrency rules.
- Update security/self-hosting/API documentation only for shipped behavior. Do not imply broader product administration or Planning exists.

Acceptance criteria:

- Owner can send, resend, and revoke within the selected organization; non-owner, agent, stale-owner, and cross-tenant attempts cannot mutate or reveal invitations.
- Successful email leads through explicit browser acceptance and verified sign-in into the correct organization. Matching and mismatched browser identities have tested, explicit behavior.
- Browser admission creates exactly one membership and acceptance audit, zero API tokens, zero automatic browser sessions, and no email verification timestamp. Existing API admission still issues its original credential and response.
- Resend invalidates previous secrets without extending expiry. Failed delivery, stale completion, retry, revocation, and simultaneous API/browser acceptance have deterministic outcomes and no secret leaks.
- Existing users retain profiles; existing inactive memberships are not reactivated; duplicate membership races roll back admission coherently.

Verification:

- Schema/domain tests for delivery generations, cooldowns, expiry, failures, audit provenance, and shared admission behavior.
- Separate-connection concurrency tests for resend/revoke/accept, stale SMTP completion, duplicate clicks, and API/browser acceptance races.
- Controller/LiveView tests for owner scope freshness, CSRF, fragment handling, scanner-safe GET, concealed failures, mismatched identities, and sign-in handoff.
- SMTP sink smoke for send, resend, failure/retry, browser admission, subsequent login, revocation/replay, restarts, and database outage/recovery. Inspect secrets across logs, redirects, database, and audit boundaries.
- Run make check, make upgrade-phase2, Docker build, make smoke-phase2, OpenAPI compatibility assertions, brain context audit, plan check, and git diff --check through the Brain session during implementation.

Dependencies: Phase 2G spec #22 and Phase 2H spec #25 are complete; PR #27 merged.

Readiness: needs refinement; owner UI scope, identity handoff, and resend semantics await user review. Set exact delivery limits, routes, statuses, audit actions, and delivery-state transitions before canonical promotion.

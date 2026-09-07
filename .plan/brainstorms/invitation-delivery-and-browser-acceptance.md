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

Make the existing invitation and sign-in foundations usable together. Keep this an invitation bridge, not an administration dashboard or new identity system. The user approved the small owner panel, separate sign-in after joining, and secret rotation on resend. Canonical promotion records those decisions; implementation remains a separate step.

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

None blocking promotion. The three proposed decisions were approved by the user. Concrete limits, routes, delivery states, and audit outcomes are specified below.

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

None blocking promotion; user approved all three recommendations.

### Candidate Approaches

- Recommended: narrow owner panel, synchronous delivery, credential-free browser acceptance, separate existing sign-in.
- Smaller: delivery endpoint plus recipient UI, leaving owner initiation API-only.
- Larger: invitation-specific mailbox verification before admission; defer unless the admission policy needs changing.

### Decision Snapshot

Approved direction: preserve Phase 2G API behavior, add a browser-specific acceptance result without issuing an API credential, and use Phase 2H for actual authentication. Never infer email verification from an invitation because owners receive invitation secrets through the existing API.

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

- Add a minimal owner-only invitation panel for the currently selected active organization: email and display-name inputs, fixed member role, seven-day expiry, pending invitation list, send/resend/revoke, and safe delivery status. Browser-created invitations carry fixed `memory.read` and `search.keyword` scopes for compatibility if accepted through the API; explain that these grant no project access and browser acceptance creates no credential. No scope editor or broad membership dashboard. Existing API-created invitations retain their original scopes and expiry when sent from the panel.
- Authorize browser operations from the tracked human session and selected active owner membership, never from a fabricated API credential or client-supplied organization/role. Reauthorize inside the mutation transaction, including concurrent owner demotion/deactivation; use consistent lock ordering with existing membership operations. Missing session redirects to `/sign-in`, missing selected membership to `/`, and authenticated non-owner or foreign invitation IDs receive concealed 404. Rehydrate on LiveView events as well as mount/reconnect.
- Deliver synchronously through existing Swoosh/SMTP and validated public URL configuration. Reserve attempts in PostgreSQL before sending: 60-second cooldown per invitation, maximum five attempts per invitation in a rolling hour, and maximum 20 attempts per organization in a rolling hour. Count failures and pending attempts; enforce limits across processes under locks. Throttled attempts neither rotate secrets nor change invitation state. New-create quota failure leaves no invitation; delivery failure after reservation leaves a pending invitation available for retry. Show owners a bounded retry time and sanitized failure, never SMTP internals. Reverse-proxy abuse limits remain an additional deployment boundary, not a new platform.
- Preserve all 45 existing OpenAPI operations and response shapes, including API creation returning its raw token and API acceptance issuing a credential. Add no `/v1` operation in this slice and no hidden email side effect to API creation. Browser routes: `GET /organization/invitations` for the panel, `POST /organization/invitations` for create-and-send, `POST /organization/invitations/:id/send` for send/resend, and `DELETE /organization/invitations/:id` for revoke. Successful or delivery-failed owner mutations use 303 back to the panel with distinct safe feedback; validation renders 422, throttling 429 with Retry-After, invalid/terminal send target 404. Revocation retains existing idempotent terminal behavior. All browser mutations require CSRF.
- Use generation-aware delivery state with `manual`, `sending`, `sent`, and `failed` outcomes. Existing/manual API invitations start `manual` and remain usable unchanged. An authorized send reserves a fresh generation and secret digest under lock, immediately invalidates all older secrets, and sets `sending`; send outside the transaction. Only current `manual` or `sent` secrets are acceptable through either transport. SMTP success atomically marks the current generation `sent`; failure marks it `failed`. Finalization may not revive an expired, accepted, revoked, or superseded invitation. Failed finalization or process crash leaves the generation unusable; after cooldown, an explicit send may replace `sending` with a new generation. No recovery of raw secrets or background retry. One current generation per invitation; bounded attempt history supports exact rolling limits.
- Resend keeps the invitation's original expiry, role, email, display name, and approved scopes. Warn owners that resending invalidates manually copied API acceptance secrets too. Sending expired invitations is rejected; creating a replacement follows existing invitation uniqueness rules. An SMTP message may arrive after revocation or with a failed finalization; its link must remain unusable, and the UI must not claim email receipt merely because SMTP accepted delivery.
- Email links use `/invitations/accept#token=...`. `GET /invitations/accept` serves only a generic landing page and makes no admission or auth mutation. Reuse the fragment-clearing pattern; keep the secret only in an in-memory/hidden form field. CSRF-protected `POST /invitations/preview` validates the secret, then shows invited email and organization plus explicit Join confirmation; `POST /invitations/accept` revalidates and atomically consumes. Valid preview returns 200. Invalid, expired, revoked, used, wrong-secret, unsent, and failed-generation results render the same 404 page. Existing active/inactive membership conflicts render 409 without overwriting or reactivating anything. Filter token parameters, set no-store and no-referrer for recipient responses, and permit no external return URL. No third-party content on token-handling pages.
- Browser acceptance shares locked admission logic with API acceptance but creates no API credential. Atomically create/reuse the invited user, create member membership, mark acceptance, and record `invitation.accept` attributed to the admitted user as the invitation actor, with `api_token_id: nil` and metadata limited to `accepted_membership_id` and `acceptance_method: browser_invitation`. This is admission provenance, not proof of authenticated identity. Preserve historical audit rows and exact API acceptance metadata. Browser owner create/revoke retain existing actions with the owner user and nil API credential; sent-generation reservation writes `invitation.delivery_requested`, while current completion writes `invitation.delivery_sent` or `invitation.delivery_failed`, with only invitation/generation IDs and a safe failure category. Never store email, raw tokens, digests, or SMTP details in audit metadata.
- A signed-in different email cannot accept while retaining that identity; offer explicit logout and retain no raw invitation secret in a redirect or durable session. A matching signed-in user continues into the invited organization only after fresh membership validation. Signed-out acceptance redirects 303 to `/sign-in` with a join-complete message; the user explicitly requests the existing magic link and then selects the organization if necessary. Do not prefill email through query parameters or store the invitation secret in the cookie. Matching signed-in acceptance selects the new active membership transactionally and redirects 303 to `/`, without reauthenticating or changing email verification. Mismatched identity renders 409 before admission; explicit existing logout and reopening the original email link is the recovery path. No automatic verification or browser session creation.
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

Readiness: ready. User approved the owner panel, separate authentication handoff, and resend rotation. Delivery limits, browser routes, public outcomes, audit provenance, and generation-state transitions are now explicit. Review the canonical spec before implementation.

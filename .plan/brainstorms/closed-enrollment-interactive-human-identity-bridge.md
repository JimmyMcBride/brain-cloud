---
created_at: "2026-09-06T12:22:26Z"
project: brain-cloud
slug: closed-enrollment-interactive-human-identity-bridge
status: active
title: Closed-enrollment interactive human identity bridge
type: brainstorm
updated_at: "2026-09-06T13:01:13Z"
---

# Brainstorm: Closed-enrollment interactive human identity bridge

Started: 2026-09-06T12:22:26Z

## Focus Question

What is the smallest secure Phase 2H bridge from Phase 2G's invitation-created human identities and API credentials to browser-authenticated Phoenix LiveView sessions, without prematurely building the Brain Cloud product UI or enterprise identity?
## Desired Outcome

A person who already exists in Brain Cloud can request a passwordless sign-in link, establish a revocable browser session, select an active organization membership, and enter a minimal authenticated LiveView shell. The flow preserves closed enrollment and the existing API identity model while creating a secure foundation for later human-facing product UI.
## Vision

## Supporting Material

## Constraints

- Reuse the existing global users and organization memberships; create no parallel identity schema.
- Keep registration closed: only bootstrap-created, owner-created, or invitation-accepted users may sign in.
- Follow Phoenix 1.8 LiveView authentication and scope conventions where they fit, but adapt rather than blindly generate over the existing Accounts context.
- Keep browser login challenges and sessions separate from bc1 API credentials and their scopes.
- Rehydrate user, selected organization membership, role, and active state on every HTTP request and LiveView mount/reconnect.
- Preserve every existing /v1 API response and authentication behavior.
- Support hosted and self-hosted delivery/configuration with explicit production failure behavior.
- Make public login requests non-enumerating and throttled; keep raw login/session secrets out of logs and durable audit metadata.
- Build only a minimal authenticated shell and organization chooser needed to prove the bridge.
- Defer passwords, passkeys, OAuth/OIDC, SSO, SCIM, MFA, owner invitations, and the product dashboard.

## Open Questions

- Should Phase 2H deliver only sign-in links, or also make Phase 2G invitation delivery a first-class email flow?
- Should a browser session authenticate the global user and carry a selected active membership, or be permanently bound to one membership/organization?
- Should email delivery be synchronous for this first slice or introduce the first durable OTP-managed background job because delivery is now real work?
- What exact login-link, session, inactivity, and recent-authentication lifetimes should become contract?
- Where should durable global authentication events live when existing audit events are organization-bound?
- What minimum distributed throttling and trusted-client-IP behavior is required before exposing the public login request endpoint?
## Ideas

- Adopt Phoenix 1.8's passwordless email magic-link model for existing users only, adapting it to Brain Cloud's existing global users, organization memberships, API credentials, and audit boundaries instead of generating a second account model.
- Keep browser authentication artifacts separate from bc1 API credentials: one-time login challenges prove email control, tracked browser sessions maintain continuity, and membership state is reloaded for every HTTP/LiveView authorization decision.
- Treat organization selection, mail delivery, anti-enumeration, throttling, session revocation, and invitation handoff as required bridge decisions—not invisible implementation details.
- Defer passwords, passkeys/WebAuthn, OAuth/OIDC, SSO, SCIM, MFA, owner invitations, account recovery beyond magic-link re-entry, and the real product dashboard.
## Raw Notes

Research basis:
- Local Phoenix 1.8.9 `phx.gen.auth` templates: existing-user email magic links, tracked session tokens, 15-minute magic-link validity, 14-day sessions, seven-day reissue, LiveView `on_mount`, and recent-authentication support.
- Phoenix authentication guide: https://hexdocs.pm/phoenix/1.8.9/mix_phx_gen_auth.html
- Phoenix scopes guide: https://hexdocs.pm/phoenix/1.8.9/scopes.html
- NIST SP 800-63B session/authenticator guidance: https://pages.nist.gov/800-63-4/sp800-63b.html
- W3C WebAuthn Level 3, retained as the leading later passkey option: https://www.w3.org/TR/webauthn-3/

Bridge map:
- Phase 2G owns identity admission: owner approval, invitation acceptance, membership creation, and initial API credential.
- Phase 2H should own existing-human browser authentication: login challenge, email delivery, tracked session, selected membership, current scope, logout/revocation, and minimal LiveView proof.
- A later invitation-experience slice may add automatic invitation delivery and interactive acceptance without changing Phase 2G's API contract.
- A later product-UI slice can build project, memory, team, agent, and administration screens on the proven browser scope.

## Promotion map

### Spec 1 — Closed-enrollment interactive human identity bridge

Problem:

Phase 2G admits human identities through bootstrap, owner administration, or invitation acceptance and gives them API credentials, but Brain Cloud has no browser authenticator, revocable browser session, organization-selection model, or authenticated LiveView boundary. Product UI built now would either invent a second identity system or misuse long-lived `bc1` API credentials in browsers.

Scope:

- Implement one bounded Phase 2H slice in the existing Phoenix umbrella. Adapt Phoenix 1.8 `phx.gen.auth` patterns to the existing global `users`, organization memberships, Accounts context, and LiveView shell; do not generate a parallel user/context stack.
- Keep enrollment closed. A normalized email is eligible only when it belongs to an existing user with at least one active organization membership. Login never creates or mutates a user, membership, API credential, invitation, team, grant, or project.
- Add a dedicated human browser-auth persistence boundary for one-time email login challenges and tracked browser sessions. Use binary UUIDs and store only SHA-256 digests of high-entropy raw tokens. Login challenges and browser sessions are separate from `bc1` API tokens and carry no API scopes.
- Allow at most one usable login challenge per user. Creating a new challenge invalidates the previous one. Challenges expire after 15 minutes and are consumed exactly once under a row lock; invalid, expired, consumed, superseded, malformed, and wrong-secret attempts have the same public result.
- Add an existing-user-only sign-in request page and endpoint. Normalize email exactly as the current User schema does. Always render the same acknowledgement for unknown, ineligible, throttled, delivery-failed, and successful requests. Never disclose whether a user or active membership exists.
- Throttle delivery per eligible user with a 60-second resend cooldown and at most five sent links in a rolling hour. Unknown emails still perform bounded dummy token work and receive the same response. Document a trusted reverse-proxy/IP rate limit as an additional production boundary; do not introduce a generic distributed rate-limit platform in this slice.
- Deliver sign-in links synchronously through Swoosh. Development and tests use the local/test adapter; production uses explicitly configured SMTP relay, port, username/password when required, TLS mode, sender address, and public application URL. A delivery failure invalidates the new challenge, emits a sanitized operational error, and still returns the generic acknowledgement. Retrying the form is the retry mechanism; add no Oban/job system.
- Keep raw login tokens out of application/request logs, database fields, audit/security metadata, and redirect destinations after consumption. The confirmation flow must avoid open redirects, clear the token-bearing URL before authenticated navigation, and require a CSRF-protected POST/final user action before consuming the challenge and creating a session.
- Successful confirmation marks the user's email verified when not already verified, consumes the challenge, rotates away any pre-authentication cookie state, and creates one tracked 14-day browser session. Store only its token digest server-side. Reissue the session atomically after seven days and revoke the replaced token. Track the authentication timestamp for a 20-minute recent-authentication boundary even though no Phase 2H page requires elevated confirmation yet.
- Configure the production browser cookie as encrypted and signed, `Secure`, `HttpOnly`, `SameSite=Lax`, with the same 14-day maximum age as the server session. The cookie contains only an opaque session token; no email, role, organization, membership, or permission claims.
- Add a Phoenix web-auth module and a `current_scope`-style struct that rehydrates the global user, all active memberships, selected membership, organization, and current role from PostgreSQL on every HTTP request and LiveView mount/reconnect. Never authorize from stale cookie or socket claims.
- A new session automatically selects its only active membership. With multiple active memberships it enters an organization chooser. Selection accepts only an active membership owned by the authenticated user and stores the selected membership on the server-side session. Switching organizations reuses the same session and the same validation rules.
- If the selected membership becomes inactive, clear the selection and return the user to the chooser when another active membership exists. If none remain, revoke the browser session and require sign-in again. Membership role changes are visible on the next request/reconnect. One organization's deactivation must not destroy access to another active organization.
- Add logout for the current browser session only. Logout revokes the server-side session, clears the browser cookie, and is idempotent. Expired, revoked, unknown, or malformed session tokens behave as signed out.
- Add a narrow global human-auth security-event table rather than weakening organization-bound audit constraints. Record successful email verification/sign-in, session reissue, organization selection, and logout with authentic user/session provenance and safe metadata. Do not persist unknown-email attempts, raw tokens/digests, email addresses, request bodies, IP addresses, or user-agent strings in these events. Sanitized structured logs cover delivery and invalid-attempt operations.
- Keep `/` public but render honest states: the existing bootstrap page plus a sign-in path when signed out; a minimal authenticated identity/selected-organization shell and logout when signed in; the organization chooser when selection is required. Add no project, memory, team, agent, invitation, token, or administration UI.
- Preserve all successful and failure behavior for public health/readiness/system discovery, public invitation acceptance, and every bearer-authenticated `/v1` operation. Browser sessions do not authenticate API routes, and API credentials do not authenticate browser routes.
- Update runtime configuration, release/Docker/Compose examples, self-hosting guidance, security documentation, roadmap, LiveView copy, Plan, AGENTS, and durable Brain context. Document HTTPS/public-URL, SMTP, cookie, throttling, and delivery-failure requirements without implying automatic invitation delivery or a complete product UI.
- Add no self-registration, automatic invitation delivery, interactive invitation acceptance, owner invitations, email-change flow, passwords, password reset, passkeys/WebAuthn, OAuth/OIDC, social login, SSO, SCIM, MFA, recovery codes, remember-me variants, session-management UI, administrator session revocation, product CRUD UI, custom roles, generic policy engine, audit-query API, notification platform, background worker, or Phase 3 work.

Acceptance criteria:

- Existing bootstrap-created, directly created, and invitation-accepted users with active memberships can request and complete sign-in; unknown users and users with no active memberships receive the exact same request acknowledgement and no session.
- Login requests enforce exact email normalization, one active challenge per user, 15-minute expiry, single use, supersession, 60-second resend cooldown, and five successful deliveries per rolling hour without revealing account state.
- SMTP success produces one link; delivery failure leaves no usable new challenge, exposes no account state, and logs no raw token or email. Development/test delivery is inspectable without external email infrastructure.
- Raw login and session tokens appear only where required for the outgoing link or browser cookie. Database inspection, application logs, errors, security events, and post-consumption URLs expose neither raw values nor token digests.
- Confirmation requires final POST intent and CSRF protection, rejects open redirects, consumes exactly one valid challenge, verifies the email, prevents session fixation, and creates exactly one tracked session. Concurrent confirmation attempts yield one success with no duplicate session/event rows.
- Browser sessions expire absolutely after 14 days, rotate atomically after seven days, preserve a 20-minute recent-authentication timestamp, and are rejected after logout or expiry. Cookie flags and server expiry agree in production.
- The authenticated scope never trusts stored authorization claims. It observes membership deactivation, reactivation, role changes, cross-organization isolation, and session revocation on the next request and LiveView reconnect.
- Single-membership users are selected automatically. Multi-membership users can select and switch only among their own active memberships. Deactivating the selected membership falls back to the chooser or signs out when no active membership remains.
- Global auth security events contain exact user/session provenance and only safe action metadata; organization audit constraints and all existing audit rows remain unchanged.
- Signed-out, chooser, and signed-in root LiveView states are exact and honest. No later dashboard or administration control is present or implied.
- Existing `bc1` human/agent bearer authentication, invitation acceptance, memberships, tokens, teams, agents, project access, provenance, memories, search, health, readiness, migrations, upgrade paths, and OpenAPI contracts remain wire compatible.
- A production release fails clearly on invalid mailer/public-URL configuration, starts with valid configuration, and never enables an insecure production cookie configuration.

Verification:

- Migration/schema tests cover token digest lengths and uniqueness, challenge/session contexts and expiry, user/session relations, selected-membership ownership/tenant constraints, email verification, security-event provenance, empty-table rollout, and forward/rollback behavior.
- Domain tests cover eligibility, normalization, supersession, expiry, wrong/replayed tokens, delivery success/failure rollback, throttle boundaries, session creation/reissue/revocation, email verification, selection/switching, deactivation fallback, role freshness, and safe event metadata.
- Separate-connection concurrency tests prove one success for simultaneous confirmation and atomic session reissue without duplicate sessions or events.
- Controller/LiveView tests assert exact non-enumerating acknowledgements, CSRF and final-intent confirmation, no open redirect, cookie attributes, signed-out/chooser/signed-in states, logout, reconnect freshness, and strict separation from API bearer authentication.
- Capture development/test mail and scan database rows, logs, rendered HTML, redirects, and security events to prove raw-token/digest and email non-disclosure outside their allowed boundary.
- Run `mix format --check-formatted`, `mix compile --warnings-as-errors`, test database creation/migrations, `mix test`, and `mix assets.deploy` through the Brain session.
- Extend `make upgrade-phase2` to prove Phase 1–2G data, API credentials, invitations, grants, provenance, and APIs remain intact with empty browser-auth tables, then complete one post-upgrade sign-in.
- Build the non-root production image and extend `make smoke-phase2` with a test SMTP sink to verify link delivery, confirmation, single/multiple organization selection, authenticated root, logout/replay denial, restart persistence, membership deactivation/role freshness, and PostgreSQL outage/recovery.
- Run `brain context audit`, `plan check`, OpenAPI parsing/operation assertions confirming no accidental API surface change, shell syntax checks, `git diff --check`, and `brain session finish`.

Dependencies: Phase 2G human invitation and acceptance foundation is merged through PR #24; canonical spec #22 is closed.

Readiness: ready.
## Refinement

### Problem

Phase 2G can create a real human identity, membership, and API credential, but a person still cannot prove control of that identity in a browser, establish a revocable Phoenix session, or safely enter a LiveView workspace. The missing bridge includes closed-enrollment sign-in, delivery, session security, organization selection, and deactivation behavior; hiding any of these behind the future UI would make that UI depend on an undefined identity model.

### User / Value

Existing owners and invited members gain a browser sign-in path tied to the same global user and organization memberships already used by the API. They can enter a minimal authenticated shell, choose an active organization, and end or lose access to sessions predictably without receiving a second identity or turning API bearer tokens into browser credentials.

### Appetite

One focused Phase 2H canonical spec and implementation PR: authentication challenge and delivery, tracked browser-session lifecycle, organization selection/current scope, invitation-to-login handoff, minimal LiveView proof, security/audit boundaries, and production configuration. Stop before product CRUD UI, account settings, enterprise federation, or alternate authenticators.

### Remaining Open Questions

- Should Phase 2H deliver only sign-in links, or also make Phase 2G invitation delivery a first-class email flow?
- Should a browser session authenticate the global user and carry a selected active membership, or be permanently bound to one membership/organization?
- Should email delivery be synchronous for this first slice or introduce the first durable OTP-managed background job because delivery is now real work?
- What exact login-link, session, inactivity, and recent-authentication lifetimes should become contract?
- Where should durable global authentication events live when existing audit events are organization-bound?
- What minimum distributed throttling and trusted-client-IP behavior is required before exposing the public login request endpoint?

### Candidate Approaches

- Recommended baseline: Phoenix-native, passwordless email magic links for existing users only, tracked server-side sessions, and a global user scope with an explicitly selected active organization membership.
- Narrower staging: implement sign-in-link delivery and session lifecycle first; add automatic invitation email delivery only after the interactive acceptance contract is separately shaped.
- Passkey-first alternative: enroll WebAuthn credentials from invitation/bootstrap proof, avoiding mail for recurring login but adding relying-party, ceremony, recovery, and browser compatibility work Phoenix does not generate.
- Password alternative: add local passwords and recovery, gaining offline/self-hosted familiarity but expanding secret storage, reset, breach, and credential-stuffing defenses.
- OIDC-first alternative: delegate authentication, attractive for hosted/enterprise deployments but unsuitable as the only self-hosted default and too coupled to provider configuration for this bridge.

### Decision Snapshot

Carry one Phase 2H spec: closed-enrollment, passwordless magic-link sign-in for existing users, adapted from Phoenix 1.8 rather than generated as a parallel auth stack. Use separate one-time login tokens and tracked global-user browser sessions; keep the selected membership in session state and rehydrate its organization, role, and active status on every request and LiveView reconnect. Start with Swoosh sign-in-link delivery and Phoenix's 15-minute link, 14-day session, seven-day reissue, and recent-authentication conventions; require encrypted Secure/HttpOnly/SameSite cookies in production, generic non-enumerating request responses, bounded application throttling, session revocation, and explicit security-event provenance. Keep Phase 2G invitation delivery/API contracts unchanged; after acceptance, the existing user can request a sign-in link. Prove the bridge with login, organization choice, authenticated root state, and logout only. Defer product UI and every alternate or enterprise authenticator.

## Challenge

### Rabbit Holes

- Turning the authenticated shell into the Phase 13 dashboard or adding project/memory administration UI.
- Running phx.gen.auth blindly and duplicating users, contexts, routes, migrations, or authorization scopes.
- Expanding one passwordless path into passwords, passkeys, social login, OAuth/OIDC, SSO, SCIM, MFA, recovery codes, or account settings.
- Making invitation email delivery, resend, templates, notification preferences, or owner invitations part of this slice.
- Introducing a generic job platform solely to deliver user-requested sign-in links.
- Conflating global human authentication with one organization's authorization or with bc1 API scopes.
- Building a generic policy/audit/event framework to represent the few new auth events.

### No-Gos

- No self-registration or implicit user/membership creation from the login form.
- No bc1 API token pasted into, stored by, or silently exchanged through browser login.
- No plaintext magic-link token or browser-session token in durable logs, audits, email metadata, or database fields where a digest suffices.
- No response, timing, or redirect distinction that intentionally reveals whether an email, user, or active membership exists.
- No session-selected membership belonging to another user, another organization context, or an inactive membership.
- No authorization based only on cookie claims captured at login; reconnects and requests must observe deactivation and role changes.
- No open redirect through return-to parameters and no state-changing GET that authenticates without final user intent.
- No production session cookie lacking encryption, Secure, HttpOnly, SameSite, expiry, rotation, and logout revocation.
- No claim that invitation email delivery, account recovery, MFA, or a usable product dashboard exists.

### Assumptions

- Control of the normalized email inbox is sufficient for the first interactive authenticator; Phase 2G acceptance alone remains explicitly not email verification.
- Every eligible human already exists through bootstrap, direct owner creation, or invitation acceptance and has at least one active membership.
- Hosted operators can provide an email adapter and self-hosters can configure SMTP; development and tests use a local/in-memory adapter.
- Production browser authentication runs only over HTTPS with a correct PHX_HOST/public URL.
- A user-level session plus one selected active membership is the least surprising basis for humans who belong to multiple organizations.
- Requesting another magic link is the only recovery path in this slice.
- Existing API credentials, scopes, and /v1 authentication remain independent and wire-compatible.
- A tracked session table is operational identity state, while security events need explicit provenance without weakening organization audit constraints.

### Likely Overengineering

The likely failure mode is treating “identity” as a mandate for a complete IAM platform. The bridge needs one existing-user magic-link authenticator, one tracked session family, one selected-membership scope, one mail adapter boundary, narrow throttling, and a tiny signed-in shell. Provider abstraction, interchangeable authenticators, generalized workflows, account-management screens, and enterprise lifecycle belong after this path is proven.

### Simpler Alternative

An existing human enters an email and always sees the same acknowledgement. If eligible and within throttle limits, Brain Cloud sends one 15-minute, single-use sign-in link. Confirmation creates one tracked 14-day browser session, automatically selects the only active membership or asks the user to choose among multiple, and redirects to the existing root LiveView rendered as a minimal authenticated shell. Every request and LiveView reconnect reloads the user and selected membership. Logout deletes the session; expiry, user removal from all active memberships, or selected-membership deactivation blocks protected UI. Nothing creates users, sends invitations, changes API tokens, or exposes product administration UI.

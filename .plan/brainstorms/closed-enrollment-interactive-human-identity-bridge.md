---
created_at: "2026-09-06T12:22:26Z"
project: brain-cloud
slug: closed-enrollment-interactive-human-identity-bridge
status: active
title: Closed-enrollment interactive human identity bridge
type: brainstorm
updated_at: "2026-09-06T12:26:53Z"
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

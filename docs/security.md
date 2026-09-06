---
updated: "2026-09-06T13:58:09Z"
---
# Security direction

Brain Cloud security is designed around tenant isolation, least privilege, provenance, and explicit durable writes.

Required controls include encryption in transit and at rest, secure token storage and revocation, input validation, rate limiting, audit logs, secure deletion, backup protection, secret detection, redaction, prompt-injection resistance, sensitive retrieval controls, and bounded agent credentials.

Permission checks occur before search, retrieval, reranking, context compilation, or model invocation. Display-time filtering is insufficient because unauthorized material must never enter generated context. Separate capabilities cover read, search, compile, propose memory, approve memory, direct edit, and administration.

## Phase 2A API identity and tenancy

Protected product routes authenticate persisted, versioned `bc1_<public_id>_<secret>` credentials. Brain Cloud stores only a public lookup ID and SHA-256 digest, compares digests in constant time, rejects expired/revoked credentials and inactive memberships, and assigns one immutable user/organization/membership/role/token/scope context to each request. Operational endpoints, the bootstrap LiveView, and system discovery remain public.

Every token belongs permanently to exactly one principal: a human organization membership or an organization-owned agent. Required scopes are checked before resource lookup; valid insufficient credentials return `403`, while missing and cross-tenant resources share non-enumerating `404` responses. Project, memory, and search queries include organization predicates before protected content loads. Owner role plus `tokens.manage` controls human token creation, metadata listing, and revocation, and issued scopes cannot exceed the caller's scopes.

Bootstrap, token create/revoke, project create, and memory create commit immutable audit events in the same transaction as their durable action. The bootstrap secret is displayed once; explicit recovery revokes it and displays one replacement. Raw tokens and digests are excluded from normal logs, errors, audit metadata, inspection, list, and revoke output.

API bearer credentials remain organization-bound and independent from the Phase 2H browser identity boundary. Passwords, passkeys, OAuth/OIDC, SSO, SCIM, MFA, interactive invitation UI, automatic invitation delivery, distributed rate limiting, and audit-query APIs remain unimplemented.

## Phase 2B membership administration

Human membership lifecycle operations require both an active owner role and `members.manage`; one-time target-member credential issuance additionally requires `tokens.manage`. Authorization completes before resource lookup. Missing, malformed, nonexistent, and cross-tenant membership IDs share `404 membership_not_found`, preventing membership enumeration.

Requested target-token scopes must be a subset of the caller's scopes. A member target cannot receive `members.manage`, `projects.manage_access`, `teams.manage`, `agents.manage`, or `tokens.manage`. Raw credentials are returned once, stored only as digests, and excluded from logs, validation details, audit metadata, and membership responses.

PostgreSQL row locks serialize changes that could remove an active owner. The final active owner cannot be demoted or deactivated, including concurrent attempts against the last two owners. Deactivation and owner-to-member demotion revoke every active credential bound to the target membership in the same transaction. Reactivation never clears revocation, so access resumes only after an owner explicitly issues a fresh credential. Membership create, role change, deactivate, and reactivate actions commit safe immutable audit events transactionally.

## Phase 2C project access control

Project access combines fixed token scopes with membership-level authorization. Owners have implicit full access. Active members need a direct `reader` or `editor` grant: readers may retrieve memories and search, while editors may also create memories. Authorization occurs before any memory, revision, or search query so denied projects return the same non-enumerating `404 project_not_found` response as missing, malformed, inaccessible, and cross-tenant projects.

Grant administration requires an active owner plus `projects.manage_access`. PostgreSQL composite foreign keys enforce that each grant, project, and membership share one organization. Inactive memberships cannot receive grants, but existing grants survive suspension/reactivation and role changes; they are dormant for inactive memberships and owners. Member-created projects atomically grant the creator editor access. Existing member/project pairs are backfilled as editors during upgrade, including inactive memberships, while owners remain implicit.

Grant create, access change, and revoke actions commit immutable audit events with project, membership, current access, and previous access where applicable. Idempotent PUTs and absent DELETEs emit no event.

## Phase 2D team access

Team lifecycle and membership administration requires an active owner plus `teams.manage`; team project-grant administration remains separate under `projects.manage_access`. PostgreSQL composite foreign keys enforce organization alignment for teams, membership links, projects, and grants. Case-insensitive team names are unique within an organization.

Teams are soft-deactivated. Their membership links and project grants remain inspectable and auditable but contribute no authorization until explicit reactivation. Active members receive the strongest reader/editor permission from direct grants and any active linked teams, with no deny rules. Team-row locks serialize lifecycle, membership, and grant mutations; transactional audit events are emitted only for real state changes.

## Phase 2E–2F agent identity, credentials, and provenance

Agents are organization-owned principals, not synthetic users or memberships. Each credential belongs to exactly one human membership or agent, uses the same one-time-secret/digest format, and authenticates into an explicit principal type and ID. Agent credentials are restricted to non-empty subsets of `memory.write`, `memory.read`, and `search.keyword`; they cannot bootstrap, create projects, manage access, manage agents, or exercise human administration.

Agent lifecycle and nested credential operations require an active owner plus `agents.manage`. Direct agent grants require owner plus `projects.manage_access`, are reader or editor, and use project-first tenant concealment. Agent memory creation requires both `memory.write` and a direct editor grant; retrieval and search require their own scopes plus reader or editor access. Revision and audit rows store exactly one human or agent actor, preserve existing human actor IDs, and enforce agent tenant alignment in PostgreSQL. Deactivation locks the agent, revokes all active credentials transactionally, emits one aggregate audit event, and retains dormant grants. Reactivation never restores credentials. PostgreSQL checks enforce exactly one token principal, exactly one revision and audit actor, and tenant-aligned agent grants and provenance.

## Phase 2G human invitation acceptance

Human member invitations use distinct one-time `bci1_<public_id>_<secret>` acceptance tokens. Brain Cloud stores only the public lookup ID and SHA-256 digest, filters token and secret parameters from logs, and uses constant-time digest comparison after lookup. Owners need `members.manage` to list or revoke invitations and both `members.manage` and `tokens.manage` to create one; authorization precedes validation and tenant-concealed lookup.

Each invitation is tenant-bound to its organization and inviter membership, expires within seven days, grants only the fixed `member` role, and cannot carry member-forbidden management scopes. PostgreSQL composite foreign keys, a partial unresolved-email uniqueness constraint, row locks, and email-scoped transaction advisory locks serialize creation, revocation, acceptance, and direct-membership races. Public acceptance conceals malformed, unknown, wrong, expired, revoked, accepted, and replayed tokens behind the same `404 invitation_not_found` response.

Valid acceptance atomically creates or reuses the globally normalized user without overwriting an existing profile, creates one active membership, issues one non-expiring initial `bc1` credential with pre-approved scopes, marks the invitation accepted, and writes one authentic acceptance audit. Raw secrets, digests, email, and display name are excluded from audit metadata and safe responses. Automatic invitation delivery, interactive invitation acceptance, owner invitations, and invitation resend/recovery remain unimplemented.

## Phase 2H browser identity

Browser sign-in is closed enrollment: exact normalized email must match an existing user with an active membership, but every request receives the same acknowledgement. Eligible-user delivery is limited to one sent link per 60 seconds and five per rolling hour. Deployments must add a trusted reverse-proxy IP limiter because the application intentionally adds no generic distributed limiter in this slice.

Login challenges and browser sessions use separate high-entropy `bcl1` and `bcs1` secrets. PostgreSQL stores only SHA-256 digests. Challenges expire after 15 minutes, supersede one another, and consume once under a row lock. Sign-in links carry the raw token in a URL fragment so it is absent from HTTP request logs; browser JavaScript clears the fragment, places the token in a hidden field, and requires a CSRF-protected final POST. No return URL is accepted.

Successful confirmation verifies the existing email, rotates pre-authentication cookie state, and creates one server-tracked session with an absolute 14-day expiry and seven-day atomic token reissue. Production cookies are encrypted and signed, `Secure`, `HttpOnly`, `SameSite=Lax`, and contain only the opaque session token. A 20-minute authentication timestamp is retained for future elevated actions.

Every browser HTTP request and LiveView mount/reconnect reloads the user, active memberships, selected membership, organization, and role from PostgreSQL. Selection accepts only an active membership owned by the user. Inactive selection falls back to the chooser; losing all active memberships revokes the session. Browser sessions never authenticate `/v1`, and `bc1` API credentials never authenticate the browser.

Successful verification/sign-in, session reissue, organization selection, and logout write global human-auth events with user/session provenance. These events exclude email, IP address, user agent, request bodies, raw secrets, and digests. Delivery failures invalidate the challenge and emit only a sanitized operational log. SMTP is synchronous; retries are explicit form submissions and no worker or queue exists.

Future encryption modes are server-readable, end-to-end encrypted, and local-only. Server-readable projects can use hosted search and Hive Mind. End-to-end encrypted projects may require trusted client-side or user-controlled retrieval and will explicitly disclose lost server features. Searchable end-to-end encryption is not an initial requirement.

## Module security

Modules are executable applications, not harmless configuration. Brain Core must mediate their capabilities and data access.

The module trust model will require:

- explicit permission requests and installation-time approval;
- organization allowlists and publisher identity;
- version pinning, signed releases, checksums, revocation, and upgrade review;
- audit logs for install, enablement, configuration, capability use, and upgrades;
- scoped secret access plus declared network and filesystem access;
- safe failure behavior and isolation where practical;
- separate Planning read, write, and approve permissions from context and memory permissions.

Supervised official OTP applications run as trusted in-process code during the first stage but still follow formal behaviours and declared contracts. Community modules later use external processes for stronger isolation and crash containment. Brain does not claim complete sandboxing. A module must not bypass tenant isolation, project permissions, content visibility, provenance, or Hive Mind query scope.

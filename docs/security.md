---
updated: "2026-07-29T07:04:36Z"
---
# Security direction

Brain Cloud security is designed around tenant isolation, least privilege, provenance, and explicit durable writes.

Required controls include encryption in transit and at rest, secure token storage and revocation, input validation, rate limiting, audit logs, secure deletion, backup protection, secret detection, redaction, prompt-injection resistance, sensitive retrieval controls, and bounded agent credentials.

Permission checks occur before search, retrieval, reranking, context compilation, or model invocation. Display-time filtering is insufficient because unauthorized material must never enter generated context. Separate capabilities cover read, search, compile, propose memory, approve memory, direct edit, and administration.

## Phase 2A API identity and tenancy

Protected product routes authenticate persisted, versioned `bc1_<public_id>_<secret>` credentials. Brain Cloud stores only a public lookup ID and SHA-256 digest, compares digests in constant time, rejects expired/revoked credentials and inactive memberships, and assigns one immutable user/organization/membership/role/token/scope context to each request. Operational endpoints, the bootstrap LiveView, and system discovery remain public.

Every token belongs permanently to one organization membership. Required scopes are checked before resource lookup; valid insufficient credentials return `403`, while missing and cross-tenant resources share non-enumerating `404` responses. Project, memory, and search queries include organization predicates before protected content loads. Owner role plus `tokens.manage` controls token creation, metadata listing, and revocation, and issued scopes cannot exceed the caller's scopes.

Bootstrap, token create/revoke, project create, and memory create commit immutable audit events in the same transaction as their durable action. The bootstrap secret is displayed once; explicit recovery revokes it and displays one replacement. Raw tokens and digests are excluded from normal logs, errors, audit metadata, inspection, list, and revoke output.

This slice is production-capable API access control, not a complete identity product. Passwords, browser sessions, email verification, OAuth/OIDC, SSO, SCIM, invitations, service accounts, agent credentials, rate limiting, and audit-query APIs remain unimplemented.

## Phase 2B membership administration

Human membership lifecycle operations require both an active owner role and `members.manage`; one-time target-member credential issuance additionally requires `tokens.manage`. Authorization completes before resource lookup. Missing, malformed, nonexistent, and cross-tenant membership IDs share `404 membership_not_found`, preventing membership enumeration.

Requested target-token scopes must be a subset of the caller's scopes. A member target cannot receive `members.manage`, `projects.manage_access`, or `tokens.manage`. Raw credentials are returned once, stored only as digests, and excluded from logs, validation details, audit metadata, and membership responses.

PostgreSQL row locks serialize changes that could remove an active owner. The final active owner cannot be demoted or deactivated, including concurrent attempts against the last two owners. Deactivation and owner-to-member demotion revoke every active credential bound to the target membership in the same transaction. Reactivation never clears revocation, so access resumes only after an owner explicitly issues a fresh credential. Membership create, role change, deactivate, and reactivate actions commit safe immutable audit events transactionally.

## Phase 2C project access control

Project access combines fixed token scopes with membership-level authorization. Owners have implicit full access. Active members need a direct `reader` or `editor` grant: readers may retrieve memories and search, while editors may also create memories. Authorization occurs before any memory, revision, or search query so denied projects return the same non-enumerating `404 project_not_found` response as missing, malformed, inaccessible, and cross-tenant projects.

Grant administration requires an active owner plus `projects.manage_access`. PostgreSQL composite foreign keys enforce that each grant, project, and membership share one organization. Inactive memberships cannot receive grants, but existing grants survive suspension/reactivation and role changes; they are dormant for inactive memberships and owners. Member-created projects atomically grant the creator editor access. Existing member/project pairs are backfilled as editors during upgrade, including inactive memberships, while owners remain implicit.

Grant create, access change, and revoke actions commit immutable audit events with project, membership, current access, and previous access where applicable. Idempotent PUTs and absent DELETEs emit no event.

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

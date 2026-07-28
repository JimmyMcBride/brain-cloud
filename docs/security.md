# Security direction

Brain Cloud security is designed around tenant isolation, least privilege, provenance, and explicit durable writes.

Required controls include encryption in transit and at rest, secure token storage and revocation, input validation, rate limiting, audit logs, secure deletion, backup protection, secret detection, redaction, prompt-injection resistance, sensitive retrieval controls, and bounded agent credentials.

Permission checks occur before search, retrieval, reranking, context compilation, or model invocation. Display-time filtering is insufficient because unauthorized material must never enter generated context. Separate capabilities cover read, search, compile, propose memory, approve memory, direct edit, and administration.

## Phase 1 development authentication

Phase 1 product routes use one fixed bearer token from `DEV_API_TOKEN` and one actor UUID from `DEV_ACTOR_ID`. Phoenix compares the token in constant time and records the actor UUID on project creation and immutable memory revisions. Operational endpoints and system discovery remain public.

This mechanism establishes a narrow authentication and provenance seam only. It has no users, organizations, tenant isolation, expiry, rotation, revocation, scoped permissions, or audit log, and must not be treated as production access control. Production identity and multi-tenancy begin in Phase 2.

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

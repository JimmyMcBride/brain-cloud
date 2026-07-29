---
updated: "2026-07-28T21:34:35Z"
---
# Self-hosting direction

Self-hosting is a first-class Brain Cloud deployment, using the same API and client behavior as the official hosted service. Clients select any compatible server through a configurable base URL and discover protocol/capability support.

Phase 2B supplies a non-root Phoenix release image and Compose stack containing the server and PostgreSQL. The release runs Ecto migrations before startup, readiness verifies PostgreSQL with `SELECT 1`, and the product schema stores identities, owner-managed organization memberships, scoped token digests, immutable audit events, organization-owned projects, memories, immutable revisions, and the PostgreSQL keyword-search index.

After first startup, run `/app/bin/bootstrap_owner` inside the API container with `OWNER_EMAIL`, `OWNER_DISPLAY_NAME`, `ORGANIZATION_NAME`, and `ORGANIZATION_SLUG`. The idempotent command prints the initial full-scope `bc1_...` token once. Store that output in a secret manager; neither Brain Cloud nor a repeated bootstrap can recover it. `ROTATE_TOKEN=true` explicitly revokes the active bootstrap token and prints one replacement. `ADOPT_PHASE_ONE=true` explicitly attaches the new owner to the deterministic `phase-1-import` organization created for migrated data; omit organization name and slug in that mode.

The release command emits safe JSON to standard output. Initial and recovery invocations contain the one-time raw token; protect terminal capture and automation logs accordingly. Normal API list/revoke responses, audit metadata, application logs, and database rows never contain raw token material or token digests. Product credentials are organization-bound and cannot select another tenant through headers or request bodies.

After bootstrap, owners administer human access through `/v1/organization/memberships`. Membership lifecycle calls require `members.manage`; issuing a one-time credential for another membership also requires `tokens.manage`. Transfer the returned secret out of band and protect that response like bootstrap output. Deactivating a membership or demoting an owner revokes all credentials for that membership immediately. Reactivation requires issuing a fresh credential, and the server prevents removal of the final active owner.

Production self-hosting still needs versioned image publication, TLS termination, backup and restore, upgrade runbooks, secret-manager integration, rate limiting, observability, and broader operations hardening. Dependencies will be added when implemented features need them; Redis, object storage, queues, and vector databases are not assumed.

Self-hosters will control which official and community modules are allowed and enabled. Production module operations eventually require version pinning, permission approval, publisher/integrity verification, configuration and migration tooling, worker/process lifecycle, diagnostics, and backup/export coverage for module-owned data. External community module execution is deferred until supervised official OTP applications validate the contracts.

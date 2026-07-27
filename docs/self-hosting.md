# Self-hosting direction

Self-hosting is a first-class Brain Cloud deployment, using the same API and client behavior as the official hosted service. Clients select any compatible server through a configurable base URL and discover protocol/capability support.

Phase 0 supplies a non-root Phoenix release image and Compose stack containing the server and PostgreSQL. The release runs Ecto migrations before startup, and readiness verifies PostgreSQL with `SELECT 1`. No product schema or administrator setup exists yet. These files are development scaffolding, not complete production operational guidance.

Production self-hosting will add versioned images, migrations, administrator bootstrap, storage/search/worker configuration, health checks, backup and restore, upgrades, observability, and operational runbooks. Dependencies will be added when implemented features need them; Redis, object storage, queues, and vector databases are not assumed.

Self-hosters will control which official and community modules are allowed and enabled. Production module operations eventually require version pinning, permission approval, publisher/integrity verification, configuration and migration tooling, worker/process lifecycle, diagnostics, and backup/export coverage for module-owned data. External community module execution is deferred until supervised official OTP applications validate the contracts.

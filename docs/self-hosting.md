# Self-hosting direction

Self-hosting is a first-class Brain Cloud deployment, using the same API and client behavior as the official hosted service. Clients select any compatible server through a configurable base URL and discover protocol/capability support.

Phase 1 supplies a non-root Phoenix release image and Compose stack containing the server and PostgreSQL. The release runs Ecto migrations before startup, readiness verifies PostgreSQL with `SELECT 1`, and the product schema stores projects, memories, immutable revisions, and the PostgreSQL keyword-search index.

The Compose development defaults set `DEV_API_TOKEN=development-only-token` and `DEV_ACTOR_ID=00000000-0000-0000-0000-000000000001`. Change both values for any shared development environment. This fixed credential is intentionally not production-ready and provides no users, organizations, tenant isolation, token lifecycle, or fine-grained authorization. Do not expose a Phase 1 deployment to untrusted networks.

Production self-hosting will add versioned images, production identity and administrator bootstrap, storage/search/worker configuration, backup and restore, upgrades, observability, and operational runbooks. Dependencies will be added when implemented features need them; Redis, object storage, queues, and vector databases are not assumed.

Self-hosters will control which official and community modules are allowed and enabled. Production module operations eventually require version pinning, permission approval, publisher/integrity verification, configuration and migration tooling, worker/process lifecycle, diagnostics, and backup/export coverage for module-owned data. External community module execution is deferred until supervised official OTP applications validate the contracts.

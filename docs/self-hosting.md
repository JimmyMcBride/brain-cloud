# Self-hosting direction

Self-hosting is a first-class Brain Cloud deployment, using the same API and client behavior as the official hosted service. Clients select any compatible server through a configurable base URL and discover protocol/capability support.

Phase 0 supplies a development Dockerfile and Compose stack containing the API and PostgreSQL. The API does not yet persist data, run migrations, or provide administrator setup. These files are development scaffolding, not production operational guidance.

Production self-hosting will add versioned images, migrations, administrator bootstrap, storage/search/worker configuration, health checks, backup and restore, upgrades, observability, and operational runbooks. Dependencies will be added when implemented features need them; Redis, object storage, queues, and vector databases are not assumed.

Self-hosters will control which official and community modules are allowed and enabled. Production module operations eventually require version pinning, permission approval, publisher/integrity verification, configuration and migration tooling, worker/process lifecycle, diagnostics, and backup/export coverage for module-owned data. External community module execution is deferred until compiled official modules validate the contracts.

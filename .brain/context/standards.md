# Standards

<!-- brain:begin context-standards -->
Use this file for implementation and review expectations.

## Standards

- Keep Elixir code formatted with `mix format`.
- Compile with warnings treated as errors and test PostgreSQL behavior through ExUnit.
- Keep OpenAPI synchronized with implemented Phoenix routes.

## CI

- `.github/workflows/ci.yml`
<!-- brain:end context-standards -->

## Local Notes

Public API changes require matching OpenAPI updates. Hosted and self-hosted deployments share one protocol. Permission checks must occur before retrieval; durable changes require revision provenance and auditability.

Module work must preserve explicit enablement, capability registration, permission declarations, data ownership, migrations, discovery, and audit. Official modules receive no private exceptions. Do not implement Planning domain behavior before its dedicated contract, add official Linear support, make GitHub permanent Planning infrastructure, move Hive Mind into a module, or load unrestricted third-party code in process.

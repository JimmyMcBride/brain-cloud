# Project Architecture

<!-- brain:begin project-doc-architecture -->
Use this file for the structural shape of the repository.

## Internal Packages

- `internal/config/`
- `internal/server/`

## Architecture Notes

- Keep composition in `cmd/api` and `cmd/worker`.
- Implement the public HTTP protocol without importing external SDKs.
- Add domain packages and infrastructure only with working vertical slices.
- Enforce permissions before retrieval and preserve revision provenance.
<!-- brain:end project-doc-architecture -->

## Local Notes

The Phase 0 server uses standard-library HTTP and structured logging. `internal/config` loads environment configuration; `internal/server` owns `/healthz`, `/readyz`, and `/v1/system/info`. PostgreSQL appears in development Compose but is not connected until Phase 1. See `docs/architecture.md` and the ADRs for full boundaries.

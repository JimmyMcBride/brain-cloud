# Project Architecture

<!-- brain:begin project-doc-architecture -->
Use this file for the structural shape of the repository.

## Internal Packages

- `internal/config/`
- `internal/server/`

## Architecture Notes

- Favor small package boundaries and explicit CLI/app wiring.
- Keep public CLI behavior stable; add internal seams only when they improve testability or safety.
- Treat generated project context as deterministic repo state, not LLM-authored prose.
- Treat session enforcement as the hard-control layer above soft context files.
<!-- brain:end project-doc-architecture -->

## Local Notes

The Phase 0 server uses standard-library HTTP and structured logging. `internal/config` loads environment configuration; `internal/server` owns `/healthz`, `/readyz`, and `/v1/system/info`. System discovery includes an empty enabled-module list; no module registry exists. PostgreSQL appears in development Compose but is not connected until Phase 1. Planning begins later as an optional compiled official module; community process execution follows only after official contract validation. See `docs/architecture.md` and ADRs 0007–0012.

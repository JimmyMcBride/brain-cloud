# Architecture

<!-- brain:begin context-architecture -->
Use this file for the structural shape of the repository.

## Internal Packages

- `internal/config/`
- `internal/server/`

## Architecture Notes

- Favor small package boundaries and explicit CLI/app wiring.
- Keep public CLI behavior stable; add internal seams only when they improve testability or safety.
- Treat generated project context as deterministic repo state, not LLM-authored prose.
- Treat session enforcement as the hard-control layer above soft context files.
<!-- brain:end context-architecture -->

## Local Notes

Brain Cloud is API-first and implements, but never imports, external SDKs.

- `cmd/api/main.go` composes environment configuration, structured JSON logging, HTTP serving, signal handling, and graceful shutdown.
- `cmd/worker/main.go` is a lifecycle-only worker composition root; Phase 0 deliberately has no queue or job implementation.
- `internal/config` validates environment configuration.
- `internal/server` owns the standard-library HTTP transport and handler tests.
- `openapi/brain-cloud-v1.yaml` records only implemented routes and reserves future `/v1` domain areas without speculative schemas.
- Brain CLI/local filesystem behavior and SDK implementations remain outside this repository.
- Brain Cloud owns cloud module lifecycle, configuration, execution, discovery, and unified UI.
- Planning is an optional official module, not Plan Cloud. It receives no private internal access and has separate permissions.
- Compiled official modules validate Stage 1 contracts; community modules later use an external process protocol.
- Hive Mind remains Core and modules cannot bypass its permission, scope, tenant, or provenance rules.

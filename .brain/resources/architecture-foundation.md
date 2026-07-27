---
title: Brain Cloud architecture foundation
updated: "2026-07-27T17:49:11Z"
---
## Repository boundary

Brain Cloud server only. Brain CLI and local `.brain/` behavior, language SDKs, Plan Cloud, and autonomous agent execution remain external. The server implements the public `/v1` protocol and never imports an SDK.

## Entrypoints and packages

- `cmd/api/main.go`: API composition root, structured JSON logging, signal handling, graceful HTTP shutdown.
- `cmd/worker/main.go`: lifecycle-ready worker composition root; no queue or jobs exist in Phase 0.
- `internal/config`: environment configuration and validation.
- `internal/server`: HTTP routes, compatibility response, request logging, and handler tests.

## Protocol

Implemented routes are `GET /healthz`, `GET /readyz`, and `GET /v1/system/info`. The compatibility response advertises server `brain-cloud`, version `0.0.0-dev`, protocol `v1`, and capability `system.info`. `openapi/brain-cloud-v1.yaml` is authoritative for implemented transport behavior.

## Deployment

- `Dockerfile`: multi-stage API image with a non-root distroless runtime.
- `compose.yaml`: development API plus PostgreSQL. PostgreSQL is intentionally unused until Phase 1 persistence.
- `.github/workflows/ci.yml`: formatting, tests, vet, API build, worker build.

## Verification

Run `make check`, then runtime curls against the three routes. Required closeout checks are `go test ./...`, `go vet ./...`, and `go build ./...`.

## Next implementation boundary

Phase 1 only: development authentication, one cloud project, one durable memory with a basic revision, retrieval, keyword search, PostgreSQL persistence, OpenAPI expansion, and end-to-end restart durability.

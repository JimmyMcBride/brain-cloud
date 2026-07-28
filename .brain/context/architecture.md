---
updated: "2026-07-28T05:20:54Z"
---
# Architecture

<!-- brain:begin context-architecture -->
Use this file for the structural shape of the repository.

## Umbrella Applications

- `apps/brain_cloud/`
- `apps/brain_cloud_web/`

## Architecture Notes

- Keep domain and persistence concerns in `brain_cloud`.
- Keep Phoenix, LiveView, and HTTP transport concerns in `brain_cloud_web`.
- Use OTP supervision for background processes; add no worker-only app until jobs exist.
<!-- brain:end context-architecture -->

## Local Notes

Brain Cloud is API-first and implements, but never imports, external SDKs.

- `apps/brain_cloud` owns Ecto/PostgreSQL, projects, immutable memory revisions, exact SHA-256 content hashes, project-scoped `simple` full-text search, system information, readiness, release migrations, and domain supervision.
- `apps/brain_cloud_web` owns Phoenix, Bandit, temporary development bearer authentication, structured JSON controllers, LiveView, assets, and the HTTP endpoint.
- Phase 1 product routes are `POST /v1/projects`, `POST /v1/projects/{project_id}/memories`, `GET /v1/projects/{project_id}/memories/{memory_id}`, and `GET /v1/projects/{project_id}/search`.
- Phase 1 records the configured `DEV_ACTOR_ID` as provenance but does not implement production identity, authorization, or multi-tenancy.
- Production releases emit JSON logs and run Ecto migrations before startup.
- `openapi/brain-cloud-v1.yaml` records only implemented routes and reserves future `/v1` domain areas without speculative schemas.
- `scripts/phase1-smoke.sh` owns the repeatable Compose API-restart and PostgreSQL outage/recovery verification.
- Brain CLI/local filesystem behavior and SDK implementations remain outside this repository.
- Brain Cloud owns cloud module lifecycle, configuration, execution, discovery, and unified UI.
- Planning is an optional official module, not Plan Cloud. It receives no private internal access and has separate permissions.
- Supervised official OTP applications validate Stage 1 behaviours; community modules later use an external process protocol.
- Hive Mind remains Core and modules cannot bypass its permission, scope, tenant, or provenance rules.

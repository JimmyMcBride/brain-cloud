---
updated: "2026-07-29T07:04:36Z"
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

- `apps/brain_cloud` owns Ecto/PostgreSQL, users, organizations, owner-managed memberships, scoped token digests, direct reader/editor project grants, implicit owner access, final-owner locking, transactional credential revocation, immutable audit events, organization-owned projects, immutable memory revisions, exact SHA-256 content hashes, tenant/project-scoped `simple` full-text search, system information, readiness, release migrations/bootstrap, and domain supervision.
- `apps/brain_cloud_web` owns Phoenix, Bandit, persisted bearer authentication and owner/scope/project enforcement, structured JSON controllers, LiveView, assets, and the HTTP endpoint.
- Implemented protected routes are token create/list/revoke, membership create/list/role/deactivate/reactivate/target-token, project creation, project access list/put/delete, memory creation/retrieval, and keyword search. Root, health, readiness, and system discovery remain public.
- Every authenticated request derives user, organization, membership, role, credential, and fixed scopes. Tenant- and grant-aware Ecto predicates run before protected content loads.
- Production releases emit JSON logs and run Ecto migrations before startup.
- `openapi/brain-cloud-v1.yaml` records only implemented routes and reserves future `/v1` domain areas without speculative schemas.
- `scripts/phase2-upgrade-test.sh` verifies deterministic Phase 1 migration, explicit legacy adoption, selective owner-scope upgrade, and member/project grant backfill. `scripts/phase2-smoke.sh` verifies release bootstrap/recovery, token lifecycle, direct project access, two-organization isolation, API restart durability, and PostgreSQL outage/recovery.
- Brain CLI/local filesystem behavior and SDK implementations remain outside this repository.
- Brain Cloud owns cloud module lifecycle, configuration, execution, discovery, and unified UI.
- Planning is an optional official module, not Plan Cloud. It receives no private internal access and has separate permissions.
- Supervised official OTP applications validate Stage 1 behaviours; community modules later use an external process protocol.
- Hive Mind remains Core and modules cannot bypass its permission, scope, tenant, or provenance rules.

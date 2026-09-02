---
updated: "2026-09-02T14:32:46Z"
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

- `apps/brain_cloud` owns Ecto/PostgreSQL, users, organizations, owner-managed memberships, member-only invitations and agents, human/agent token digests and one-time invitation-secret digests, soft-deactivated teams and agents, retained links/grants, direct human/team reader-editor grants, direct agent reader-editor grants, implicit owner access, row-locked lifecycle mutations, transactional credential revocation, immutable human-or-agent audit events, projects, immutable human-or-agent memory revisions, tenant/project-scoped search, readiness, release migrations/bootstrap, and domain supervision.
- `apps/brain_cloud_web` owns Phoenix, Bandit, persisted bearer authentication with explicit human/agent provenance, owner/scope/project enforcement, structured JSON controllers, LiveView, assets, and the HTTP endpoint.
- Implemented routes include public invitation acceptance plus protected invitation, human token/membership lifecycle, team lifecycle/membership, agent lifecycle/nested credentials, project creation, direct human/team/agent project grants, memory creation/retrieval, and keyword search. Root, health, readiness, and system discovery remain public.
- Every authenticated request derives principal type/ID, organization, credential, and fixed scopes; human contexts also carry user/membership/role. Tenant- and grant-aware Ecto predicates run before protected content loads.
- Production releases emit JSON logs and run Ecto migrations before startup.
- `openapi/brain-cloud-v1.yaml` records only implemented routes and reserves future `/v1` domain areas without speculative schemas.
- `scripts/phase2-upgrade-test.sh` verifies deterministic Phase 1 migration, explicit legacy adoption, selective owner-scope upgrades, member/project backfill, and empty agent tables. `scripts/phase2-smoke.sh` verifies release bootstrap/recovery, human/agent token lifecycle, direct/team/agent reader-editor access and human/agent provenance, tenant isolation, restart durability, and PostgreSQL outage/recovery.
- Brain CLI/local filesystem behavior and SDK implementations remain outside this repository.
- Brain Cloud owns cloud module lifecycle, configuration, execution, discovery, and unified UI.
- Planning is an optional official module, not Plan Cloud. It receives no private internal access and has separate permissions.
- Supervised official OTP applications validate Stage 1 behaviours; community modules later use an external process protocol.
- Hive Mind remains Core and modules cannot bypass its permission, scope, tenant, or provenance rules.

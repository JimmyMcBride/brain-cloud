---
updated: "2026-09-07T15:01:19Z"
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

- `apps/brain_cloud` owns Ecto/PostgreSQL, users, organizations, memberships/invitations, human/agent API token digests, one-time browser login challenges, tracked browser sessions, global human-auth events, teams/agents and retained grants, project access, organization audit, projects, immutable memory revisions, search, readiness, release migrations/bootstrap, and domain supervision.
- `apps/brain_cloud_web` owns Phoenix, Bandit, separate API bearer and browser authentication, synchronous Swoosh delivery, encrypted cookies, database-rehydrated current scope, structured JSON controllers, the minimal LiveView identity shell, assets, and the HTTP endpoint.
- Implemented routes include public invitation acceptance plus protected invitation, human token/membership lifecycle, team lifecycle/membership, agent lifecycle/nested credentials, project creation, direct human/team/agent project grants, memory creation/retrieval, and keyword search. Root, health, readiness, and system discovery remain public.
- Every authenticated request derives principal type/ID, organization, credential, and fixed scopes; human contexts also carry user/membership/role. Tenant- and grant-aware Ecto predicates run before protected content loads.
- Production releases emit JSON logs, validate HTTPS/SMTP configuration, and run Ecto migrations before startup.
- `openapi/brain-cloud-v1.yaml` records only implemented routes and reserves future `/v1` domain areas without speculative schemas.
- `scripts/phase2-upgrade-test.sh` verifies historical data/API compatibility, empty browser-auth rollout, rollback/forward migration, and post-upgrade sign-in. `scripts/phase2-smoke.sh` also verifies SMTP delivery, one/multiple-organization browser sign-in, switching, scope freshness, logout/replay denial, restart persistence, and PostgreSQL outage/recovery.
- Brain CLI/local filesystem behavior and SDK implementations remain outside this repository.
- Brain Cloud owns cloud module lifecycle, configuration, execution, discovery, and unified UI.
- Planning is an optional official module, not Plan Cloud. It receives no private internal access and has separate permissions.
- Supervised official OTP applications validate Stage 1 behaviours; community modules later use an external process protocol.
- Hive Mind remains Core and modules cannot bypass its permission, scope, tenant, or provenance rules.

Phase 2I implements spec [#28](https://github.com/JimmyMcBride/brain-cloud/issues/28): owner-only invitation controls, synchronous invitation email, generation-checked resend with unchanged expiry, credential-free browser admission, and separate existing email sign-in. Existing API contracts remain unchanged. No broader product dashboard or Planning implementation is included.

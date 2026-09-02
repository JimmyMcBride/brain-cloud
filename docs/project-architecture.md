---
updated: "2026-09-02T14:33:35Z"
---
# Project Architecture

<!-- brain:begin project-doc-architecture -->
Use this file for the structural shape of the repository.

## Umbrella Applications

- `apps/brain_cloud/`
- `apps/brain_cloud_web/`

## Architecture Notes

- Keep domain and persistence concerns in `brain_cloud`.
- Keep Phoenix, LiveView, and HTTP transport concerns in `brain_cloud_web`.
- Use OTP supervision for background processes; add no worker-only app until jobs exist.
<!-- brain:end project-doc-architecture -->

## Local Notes

The Phase 2G server is a Phoenix umbrella. `brain_cloud` owns Ecto/PostgreSQL, human and agent accounts, organization tenancy, member invitations and public acceptance, scoped credentials, soft-deactivated teams/agents and retained links/grants, direct human/team reader-editor grants, direct agent reader-editor grants, implicit owner access, row-locked lifecycle mutations, transactional credential revocation, immutable human-or-agent audit events, projects, memories, immutable human-or-agent revisions, tenant/project-scoped keyword search, readiness, release migrations/bootstrap, and domain supervision. `brain_cloud_web` owns Phoenix, Bandit, explicit human/agent bearer authentication, owner/scope/project-access enforcement, LiveView, JSON controllers, and assets. System discovery includes implemented core capabilities and an empty enabled-module list; no module registry exists. Planning begins later as an optional supervised official OTP application; community process execution follows only after official contract validation. See `docs/architecture.md` and ADRs 0007–0013.

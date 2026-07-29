---
updated: "2026-07-29T07:04:36Z"
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

The Phase 2D server is a Phoenix umbrella. `brain_cloud` owns Ecto/PostgreSQL, accounts and organization tenancy, owner-managed human memberships, scoped credentials, soft-deactivated teams and retained membership links, direct and team reader/editor project grants, implicit owner project access, final-owner and team-mutation locking, transactional credential revocation, immutable audit events, organization-owned projects, memories, immutable revisions, tenant/project-scoped keyword search, system information, readiness, release migrations/bootstrap, and domain supervision. `brain_cloud_web` owns Phoenix, Bandit, persisted bearer authentication, owner/scope/project-access enforcement, LiveView, JSON controllers, and assets. System discovery includes implemented core capabilities and an empty enabled-module list; no module registry exists. Planning begins later as an optional supervised official OTP application; community process execution follows only after official contract validation. See `docs/architecture.md` and ADRs 0007–0013.

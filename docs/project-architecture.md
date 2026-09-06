---
updated: "2026-09-06T13:58:09Z"
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

The Phase 2H server is a Phoenix umbrella. `brain_cloud` owns Ecto/PostgreSQL, human and agent accounts, organization tenancy, invitations, API credentials, browser login challenges and sessions, global auth events, teams/agents and retained links/grants, direct project access, lifecycle locking, organization audit, projects, memories, keyword search, readiness, release migrations/bootstrap, and domain supervision. `brain_cloud_web` owns Phoenix, Bandit, separate API bearer and human browser authentication, synchronous Swoosh delivery, encrypted session cookies, current-scope rehydration, the minimal LiveView identity shell, JSON controllers, and assets. System discovery still reports the same API capabilities and empty enabled-module list. See `docs/architecture.md` and ADRs 0007–0013.

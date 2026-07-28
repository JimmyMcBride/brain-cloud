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

The Phase 0 server is a Phoenix umbrella. `brain_cloud` owns Ecto/PostgreSQL, system information, readiness, release migrations, and domain supervision. `brain_cloud_web` owns Phoenix, Bandit, LiveView, JSON controllers, and assets. System discovery includes an empty enabled-module list; no module registry exists. PostgreSQL readiness is implemented, while Phase 1 product persistence remains deferred. Planning begins later as an optional supervised official OTP application; community process execution follows only after official contract validation. See `docs/architecture.md` and ADRs 0007–0013.

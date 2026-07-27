# Standards

<!-- brain:begin context-standards -->
Use this file for implementation and review expectations.

## Standards

- Keep code idiomatic Go with small, concrete abstractions.
- Prefer standard-library dependencies until a dependency clearly earns its place.
- Test implemented HTTP contracts and configuration behavior explicitly.
- Never add placeholder domain packages or claim roadmap features are implemented.
- Record required verification through `brain session run -- ...` so finish-stage enforcement can validate it.

## CI

- `.github/workflows/ci.yml`
<!-- brain:end context-standards -->

## Local Notes

Public API changes require matching OpenAPI updates. Hosted and self-hosted deployments share one protocol. Permission checks must occur before retrieval; durable changes require revision provenance and auditability.

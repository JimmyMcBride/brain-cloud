---
updated: "2026-07-28T20:57:51Z"
---
# Current State

<!-- brain:begin context-current-state -->
This file is a deterministic snapshot of the repository state at the last refresh.

## Repository

- Project: `brain-cloud`
- Root: `.`
- Runtime: `elixir`
- Current branch: `codex/phase-2b-membership-administration-plan`
- Default branch: `develop`
- Remote: `https://github.com/JimmyMcBride/brain-cloud.git`
- Umbrella apps: `brain_cloud`, `brain_cloud_web`
- ExUnit test files: `13`

## Docs

- `README.md`
- `docs/architecture.md`
- `docs/product-vision.md`
- `docs/project-architecture.md`
- `docs/project-overview.md`
- `docs/project-workflows.md`
- `docs/roadmap.md`
- `docs/security.md`
- `docs/self-hosting.md`
<!-- brain:end context-current-state -->

## Local Notes

Phase 1 is implemented from GitHub spec [#2](https://github.com/JimmyMcBride/brain-cloud/issues/2), `brain-cloud-first-vertical-slice`: development bearer authentication, projects, one immutable Markdown memory revision, PostgreSQL `simple` full-text search, structured errors, OpenAPI coverage, and restart durability.

Phase 2A is implemented from GitHub spec [#5](https://github.com/JimmyMcBride/brain-cloud/issues/5), `production-identity-and-organization-tenant-foundation`: persisted users and organizations, owner/member memberships, scoped revocable API tokens, tenant enforcement on existing product routes, deterministic Phase 1 data migration and explicit adoption, release owner bootstrap/recovery, and minimal immutable audit events. Teams, agent credentials, interactive login, invitations, and fine-grained project ACLs remain deferred.

Phase 2A merged through [PR #7](https://github.com/JimmyMcBride/brain-cloud/pull/7).
Next planning candidate is `.plan/brainstorms/organization-membership-administration-foundation.md`:
owner-only human membership lifecycle plus explicit one-time target-member credentials,
without invitations, interactive login, teams, service/agent identities, or project ACLs.

When a local brainstorm has already been promoted in GitHub source mode, update the existing issue with `plan github adopt --issues <number>`; do not reapply `plan discuss promote`, whose preview does not reconcile local brainstorm sources to existing issues.

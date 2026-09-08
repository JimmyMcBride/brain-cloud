---
updated: "2026-09-08T01:07:31Z"
---
# Current State

<!-- brain:begin context-current-state -->
This file is a deterministic snapshot of the repository state at the last refresh.

## Repository

- Project: `brain-cloud`
- Root: `.`
- Runtime: `elixir`
- Current branch: `codex/phase-2h-interactive-human-identity-bridge`
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

Phase 2B implements GitHub spec [#9](https://github.com/JimmyMcBride/brain-cloud/issues/9): owner-only human membership create/list/role/deactivate/reactivate operations, explicit one-time target-member credentials, non-enumerating tenant boundaries, final-owner concurrency protection, transactional credential revocation, and membership audit events. Invitations, interactive login, teams, service/agent identities, and project ACLs remain deferred.

Phase 2C implements GitHub spec [#12](https://github.com/JimmyMcBride/brain-cloud/issues/12), `project-access-control-foundation`: direct reader/editor grants for human memberships, implicit owner access, member-creator editor grants, fixed `projects.manage_access` scope migration, PostgreSQL-enforced tenant alignment, compatibility backfill including inactive members, exact owner-only management contracts, deterministic audit semantics, and authorization before memory/revision/search lookup. Teams, invitations, interactive login, service/agent identities, custom roles, and a generic policy engine remain deferred.

Phase 2D implements GitHub spec [#14](https://github.com/JimmyMcBride/brain-cloud/issues/14), `team-access-foundation`: soft-deactivated organization teams, retained membership links, separate team project grants, strongest direct-or-team authorization, fixed `teams.manage`, tenant-aligned composite constraints, serialized mutations, and transactional audit semantics. Invitations, interactive login, service/agent identities, custom roles, nested teams, deny rules, and a generic policy engine remain deferred.

Phase 2E is complete from GitHub spec [#16](https://github.com/JimmyMcBride/brain-cloud/issues/16), `agent-identity-and-credential-foundation`: organization-owned agent principals, shared-format read-only credentials with explicit principal provenance, fixed `agents.manage`, direct reader grants, lifecycle locking, aggregate deactivation revocation audits, and tenant-aligned database constraints. Phase 2F supersedes its read-only agent boundary; invitations, interactive login, custom roles, deny rules, and a generic policy engine remain deferred.

Phase 2F is complete from canonical GitHub spec [#19](https://github.com/JimmyMcBride/brain-cloud/issues/19), `agent-authored-memory-provenance-foundation`, and merged PR [#21](https://github.com/JimmyMcBride/brain-cloud/pull/21): split human/agent memory and audit provenance, direct agent editor grants, and scoped agent-authored immutable memory creation.

Phase 2G is implemented from canonical GitHub spec [#22](https://github.com/JimmyMcBride/brain-cloud/issues/22), `human-invitation-and-acceptance-foundation`: owner-managed member-only invitations, one-time expiring `bci1` acceptance secrets stored only as digests, transactional user reuse or creation, membership and initial-credential issuance, terminal-state row locking, tenant-safe database constraints, exact concealed failures, and explicit invitation audit provenance. Email delivery, interactive login, owner invitations, project/team assignment, custom roles, proposals, and a generic policy engine remain deferred.

When a local brainstorm has already been promoted in GitHub source mode, update the existing issue with `plan github adopt --issues <number>`; do not reapply `plan discuss promote`, whose preview does not reconcile local brainstorm sources to existing issues.

Phase 2H is implemented from canonical GitHub spec [#25](https://github.com/JimmyMcBride/brain-cloud/issues/25), `closed-enrollment-interactive-human-identity-bridge`: existing-user-only passwordless email sign-in, digest-only one-time challenges, synchronous Swoosh SMTP, revocable 14-day browser sessions with seven-day reissue, active-organization selection, PostgreSQL-rehydrated HTTP/LiveView scope, safe global auth events, and a minimal signed-out/chooser/signed-in shell. Browser and API credentials remain strictly separate. Automatic invitation delivery, interactive invitation acceptance, product CRUD UI, alternate authenticators, owner invitations, and generic rate-limit infrastructure remain later work.

Concurrent sign-in issuance remains non-enumerating: the user row lock serializes normal challenge creation, the named active-challenge uniqueness race is accepted without logging, and a challenge superseded after synchronous delivery but before sent-state persistence is treated as an expected no-op while unexpected persistence failures still invalidate and log.

## Phase 2I shaping

Phase 2I was approved in canonical GitHub spec [#28](https://github.com/JimmyMcBride/brain-cloud/issues/28), `invitation-delivery-and-browser-acceptance`; implementation status is recorded below. The user approved a minimal owner invitation panel, separate sign-in after admission, and secret rotation on resend without extending expiry. The spec fixes SMTP attempt limits and generation-safe delivery, credential-free browser acceptance, existing API compatibility, explicit mismatched-identity handling, and admission audit provenance. The canonical spec remains the acceptance contract. Existing API acceptance always mints a credential; browser admission must not silently mint and discard one. Invitation possession must never verify email or authenticate a browser.

## Phase 2I implementation

Spec #28 is implemented on `codex/invitation-delivery-and-browser-acceptance-v2`, based on fresh develop with the tested admission slice carried over. InvitationDelivery owns owner reauthorization, generation-safe reservations/finalization, and PostgreSQL-backed attempt limits. The owner invitation panel uses synchronous Swoosh delivery; recipient landing/preview/accept pages require CSRF and explicit intent. Browser admission issues no API credential and never verifies email or creates a session. Matching sessions select the new membership transactionally; mismatched identities must sign out. All 45 existing OpenAPI operations remain unchanged.

Migration adds delivery state, a tenant-bound current generation, and bounded rolling attempt history. Old invitations remain manual until explicitly sent. SMTP runs outside locks; failed/crashed/superseded generations remain unusable. Limits count every reserved attempt: 60-second invitation cooldown, five per invitation/hour, and 20 per organization/hour. Active owners lock in membership-ID order, followed by invitation and organization quota locks. Rolling history keeps current generations for safe referential integrity; old noncurrent rows expire during reservations. No background jobs or additional public API endpoints.

Validation: 156 ExUnit tests, formatting, warnings-as-errors compile, production assets, upgrade/rollback/forward tests, Docker image, and expanded Compose smoke passed. Browser landing layout was visually inspected. Same-tab fragment handling was fixed after QA and verified with an isolated JavaScript harness; final in-app browser recheck was blocked by its error-page navigation after deliberate server restarts. Existing controller tests and HTTP smoke cover confirmation and sign-in. SMTP failure/retry limits and concurrency are covered by domain/controller tests.

Planning PRs must avoid closing keywords next to issue numbers, even in negated sentences: PR #29 accidentally closed #28 because GitHub interpreted a negated closing phrase. The issue was reopened and that phrase removed. Canonical specs stay open until their implementation PRs merge.

PR #30 review follow-up: browser admission confirmation now distinguishes an already signed-in matching recipient from a signed-out recipient. Regression coverage checks both redirect/message pairs and selected-organization persistence.

## Phase 3A project discovery implementation

Canonical GitHub spec [#31](https://github.com/JimmyMcBride/brain-cloud/issues/31) is approved. Branch `codex/project-discovery-foundation` implements bearer-only project list/detail, explicit `projects.read`, strict bounded keyset cursors, PostgreSQL access filtering, and no credential or invitation backfill. Existing owners deliberately rotate bootstrap credentials with `ROTATE_TOKEN=true` when they need the additive scope. Implementation verification and review remain in progress.

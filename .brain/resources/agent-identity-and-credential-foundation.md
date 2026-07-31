---
title: Agent identity and credential foundation
updated: "2026-07-31T19:47:40Z"
---
# Agent identity and credential foundation

Phase 2E implements GitHub spec #16. `BrainCloud.Agents` owns organization agent lifecycle and nested credentials; `BrainCloud.Projects` owns direct reader-only agent grants. Agent credentials reuse the `bc1_` format and digest storage but authenticate as explicit `:agent` principals, accept only `memory.read` and `search.keyword`, never bootstrap, and stay outside human `/v1/auth/tokens` management.

Agent-row locks serialize lifecycle, issuance, revocation, and grant PUTs. Deactivation revokes every active credential in one transaction and emits one `agent.deactivate` audit event with `revoked_token_count`; it emits no per-token revoke events. Grants remain dormant while inactive and resume only after reactivation plus fresh credential issuance. Composite foreign keys align agents and grants to organizations, and token checks enforce exactly one human or agent principal.

Phase 2E does not add agent-authored writes, delegation, impersonation, interactive login, custom roles, deny rules, caches, background jobs, or a generic policy engine.

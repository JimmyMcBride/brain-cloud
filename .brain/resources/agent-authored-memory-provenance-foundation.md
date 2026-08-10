---
updated: "2026-08-10T07:14:13Z"
---
# Agent-authored memory provenance foundation

Phase 2F extends first-class agents without granting them human identity or administrative authority. Memory revisions and audit events use separate nullable human and agent actor columns with database-enforced exactly-one provenance. Agent tenant alignment is enforced against the memory project and audit organization.

An active agent may create immutable revision-1 Markdown only when its current credential has `memory.write` and it holds a direct editor grant on the target project. Credential validity, agent lifecycle, and grant state are rechecked under compatible row locks inside the write transaction. Reader/editor grants and fixed token scopes remain independent; editor implies read access, while reader never implies write.

The public API projects provenance as stable `actor_type` plus `actor_id`, preserving existing human actor UUID values. Phase 2F does not add project creation, administration, delegation, proposals, agent-authored revisions beyond initial creation, or a generic policy engine.

Verification covers raw database actor constraints, cross-tenant rejection, human compatibility, authorization combinations, deactivation/revocation/grant-removal races, deterministic upgrade behavior, production image construction, and Compose restart/outage recovery.

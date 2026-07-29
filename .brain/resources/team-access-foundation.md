---
title: Team access foundation
updated: "2026-07-29T08:58:35Z"
---
Phase 2D implements GitHub spec #14. BrainCloud.Teams owns soft-deactivated organization teams and retained membership links. BrainCloud.Projects owns direct and team reader/editor grants and resolves the strongest active source; owners remain implicit. Team lifecycle and membership require owner plus teams.manage; team project grants require owner plus projects.manage_access. Composite PostgreSQL foreign keys enforce tenant alignment. Team-row locks serialize lifecycle, membership, and grant mutations. Deactivation retains links and grants but makes team-derived access dormant until explicit reactivation. Real mutations emit transactional immutable audit events; idempotent no-ops do not. Invitations, nested teams, team managers/roles, agent identities, deny rules, generic policy, RLS, caches, and access UI remain deferred.

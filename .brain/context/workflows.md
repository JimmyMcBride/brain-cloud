---
updated: "2026-07-28T21:34:35Z"
---
# Workflows

<!-- brain:begin context-workflows -->
Use this file for agent operating workflow inside the repo.

## Startup

1. If no validated session is active, run `brain prep --task "<task>"`.
2. If a session already exists, run `brain prep`.
3. Read `AGENTS.md`, `.brain/policy.yaml`, and the linked context files still needed for the task.
4. Use `brain context compile --task "<task>"` only when you need the lower-level packet compiler directly.
5. If project memory still matters, run `brain find brain-cloud` or `brain search "brain-cloud <task>"`.

## Post-Adoption Enrichment

After `brain adopt` creates starter context, the AI agent must scan the repo before treating the templates as complete memory.

1. Treat generated context as starter context, not complete repo memory.
2. Scan repo structure, docs, manifests, entrypoints, tests, CI, config, and deployment surfaces.
3. Update AGENTS.md, docs, or .brain notes with durable project-specific findings.
4. Add focused .brain/resources notes for architecture, workflows, risks, and references that do not belong in top-level templates.
5. Keep generated managed blocks refreshable; put hand-authored findings in Local Notes or dedicated notes.

## During Work

- Keep durable discoveries, decisions, and risks in AGENTS.md, /docs, or .brain notes.
- Update existing durable notes instead of duplicating context.
- Run required verification commands through `brain session run -- <command>`.
- Run `brain context audit` after meaningful architecture, config, CI, deploy, test, or docs-surface changes.
- If you change Brain command behavior or agent-facing workflow guidance, update `skills/brain/SKILL.md` in the same branch.
- Re-read context before large changes if the task shifts.

## Ticket Loop

1. Start one task or ticket at a time and keep the scope narrow.
2. Implement the task, then run focused tests for the touched packages.
3. Run the required full checks through `brain session run -- mix test`, `brain session run -- mix compile --warnings-as-errors`, and `brain session run -- mix assets.deploy`.
4. Review the diff against the task goal and user-facing behavior.
5. If review finds issues, patch the work and repeat the test and review steps.
6. When the task is clean, commit it, push it, and only then move to the next task.

## Close-Out

- Refresh or update durable notes for meaningful behavior, config, or architecture changes.
- Use `brain context audit --proposal` when context coverage findings should become a reviewed durable update proposal.
- If `brain session finish` blocks, inspect the promotion suggestions first; run `brain distill --session --dry-run` only when you need the full review without creating a proposal note.
- Before switching away from a working branch or back to `develop`, run `git status --short` and resolve repo-owned leftovers. If `.brain/resources/changes/*`, `.brain/`, `docs/`, or contract files belong to the task, keep them in the same branch/PR; otherwise review and intentionally remove them instead of carrying them onto `develop`, `release/*`, or `main`.
- If `skills/brain/` changed, reinstall the local Brain skill for Codex and OpenClaw with `brain skills install --scope local --agent codex --agent openclaw --project .`.
- When opening a PR, make the title and body release-note friendly because GitHub release notes are generated from merged PR metadata.
- Summarize shipped behavior in the PR, not just implementation steps, so future changelogs stay human-readable.
- Finish with `brain session finish`.
- If you must bypass enforcement, use `brain session finish --force --reason "..."` so the override is recorded.
<!-- brain:end context-workflows -->

## Local Notes

Project-specific commands:

- `make check`: formatting, warnings-as-errors compilation, database migrations/tests, and production assets.
- `make run`: Phoenix and LiveView on `PORT` (default `4000`).
- `Dockerfile`: multi-stage, non-root OTP release image with migration entrypoint.
- `compose.yaml`: Phoenix release and PostgreSQL; operators create the initial organization owner through `/app/bin/bootstrap_owner`.
- `make upgrade-phase2`: with PostgreSQL running, verify deterministic Phase 1 data migration, synthetic principals, explicit legacy adoption, and preserved retrieval/search.
- `make smoke-phase2`: against a running Compose project, verify public endpoints, owner bootstrap/recovery, exact authorization behavior, scoped token lifecycle, two-organization isolation, create/retrieve/search, API-only restart durability, PostgreSQL outage health/readiness behavior, recovery, and persisted retrieval/search.

Active delivery branch is `develop`; `main` is releases and `release/vX.Y.Z` is stabilization. Phase 1 provides persistent project/memory/search. Phase 2A adds production API identity and organization tenancy. Phase 2B adds owner-managed human membership lifecycle and target credentials; invitations, teams, interactive identity, agent credentials, and project ACLs remain later Phase 2 work.

Plan currently uses GitHub source mode only as transitional repository coordination. All Plan-owned GitHub mutations still go through Plan. The target product architecture stores optional Planning data in local/cloud/hybrid Brain, not permanently in GitHub. Module ecosystem implementation is deferred until Phase 10; the Planning migration requires a separate follow-up contract.

# Project Agent Contract

<!-- brain:begin agents-contract -->
Use this file as a Brain-managed project context entrypoint for `brain-cloud`.

Brain is intended for AI agents operating in this repo, not as a human-operated project dashboard.

Read the linked context files before substantial work. Prefer the `brain` skill and `brain` CLI for project memory, retrieval, and durable context updates.

## Table Of Contents

- [Overview](./.brain/context/overview.md)
- [Architecture](./.brain/context/architecture.md)
- [Standards](./.brain/context/standards.md)
- [Workflows](./.brain/context/workflows.md)
- [Memory Policy](./.brain/context/memory-policy.md)
- [Current State](./.brain/context/current-state.md)
- [Policy](./.brain/policy.yaml)

## Project Docs

- [README.md](./README.md)
- [architecture.md](./docs/architecture.md)
- [product-vision.md](./docs/product-vision.md)
- [project-architecture.md](./docs/project-architecture.md)
- [project-overview.md](./docs/project-overview.md)
- [project-workflows.md](./docs/project-workflows.md)
- [roadmap.md](./docs/roadmap.md)
- [security.md](./docs/security.md)
- [self-hosting.md](./docs/self-hosting.md)

## Required Workflow

1. If no validated session is active, run `brain prep --task "<task>"`.
2. If a session is already active, run `brain prep`.
3. Read this file and the linked context files still needed for the task.
4. Use `brain context compile --task "<task>"` only when you need the lower-level packet compiler directly.
5. Retrieve project memory with `brain find brain-cloud` or `brain search "brain-cloud <task>"` when the compiled packet is not enough.
6. Use `brain edit` for durable context updates to AGENTS.md, docs, or .brain notes.
7. Run `brain context audit` after meaningful architecture, config, CI, deploy, test, or docs-surface changes.
8. Use `brain session run -- <command>` for required verification commands.
9. Finish with `brain session finish` so policy checks can enforce verification and surface promotion review when durable follow-through is still needed.

## Karpathy Guidelines

Behavioral guidelines to reduce common LLM coding mistakes, derived from [Andrej Karpathy's observations](https://x.com/karpathy/status/2015883857489522876) on LLM coding pitfalls.

Use these guidelines when writing, reviewing, or refactoring code to avoid overcomplication, make surgical changes, surface assumptions, and define verifiable success criteria.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No flexibility or configurability that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't improve adjacent code, comments, or formatting unless the task requires it.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it; don't delete it.

When your changes create orphans:
- Remove imports, variables, and functions that your changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" -> "Write tests for invalid inputs, then make them pass"
- "Fix the bug" -> "Write a test that reproduces it, then make it pass"
- "Refactor X" -> "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```text
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

Strong success criteria let you loop independently. Weak criteria such as "make it work" require constant clarification.

## Post-Adoption Enrichment

After `brain adopt` creates starter context, the AI agent must scan the repo before treating the templates as complete memory.

1. Treat generated context as starter context, not complete repo memory.
2. Scan repo structure, docs, manifests, entrypoints, tests, CI, config, and deployment surfaces.
3. Update AGENTS.md, docs, or .brain notes with durable project-specific findings.
4. Add focused .brain/resources notes for architecture, workflows, risks, and references that do not belong in top-level templates.
5. Keep generated managed blocks refreshable; put hand-authored findings in Local Notes or dedicated notes.
<!-- brain:end agents-contract -->

## Local Notes

Brain Cloud is the one hosted and self-hostable platform for Brain Core and enabled modules. Preserve one public `/v1` protocol across deployments. The primary repository family is `brain`, `brain-cloud`, and `brain-cloud-sdk-go`.

Planning is moving into Brain as an optional official module. The standalone `plan` repository remains during migration, but agents must not implement Plan Cloud, a separate Plan frontend/SDK/identity system/agent gateway, or official Linear integration. GitHub planning support is transitional and optional, though this repository currently uses Plan GitHub mode for coordination.

Official modules must use formal lifecycle, capability, permission, configuration, event, migration, discovery, and audit boundaries with no private exceptions. Planning permissions stay separate from context and memory. Brain Cloud official modules begin as supervised OTP applications; community modules should eventually use an external process protocol. Do not load unrestricted third-party code in process. Hive Mind remains Core and mediates scope, retrieval, reranking, contradictions, and provenance.

Current Phase 1 implementation is a Phoenix umbrella: `apps/brain_cloud` owns Ecto/PostgreSQL, projects, immutable memory revisions, project-scoped keyword search, and domain supervision, while `apps/brain_cloud_web` owns Phoenix, Bandit, temporary development bearer authentication, LiveView, and HTTP transport. There is no separate worker application until jobs exist. Never imply later roadmap features already work. Run `make check` plus runtime endpoint and restart-durability smoke tests after server changes. Production identity and multi-tenancy remain Phase 2.

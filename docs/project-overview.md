---
updated: "2026-09-02T14:33:35Z"
---
# Project Overview

<!-- brain:begin project-doc-overview -->
Project: `brain-cloud`

Primary runtime: `elixir`

## Manifests

- `mix.exs`
- `mix.lock`
- `Makefile`

## Repo Map

- `.brain/`
- `.plan/`
- `apps/`
- `config/`
- `deploy/`
- `docs/`
- `openapi/`
- `rel/`
<!-- brain:end project-doc-overview -->

## Local Notes

Brain Cloud is the API-first hosted and self-hostable platform for Brain Core and optional official/community modules. Planning is an optional official module, not a separate cloud platform; Hive Mind remains Core. Phase 2G implements persisted human and agent API identity, owner-managed member invitations with public one-time acceptance, organization tenancy, owner-managed human memberships and agents, scoped revocable tokens, soft-deactivated teams and agents, direct human/team reader-editor grants, direct agent reader-editor grants, immutable human-or-agent audit events, organization-owned project creation, immutable human-or-agent Markdown memory persistence/retrieval, and PostgreSQL keyword search. Product scope and current limitations are in `README.md`; full direction is in `docs/product-vision.md` and `docs/roadmap.md`.

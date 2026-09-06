---
updated: "2026-09-06T13:58:09Z"
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

Brain Cloud is the API-first hosted and self-hostable platform for Brain Core and optional official/community modules. Planning is an optional official module, not a separate cloud platform; Hive Mind remains Core. Phase 2H preserves the existing human/agent API identity, tenancy, invitations, scoped credentials, access control, provenance, projects, memory, and search while adding closed-enrollment passwordless human sign-in, tracked browser sessions, organization selection, fresh LiveView identity scope, and a minimal authenticated shell. Product CRUD remains API-only. Product scope and current limitations are in `README.md`; full direction is in `docs/product-vision.md` and `docs/roadmap.md`.

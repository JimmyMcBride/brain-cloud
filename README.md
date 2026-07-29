---
updated: "2026-07-29T07:04:36Z"
---
# Brain Cloud

Brain Cloud is the hosted and self-hostable cloud platform for Brain: an extensible context and memory platform for people, teams, and AI agents.

Brain supports three equal operating modes:

- **Local:** core context and memory stay on the user's machine; no account or server is required.
- **Cloud:** cloud-native projects store context, memory, search, conversations, collaboration, and optional module data without requiring a local repository.
- **Hybrid:** local Brain projects link to cloud projects and synchronize only user-selected durable content.

The official hosted service and self-hosted installations use the same public HTTP protocol. Compatible clients select a server by base URL; the hosted service has no privileged protocol.

## Product boundary

Brain Core owns capabilities every deployment and module needs: project identity, durable context and memory, retrieval, compilation, provenance, sessions, security boundaries, events, audit, and module lifecycle contracts.

This repository owns the Brain Cloud server, HTTP API, cloud-native projects, hosted retrieval, revision history, sync coordination, Hive Mind, identity and collaboration, module management and execution, workers, auditability, deployment support, and eventually one unified web application.

The primary repository family is:

```text
brain
brain-cloud
brain-cloud-sdk-go
```

Future TypeScript and Python SDKs may follow. The server implements the protocol and never depends on an SDK. Local `.brain/` behavior and Brain CLI implementation remain in `brain`.

Planning is not a separate cloud platform. It is the first major optional official Brain module. The existing standalone `plan` repository remains useful during migration, but this repository must not implement Plan Cloud, a separate Plan frontend, identity system, SDK, or agent gateway.

## Extensibility

Official and community modules adapt Brain to different workflows without making every workflow part of Brain Core. Modules use formal capabilities and permissions; official modules receive no private bypass into unrelated internals.

The staged direction is:

1. Supervised official OTP applications validate stable interfaces inside Brain Cloud.
2. Community modules later run as isolated external processes through a language-neutral protocol.
3. Cloud module services, jobs, APIs, agent tools, and constrained web surfaces follow after the contracts and security model mature.

Planning must be optional. Brain works without Planning, with the official Planning module, with external planning-context modules, or with Planning connected to an external execution system. GitHub planning remains transitional coordination, not the permanent data foundation. No official Linear integration is planned.

## Status

Phase 2D adds reusable organization teams and team-derived reader/editor project grants on top of the Phase 2C direct-grant foundation. Owners have implicit full project access; active members receive the strongest direct or active-team grant while every route still requires its fixed token scope. Team deactivation retains links and grants but makes them dormant until explicit reactivation. Organization-isolated project, immutable Markdown memory, and PostgreSQL keyword-search APIs remain the product slice. The Phoenix/LiveView shell remains an honest bootstrap surface; invitations, interactive login, agent credentials, custom roles, nested teams, sync, Hive Mind, module execution, Planning, and product UI remain roadmap work.

## Local development

Requirements: Elixir 1.20.2 and Erlang/OTP 29.0.3. PostgreSQL 18 and Docker are optional for local development.

```bash
docker compose up -d postgres
make setup
make check
make run
```

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `4000` | Phoenix HTTP port |
| `DATABASE_URL` | local development config | PostgreSQL connection URL |
| `SECRET_KEY_BASE` | development-only value | cookie and LiveView signing secret |
| `PHX_HOST` | `localhost` | externally visible host |
| `PHX_SERVER` | unset locally | start the endpoint in an OTP release |
| `POOL_SIZE` | `10` | PostgreSQL connection pool size |

```bash
docker compose up --build -d
make smoke-phase2
curl http://localhost:4000/
curl http://localhost:4000/healthz
curl http://localhost:4000/readyz
curl http://localhost:4000/v1/system/info
```

The Compose file starts the Phoenix release and PostgreSQL. `/readyz` returns `503` until PostgreSQL accepts a query. Bootstrap the first owner after the release starts:

```bash
bootstrap_response="$(
  docker compose exec -T \
    -e OWNER_EMAIL=owner@example.com \
    -e OWNER_DISPLAY_NAME="Example Owner" \
    -e ORGANIZATION_NAME="Example Organization" \
    -e ORGANIZATION_SLUG=example \
    api /app/bin/bootstrap_owner
)"

export BRAIN_CLOUD_TOKEN="$(printf '%s' "${bootstrap_response}" | jq -r '.token')"
```

The command creates or reuses the user, organization, and owner membership transactionally. Its initial full-scope token is displayed once. Repeating the same command returns `"status":"existing"` and `"token":null`; it cannot recover the prior secret. If that secret is lost, repeat the command with `-e ROTATE_TOKEN=true` to revoke it and display one replacement. Add `-e ADOPT_PHASE_ONE=true` and omit organization name/slug only when explicitly adopting data migrated into the deterministic `phase-1-import` organization.

Use the token on protected API routes:

```bash

project_response="$(
  curl --fail-with-body \
    --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
    --header "Content-Type: application/json" \
    --data '{"name":"Research"}' \
    http://localhost:4000/v1/projects
)"

project_id="$(printf '%s' "${project_response}" | jq -r '.project.id')"

curl --fail-with-body \
  --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{"title":"Phoenix","content":"# Durable memory","content_type":"text/markdown"}' \
  "http://localhost:4000/v1/projects/${project_id}/memories"

curl --fail-with-body \
  --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
  "http://localhost:4000/v1/projects/${project_id}/search?q=durable"
```

Tokens use `bc1_<public_id>_<secret>`, are permanently bound to one organization membership, and are stored only as SHA-256 digests. Token-management endpoints require an owner membership plus `tokens.manage`; membership lifecycle endpoints require owner plus `members.manage`, team lifecycle/membership requires owner plus `teams.manage`, and target-member issuance requires both token and membership management scopes. Direct and team project-grant management requires owner plus `projects.manage_access`. Product routes require both their advertised fixed token scope and project access: owners are implicit, readers can retrieve/search, and editors can also create memories.

Create a human member and issue a one-time credential explicitly:

```bash
membership_response="$(
  curl --fail-with-body \
    --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
    --header "Content-Type: application/json" \
    --data '{"email":"member@example.com","display_name":"Example Member","role":"member"}' \
    http://localhost:4000/v1/organization/memberships
)"

membership_id="$(printf '%s' "${membership_response}" | jq -r '.membership.id')"

member_token_response="$(
  curl --fail-with-body \
    --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
    --header "Content-Type: application/json" \
    --data '{"name":"Member reader","scopes":["memory.read","search.keyword"]}' \
    "http://localhost:4000/v1/organization/memberships/${membership_id}/tokens"
)"

export MEMBER_TOKEN="$(printf '%s' "${member_token_response}" | jq -r '.token.token')"

curl --fail-with-body \
  --header "Authorization: Bearer ${BRAIN_CLOUD_TOKEN}" \
  --header "Content-Type: application/json" \
  --request PUT \
  --data '{"access":"reader"}' \
  "http://localhost:4000/v1/projects/${project_id}/access/${membership_id}"
```

Grants survive suspension/reactivation and role changes. They are dormant while a membership is inactive or an owner, and become effective again when the membership is an active member. Deactivation and owner-to-member demotion revoke all target credentials immediately; reactivation never restores them. The final active owner cannot be demoted or deactivated. See [self-hosting](docs/self-hosting.md) for bootstrap, recovery, and access administration details.

## Project documents

- [Product vision](docs/product-vision.md)
- [Architecture](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Security direction](docs/security.md)
- [Self-hosting direction](docs/self-hosting.md)
- [Architecture decisions](docs/adr/)

## Branches

`develop` is the active integration/default branch, `release/vX.Y.Z` stabilizes releases, and `main` is the release branch. Recommended protections for `develop` and `main`: require pull requests, passing CI, resolved review conversations, and no force pushes or deletion.

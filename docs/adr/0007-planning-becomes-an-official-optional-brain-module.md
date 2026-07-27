# 0007: Planning becomes an official optional Brain module

## Status

Accepted. Supersedes the Planning/Plan Cloud separation in ADR 0001 and all of ADR 0006.

## Context

Planning benefits from Brain project identity, context, memory, retrieval, permissions, events, audit, local/cloud/hybrid behavior, and one user experience. A separate Plan Cloud platform would duplicate those foundations while forcing integrations between closely related workflows. Planning must still remain optional because many users use GitHub Issues, Jira, internal systems, or no structured planning tool.

## Decision

Planning is the first major official optional Brain module, not a separate cloud platform. It uses stable module interfaces, receives no private Brain exceptions, and has permissions separate from context and memory. It must work locally, in Brain Cloud, and in hybrid mode without requiring an external tracker. Brain Cloud stores and serves Planning data and UI only when the module is enabled.

The standalone `plan` repository remains during migration. A dedicated follow-up defines domain boundaries, storage, CLI, compatibility, and migration.

## Consequences

Brain remains useful without Planning. One platform can share identity, provenance, retrieval, audit, and module lifecycle while keeping Planning domain code optional and bounded. Planning capability discovery becomes necessary for APIs, SDKs, agents, and UI.

## Alternatives considered

- Separate Plan Cloud: rejected due to duplicated platform foundations and fragmented UX.
- Put all planning in Brain Core: rejected because Planning is optional.
- Require an external tracker: rejected because local/cloud/hybrid Brain must be self-sufficient.

## Migration implications

Do not create Plan Cloud, a Plan Cloud SDK, separate frontend, identity service, or agent gateway. Preserve current Plan during transition. Move concepts only under a future approved migration contract; do not begin migration under this ADR alone.

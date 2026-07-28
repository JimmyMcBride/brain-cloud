# 0010: One Brain Cloud platform and web application

## Status

Accepted. Supersedes the platform split in ADR 0006 and part of ADR 0001.

## Context

Separate cloud platforms, identity systems, agent gateways, SDKs, and frontends for context and planning would duplicate infrastructure and divide a workflow that depends on shared project knowledge.

## Decision

Brain Cloud is the single hosted and self-hostable platform. It provides one identity/access foundation, public API, agent boundary, SDK family per language, module runtime, and unified web application. Enabled modules may add constrained APIs, tools, jobs, navigation, settings, panels, and dashboards.

Planning surfaces and clients are capability-gated and absent when Planning is disabled.

## Consequences

Users get one project, permission, audit, and navigation model. Module UI security and sandboxing require future design. Optional features must not make core routes or clients depend on their presence.

## Alternatives considered

- Separate Plan Cloud stack: rejected due to duplication and synchronization burden.
- Always-on Planning UI inside Core: rejected because Planning is optional.
- Separate SDK per module: rejected because capability discovery supports one language SDK family.

## Migration implications

Do not build separate Plan Cloud services or packages. Future SDKs expose optional capability clients. The standalone Plan UI/CLI, if any, is addressed by the Planning migration contract rather than copied into a second cloud product.

# 0011: Linear integration is not a product direction

## Status

Accepted.

## Context

Early standalone Plan work considered Linear integration. Brain Planning must operate without any external tracker, and official integration commitments create ongoing API, support, and product obligations.

## Decision

Brain does not plan or maintain official Linear integration. Linear is removed from committed roadmaps, diagrams, promises, and official module examples. A future community module could theoretically integrate it through general module contracts.

## Consequences

Planning architecture stays tracker-independent. Product effort focuses on local, cloud, and hybrid Brain behavior. Users needing Linear would depend on a community extension without official support commitments.

## Alternatives considered

- Continue official integration: rejected because it distracts from first-party Planning foundations.
- Make Linear a required backend: rejected because Brain Planning must be self-sufficient.
- Ban all future integration: rejected because community modules should remain possible.

## Migration implications

No Brain Cloud Linear work should be created. Existing Linear-related code in the standalone Plan repository is untouched here and will be removed or retired by the dedicated Planning migration effort. Legacy Plan workspace metadata may remain only where required for migration history, never as roadmap direction.

# 0012: GitHub planning support is transitional and optional

## Status

Accepted.

## Context

The current repository uses Plan in GitHub source mode for collaborative coordination. GitHub issues, discussions, milestones, and repository artifacts are useful while Brain Cloud and the Planning module are immature, but they cannot define Planning's permanent storage architecture.

## Decision

Keep existing GitHub planning support during transition. Long term, Planning operates fully through local Brain, Brain Cloud, or hybrid Brain. GitHub becomes an optional module or integration that may import, publish, mirror, or target execution; it is not a mandatory source of truth.

## Consequences

Current development can continue without an immediate planning-tool migration. Future Planning contracts must avoid GitHub-specific identities and semantics. Repository workflows may still use GitHub normally for source control and pull requests.

## Alternatives considered

- Remove GitHub support immediately: rejected because it would disrupt current coordination.
- Make GitHub the permanent backend: rejected because local/self-hosted/cloud Planning must stand alone.
- Avoid all GitHub integration: rejected because optional publication and execution links remain valuable.

## Migration implications

This `brain-cloud` repository remains in Plan GitHub mode for now. Plan-owned GitHub artifacts continue through Plan workflows, not raw `gh` planning mutations. The dedicated Planning migration effort defines transition and compatibility.

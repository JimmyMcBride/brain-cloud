# 0009: Community modules use an external process model

## Status

Accepted direction; transport deferred.

## Context

Untrusted or independently released extensions need language independence, crash containment, explicit mediation, and fewer Go ABI constraints. Go's native plugin mechanism provides weak portability and isolation.

## Decision

Community modules will eventually run as separate processes. Connect RPC, gRPC, and JSON-RPC remain candidate transports; this ADR does not select one. Brain Core mediates capabilities, permissions, events, configuration, secrets, and lifecycle across the process boundary.

Compiled in-process execution is reserved initially for official modules maintained with Brain.

## Consequences

Community modules can use multiple languages and release independently. The platform must design process startup, health, protocol compatibility, cancellation, logs, resource limits, and failure containment. A process boundary improves isolation but is not complete sandboxing.

## Alternatives considered

- Go native plugins: rejected due to ABI, portability, and isolation limits.
- Unrestricted in-process third-party packages: rejected due to trust and failure blast radius.
- Webhooks only: rejected because richer tools, providers, jobs, and queries need bidirectional contracts.

## Migration implications

Do not implement arbitrary module loading now. Official compiled modules must avoid assumptions that prevent later remote contracts. Transport selection and external SDK work wait until official modules validate the model.

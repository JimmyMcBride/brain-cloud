# 0002: API-first self-hostable server

## Context

Official hosting, enterprise self-hosting, localhost, and third-party clients need compatible behavior without privileged service access.

## Decision

Brain Cloud exposes one public, base-URL-configurable, versioned HTTP protocol. OpenAPI records implemented operations. Server discovery reports protocol version and capabilities. Hosted and self-hosted deployments run the same server behavior.

## Consequences

Hosted-only private endpoints are prohibited. Compatibility and upgrade policy become product concerns. Deployment adapters must not leak managed-provider assumptions into the protocol.

## Alternatives considered

A hosted-only private protocol was rejected for lock-in. Separate self-hosted and hosted editions were rejected because they would drift. An unversioned API was rejected because independent SDK and server releases require negotiation.

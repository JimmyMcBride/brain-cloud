# 0004: External language-specific SDKs

## Context

Go, TypeScript, and Python clients need independent packaging and release cadence. Server and clients must not form a circular dependency.

## Decision

Language SDKs live in separate repositories. OpenAPI will generate protocol models and low-level transport; each SDK adds a handwritten ergonomic layer. The server implements the contract and never depends on an SDK.

## Consequences

Contract compatibility requires CI across repositories. SDKs remain reusable by CLI, integrations, and third parties. Local Markdown scanning, `.brain/` filesystem behavior, and CLI concerns are excluded from SDKs.

## Alternatives considered

SDK packages inside this repository were rejected due to release coupling. Handwritten duplicate protocol models were rejected because they increase drift. Importing the Go SDK into the server was rejected as an inverted dependency.

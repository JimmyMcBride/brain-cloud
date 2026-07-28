# 0001: Brain Cloud repository boundaries

## Status

Superseded in part by [ADR 0007](0007-planning-becomes-an-official-optional-brain-module.md) and [ADR 0010](0010-one-brain-cloud-platform-and-web-application.md). The server/SDK/CLI dependency boundaries remain accepted; the separate Plan Cloud boundary does not.

## Context

Brain, Brain Cloud, their SDKs, Plan, and Plan Cloud have related but distinct responsibilities. Combining them would couple release cycles and blur ownership.

## Decision

This repository contains only the Brain Cloud server, public HTTP API, cloud knowledge domains, hosted retrieval, sync coordination, Hive Mind, integrations, workers, auditability, deployment support, and eventual web application. Brain CLI/local behavior, SDKs, Plan domains, and autonomous agent execution remain external.

## Consequences

Integration must use explicit versioned contracts. Cross-repository changes require coordination, but each product retains independent ownership and releases.

## Alternatives considered

A monorepo was rejected because shared proximity would encourage forbidden domain coupling. Putting server code in `brain` was rejected because local Brain must remain independently useful and lightweight.
